import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  final _query = ''.obs;
  Worker? _debounceWorker;
  int _latestRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    _debounceWorker = debounce<String>(
      _query,
      _search,
      time: const Duration(milliseconds: 300),
    );
  }

  void onQueryChanged(String query) {
    _query.value = query;

    // หากผู้ใช้ลบข้อความจนว่าง ให้ยกเลิกผลลัพธ์ของ Request ที่ค้างอยู่และรีเซ็ตหน้าจอทันที
    if (query.trim().isEmpty) {
      _latestRequestId++;
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final int requestId = ++_latestRequestId;
    isLoading.value = true;
    hasSearched.value = true;

    try {
      final found = await dealRepo.search(trimmed);
      // ทิ้งผลลัพธ์ทันทีหากมีคำค้นหาใหม่ถูกส่งออกไปหลังจาก Request นี้
      if (requestId != _latestRequestId) return;

      results.assignAll(found);
    } catch (e) {
      if (requestId != _latestRequestId) return;
      LogService.error('search failed', e);
    } finally {
      // ปิดสถานะ Loading เฉพาะเมื่อ Request นี้ยังเป็นตัวล่าสุดอยู่เท่านั้น
      if (requestId == _latestRequestId) {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    _debounceWorker?.dispose();
    super.onClose();
  }
}