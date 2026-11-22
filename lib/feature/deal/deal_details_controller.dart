import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  late final DealModel deal;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();
    deal = Get.arguments as DealModel;
    _quantityLeft.value = deal.quantityLeft;
    analytics.logEvent('deal_details_view', {
      'deal_id': deal.id,
      'source': Get.parameters['source'] ?? 'unknown',
    });
    // เก็บ instance ของ Worker ไว้ เพื่อนำไปยกเลิกเมื่อ Controller ถูกปิด
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _recheckAvailability() async {
    if (isClosed) return;
    LogService.log('re-checking availability for deal ${deal.id}');
    try {
      final fresh = await dealRepo.fetchById(deal.id);
      if (isClosed) return;
      _quantityLeft.value = fresh.quantityLeft;
    } catch (e) {
      LogService.error('re-check availability failed for deal ${deal.id}', e);
    }
  }

  void addToCart() {
    cartService.add(deal);
    Get.snackbar(
      'Added to bag',
      '${deal.name} — pick up ${deal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }
}