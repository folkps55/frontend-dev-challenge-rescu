import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../model/cart_item_model.dart';
import '../../service/clock_service.dart';
import '../shared_widget/the_network_image.dart';
import 'cart_controller.dart';

class CartScreen extends GetView<CartController> {
  const CartScreen({super.key});

  ClockService get _clock => Get.isRegistered<ClockService>()
      ? Get.find<ClockService>()
      : Get.put(ClockService(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final cart = controller.cartService;
    return Scaffold(
      appBar: AppBar(title: const Text('My bag')),
      body: Obx(() {
        if (cart.items.isEmpty) {
          return const Center(child: Text('Your bag is empty'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            final item = cart.items[index];
            return _CartLineCard(
              item: item,
              clock: _clock,
              onIncrement: () => cart.add(item.deal),
              onDecrement: () => cart.decrement(item.deal.id),
              onRemove: () => cart.remove(item.deal.id),
              onRetryReservation: () => cart.retryReservation(item.deal.id),
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        if (cart.items.isEmpty) return const SizedBox.shrink();
        final hasExpired = cart.hasExpiredReservations;
        final isReserving = cart.isAnyReserving;
        final disableCheckout =
            controller.isCheckingOut.value || hasExpired || isReserving;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasExpired) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off_outlined,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some items have expired reservations. Reserve again or remove them to check out.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 13)),
                      Text('฿${cart.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: FilledButton(
                      onPressed: disableCheckout ? null : controller.checkout,
                      child: controller.isCheckingOut.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Checkout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  final CartItemModel item;
  final ClockService clock;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onRetryReservation;

  const _CartLineCard({
    required this.item,
    required this.clock,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onRetryReservation,
  });

  String _formatRemaining(Duration remaining) {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = clock.now.value;
      final reservation = item.reservation;
      final Duration remaining = reservation != null
          ? reservation.expiresAt.toLocal().difference(now)
          : Duration.zero;
      final bool isExpired =
          !item.isReserving && (reservation == null || remaining <= Duration.zero);

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: isExpired ? Colors.red.shade50.withValues(alpha: 0.35) : Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isExpired
              ? BorderSide(color: Colors.red.shade200)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TheNetworkImage(
                    url: item.deal.imageUrl,
                    width: 64,
                    height: 64,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.deal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                        Text(item.deal.storeName,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600)),
                        Text('฿${item.deal.price.toStringAsFixed(0)} each',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppConfig.primaryGreen,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (isExpired)
                    IconButton(
                      tooltip: 'Remove item',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade700),
                      onPressed: onRemove,
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: onDecrement,
                        ),
                        Text('${item.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: onIncrement,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildReservationStatus(
                isReserving: item.isReserving,
                isExpired: isExpired,
                remaining: remaining,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildReservationStatus({
    required bool isReserving,
    required bool isExpired,
    required Duration remaining,
  }) {
    if (isReserving) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Reserving stock…',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    if (isExpired) {
      return Row(
        children: [
          Icon(Icons.timer_off_outlined, size: 15, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Text(
            'Reservation expired',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onRetryReservation,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              foregroundColor: AppConfig.primaryGreen,
            ),
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text(
              'Reserve again',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final isUrgent = remaining.inSeconds < 60;
    final badgeColor =
        isUrgent ? Colors.orange.shade800 : AppConfig.primaryGreen;
    final bgColor = isUrgent
        ? Colors.orange.shade50
        : AppConfig.primaryGreen.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            'Reserved · ${_formatRemaining(remaining)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: badgeColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}