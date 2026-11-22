import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;

    if (cartService.isAnyReserving) {
      Get.snackbar(
        'Hold in progress',
        'Please wait a moment while we confirm your stock reservation.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (cartService.hasExpiredReservations) {
      cartService.notifyStateChanged();
      Get.snackbar(
        'Reservation expired',
        'One or more items ran out of time. Tap "Reserve again" or remove them to check out.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(cartService.items.toList());
      cartService.clear();
      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      if (e.statusCode == 410) {
        cartService.notifyStateChanged();
        Get.snackbar(
          'Reservation expired',
          'Your 5-minute reservation expired before checkout finished. Tap "Reserve again" on expired items to continue.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else if (e.statusCode == 409) {
        Get.snackbar(
          'Stock changed',
          'Some items in your bag are no longer available.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Checkout failed',
          'Unable to complete your order right now. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isCheckingOut.value = false;
    }
  }
}