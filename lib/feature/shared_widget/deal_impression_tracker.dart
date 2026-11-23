import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

/// Fires a single impression event when [child] stays at least 50% visible
/// in the viewport for [dwellDuration].
class DealImpressionTracker extends StatefulWidget {
  final int dealId;
  final String source;
  final int? position;
  final Duration dwellDuration;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    this.position,
    this.dwellDuration = const Duration(milliseconds: 400),
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _dwellTimer;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      _dwellTimer ??= Timer(widget.dwellDuration, () {
        _dwellTimer = null;
        if (!mounted) return;
        _recordImpression();
      });
    } else {
      _cancelTimer();
    }
  }

  void _recordImpression() {
    if (!Get.isRegistered<AnalyticsService>()) return;
    Get.find<AnalyticsService>().logImpression(
      dealId: widget.dealId,
      source: widget.source,
      position: widget.position,
    );
  }

  void _cancelTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
  }

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealId != widget.dealId ||
        oldWidget.source != widget.source) {
      _cancelTimer();
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(
        'impression_${widget.source}_${widget.dealId}_${widget.position ?? 0}',
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}