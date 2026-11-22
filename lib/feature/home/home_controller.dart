import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  bool _isRefreshing = false;

  // ตัวนับรอบของข้อมูล (Epoch/Generation token) เพิ่มค่าทุกครั้งที่ Refresh
  // เพื่อใช้ตัดทิ้ง Request ของ loadMore() รอบเก่าที่ยังค้างอยู่
  int _feedEpoch = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final int epoch = ++_feedEpoch;
    _isRefreshing = true;
    // ยกเลิกสถานะการโหลดหน้าถัดไปของรอบเก่าทันที
    _isFetchingMore = false;

    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (isClosed || epoch != _feedEpoch) return;

      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
      refreshController.resetNoData();
    } catch (e) {
      if (isClosed || epoch != _feedEpoch) return;
      LogService.error('refresh deals failed', e);
      refreshController.refreshFailed();
    } finally {
      if (epoch == _feedEpoch) {
        _isRefreshing = false;
      }
    }
  }

  Future<void> loadMore() async {
    if (_isRefreshing) {
      refreshController.loadComplete();
      return;
    }
    if (_isFetchingMore) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }

    final int epoch = _feedEpoch;
    final int nextPage = _page + 1;
    _isFetchingMore = true;

    try {
      final res = await dealRepo.fetchDeals(page: nextPage);
      // หากผู้ใช้กด Refresh ระหว่างที่หน้านี้กำลังโหลดอยู่ ให้ทิ้งผลลัพธ์เก่าทันที
      if (isClosed || epoch != _feedEpoch) return;

      _page = nextPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);

      if (hasMore) {
        refreshController.loadComplete();
      } else {
        refreshController.loadNoData();
      }
    } catch (e) {
      if (isClosed || epoch != _feedEpoch) return;
      LogService.error('loadMore failed', e);
      refreshController.loadFailed();
    } finally {
      if (epoch == _feedEpoch) {
        _isFetchingMore = false;
      }
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}