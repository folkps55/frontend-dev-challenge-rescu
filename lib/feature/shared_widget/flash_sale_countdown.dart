import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/clock_service.dart';

/// Displays a live 1-second countdown until [endsAt] using a single shared
/// [ClockService]. Only the [Text] node rebuilds on each tick.
class FlashSaleCountdown extends StatelessWidget {
  final DateTime endsAt;
  final String? prefix;
  final String expiredText;
  final TextStyle? style;

  const FlashSaleCountdown({
    super.key,
    required this.endsAt,
    this.prefix,
    this.expiredText = 'Ended',
    this.style,
  });

  ClockService get _clock => Get.isRegistered<ClockService>()
      ? Get.find<ClockService>()
      : Get.put(ClockService(), permanent: true);

  String _formatRemaining(Duration remaining) {
    if (remaining <= Duration.zero) {
      return expiredText;
    }

    final totalHours = remaining.inHours;
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    final formatted = totalHours > 0
        ? '${totalHours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';

    return prefix != null ? '$prefix$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock;
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Obx(() {
      final remaining = endsAt.toLocal().difference(clock.now.value);
      return Text(
        _formatRemaining(remaining),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: effectiveStyle,
      );
    });
  }
}