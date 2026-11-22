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

  final _deal = Rxn<DealModel>();
  DealModel? get deal => _deal.value;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();
    _initDeal();
    // เก็บ instance ของ Worker ไว้ เพื่อนำไปยกเลิกเมื่อ Controller ถูกปิด
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _initDeal() async {
    final arg = Get.arguments;
    if (arg is DealModel) {
      _deal.value = arg;
      _quantityLeft.value = arg.quantityLeft;
      _logView(arg.id);
      return;
    }

    final rawId = Get.parameters['id'];
    final id = int.tryParse(rawId ?? '');
    if (id == null) {
      errorMessage.value = 'Invalid deal link';
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final fetched = await dealRepo.fetchById(id);
      if (isClosed) return;
      _deal.value = fetched;
      _quantityLeft.value = fetched.quantityLeft;
      _logView(fetched.id);
    } catch (e) {
      if (isClosed) return;
      LogService.error('failed to load deal $id from deep link', e);
      errorMessage.value = 'Deal not found or failed to load';
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  void _logView(int dealId) {
    analytics.logEvent('deal_details_view', {
      'deal_id': dealId,
      'source': Get.parameters['source'] ?? 'unknown',
    });
  }

  Future<void> retry() => _initDeal();

  Future<void> _recheckAvailability() async {
    final currentDeal = deal;
    if (isClosed || currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    try {
      final fresh = await dealRepo.fetchById(currentDeal.id);
      if (isClosed) return;
      _quantityLeft.value = fresh.quantityLeft;
    } catch (e) {
      LogService.error(
          're-check availability failed for deal ${currentDeal.id}', e);
    }
  }

  void addToCart() {
    final currentDeal = deal;
    if (currentDeal == null) return;
    cartService.add(currentDeal);
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
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