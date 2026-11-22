import 'dart:async';
import 'package:flutter/material.dart';

class PickupCountdown extends StatefulWidget {
  final DateTime pickupStart;

  const PickupCountdown({super.key, required this.pickupStart});

  @override
  State<PickupCountdown> createState() => _PickupCountdownState();
}

class _PickupCountdownState extends State<PickupCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();

    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = _calculateRemaining();
        setState(() {
          _remaining = next;
        });
        if (_remaining == Duration.zero) {
          _timer?.cancel();
        }
      });
    }
  }

  Duration _calculateRemaining() {
    final diff = widget.pickupStart.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Text(
        'Ready for pickup',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.green.shade700,
        ),
      );
    }

    return Text(
      'Pickup in ${_formatDuration(_remaining)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.orange.shade800,
      ),
    );
  }
}