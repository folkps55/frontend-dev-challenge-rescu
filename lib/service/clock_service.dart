import 'dart:async';

import 'package:get/get.dart';

/// Shared 1-second ticker service so all live countdown widgets stay in sync
/// without spawning separate timers per card.
class ClockService extends GetxService {
  final now = DateTime.now().obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}