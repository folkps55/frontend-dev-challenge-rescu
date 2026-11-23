import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../model/reservation_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';
import 'api_exception.dart';
import 'clock_service.dart';

/// App-wide cart backed by server-side stock reservations (5-minute holds).
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  /// Per-deal serial queue so rapid +/- taps reconcile in exact order.
  final Map<int, Future<void>> _dealQueues = {};
  final Map<int, int> _pendingOps = {};

  OrderRepo get _orderRepo => Get.find<OrderRepo>();

  ClockService get _clock => Get.isRegistered<ClockService>()
      ? Get.find<ClockService>()
      : Get.put(ClockService(), permanent: true);

  bool isItemExpired(CartItemModel item) {
    if (item.isReserving) return false;
    final res = item.reservation;
    if (res == null) return true;
    return !_clock.now.value.isBefore(res.expiresAt.toLocal());
  }

  bool get hasExpiredReservations => items.any(isItemExpired);

  bool get isAnyReserving => items.any((i) => i.isReserving);

  /// Optimistically adds or increments [deal] in the bag, then reserves stock.
  /// Returns `false` if already at the deal's maximum available quantity.
  bool add(DealModel deal) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    final int previousQty = existing?.quantity ?? 0;

    if (previousQty >= deal.quantityLeft) {
      LogService.log('cart: cannot add more of deal ${deal.id}');
      _showFriendlyNotice(
        'Limit reached',
        'All available bags for ${deal.name} are already in your bag.',
      );
      return false;
    }

    final int targetQty = previousQty + 1;
    if (existing != null) {
      existing.quantity = targetQty;
      existing.isReserving = true;
      items.refresh();
    } else {
      items.add(
        CartItemModel(
          deal: deal,
          quantity: targetQty,
          isReserving: true,
        ),
      );
    }
    _recount();

    _enqueueDealOp(deal.id, () async {
      await _reconcileQuantityChange(
        deal: deal,
        targetQty: targetQty,
        previousQty: previousQty,
      );
    });

    return true;
  }

  /// Optimistically decrements [dealId] and releases/adjusts the backend hold.
  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    final deal = existing.deal;
    final int previousQty = existing.quantity;
    final int targetQty = previousQty - 1;

    if (targetQty <= 0) {
      final immediateRes = existing.reservation;
      items.removeWhere((i) => i.deal.id == dealId);
      _recount();
      _enqueueDealOp(dealId, () async {
        await _safeRelease(immediateRes);
      });
      return;
    }

    existing.quantity = targetQty;
    existing.isReserving = true;
    items.refresh();
    _recount();

    _enqueueDealOp(dealId, () async {
      await _reconcileQuantityChange(
        deal: deal,
        targetQty: targetQty,
        previousQty: previousQty,
      );
    });
  }

  /// Removes a line item completely and releases its backend hold.
  void remove(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    final immediateRes = existing.reservation;
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();

    _enqueueDealOp(dealId, () async {
      await _safeRelease(immediateRes);
    });
  }

  /// Re-attempts reserving stock for an item whose 5-minute hold has expired.
  Future<void> retryReservation(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null || existing.isReserving) return;

    final deal = existing.deal;
    final int qty = existing.quantity;

    existing.isReserving = true;
    items.refresh();

    await _enqueueDealOp(dealId, () async {
      final currentBefore = items.firstWhereOrNull((i) => i.deal.id == deal.id);
      final staleReservation = currentBefore?.reservation;
      if (currentBefore != null) {
        currentBefore.reservation = null;
      }
      await _safeRelease(staleReservation);

      try {
        final newRes = await _orderRepo.reserve(deal.id, quantity: qty);
        final currentAfter =
            items.firstWhereOrNull((i) => i.deal.id == deal.id);
        if (currentAfter == null) {
          await _safeRelease(newRes);
          return;
        }
        currentAfter.reservation = newRes;
      } on ApiException catch (e) {
        LogService.error('retry reservation failed for deal ${deal.id}', e);
        final currentAfter =
            items.firstWhereOrNull((i) => i.deal.id == deal.id);
        if (currentAfter != null) {
          currentAfter.reservation = null;
        }
        _showFriendlyNotice(
          'Could not reserve again',
          _friendlyReservationError(e, deal.name),
        );
      } catch (e) {
        LogService.error('retry reservation unexpected error', e);
      }
    });
  }

  Future<void> _reconcileQuantityChange({
    required DealModel deal,
    required int targetQty,
    required int previousQty,
  }) async {
    final currentBefore = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    final activeReservation = currentBefore?.reservation;
    if (currentBefore != null) {
      currentBefore.reservation = null;
    }

    // Release the actual hold active at execution time before acquiring the new one.
    await _safeRelease(activeReservation);

    try {
      final newRes = await _orderRepo.reserve(deal.id, quantity: targetQty);
      final currentAfter = items.firstWhereOrNull((i) => i.deal.id == deal.id);
      if (currentAfter == null) {
        // User removed the item while the reservation request was in flight.
        await _safeRelease(newRes);
        return;
      }
      currentAfter.reservation = newRes;
    } on ApiException catch (e) {
      LogService.error(
        'reservation failed for deal ${deal.id} (qty $targetQty)',
        e,
      );
      await _rollbackOptimisticChange(
        deal: deal,
        previousQty: previousQty,
        error: e,
      );
    } catch (e) {
      LogService.error('unexpected reservation error for deal ${deal.id}', e);
      await _rollbackOptimisticChange(
        deal: deal,
        previousQty: previousQty,
        error: null,
      );
    }
  }

  Future<void> _rollbackOptimisticChange({
    required DealModel deal,
    required int previousQty,
    required ApiException? error,
  }) async {
    final current = items.firstWhereOrNull((i) => i.deal.id == deal.id);

    if (previousQty <= 0) {
      items.removeWhere((i) => i.deal.id == deal.id);
      _recount();
    } else if (current != null) {
      current.quantity = previousQty;
      _recount();
      try {
        final restoredRes =
            await _orderRepo.reserve(deal.id, quantity: previousQty);
        current.reservation = restoredRes;
      } catch (_) {
        current.reservation = null;
      }
    }

    _showFriendlyNotice(
      'Stock unavailable',
      _friendlyReservationError(error, deal.name),
    );
  }

  String _friendlyReservationError(ApiException? e, String dealName) {
    if (e != null && e.statusCode == 409) {
      return 'Sorry, $dealName was just reserved by another customer.';
    }
    return 'Could not hold $dealName right now. Please try again.';
  }

  Future<void> _safeRelease(ReservationModel? reservation) async {
    if (reservation == null || reservation.id.isEmpty) return;
    try {
      await _orderRepo.releaseReservation(reservation.id);
    } catch (e) {
      LogService.log('releaseReservation(${reservation.id}) ignored: $e');
    }
  }

  Future<void> _enqueueDealOp(int dealId, Future<void> Function() task) {
    _pendingOps[dealId] = (_pendingOps[dealId] ?? 0) + 1;
    final prev = _dealQueues[dealId] ?? Future<void>.value();
    final next = prev.then((_) => task()).catchError((Object e) {
      LogService.error('cart queue error for deal $dealId', e);
    }).whenComplete(() {
      final remaining = (_pendingOps[dealId] ?? 1) - 1;
      if (remaining <= 0) {
        _pendingOps.remove(dealId);
      } else {
        _pendingOps[dealId] = remaining;
      }
      final current = items.firstWhereOrNull((i) => i.deal.id == dealId);
      if (current != null) {
        current.isReserving = remaining > 0;
        items.refresh();
      }
    });
    _dealQueues[dealId] = next;
    return next;
  }

  void _showFriendlyNotice(String title, String message) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void notifyStateChanged() {
    items.refresh();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}