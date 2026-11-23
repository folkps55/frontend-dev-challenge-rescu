import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';

void main() {
  test('DealModel parses API json', () {
    final deal = DealModel.fromJson({
      'id': 7,
      'name': 'Surprise Bakery Bag',
      'description': 'Assorted pastries',
      'imageUrl': 'https://example.com/img.jpg',
      'originalPrice': 150,
      'price': 49,
      'currencyCode': 'THB',
      'quantityLeft': 3,
      'storeId': 2,
      'storeName': 'Sunrise Bakehouse',
      'storeAddress': '1 Sukhumvit Soi 1, Bangkok',
      'lat': 13.75,
      'lng': 100.5,
      'rating': null,
      'tags': ['bestseller'],
      'pickupWindow': {
        'start': '2026-01-01T10:30:00.000Z',
        'end': '2026-01-01T14:00:00.000Z',
      },
      'flashSaleEndsAt': null,
    });

    expect(deal.id, 7);
    expect(deal.rating, isNull);
    expect(deal.discountPercent, 67);
    expect(deal.isFlashSale, isFalse);
    expect(deal.pickupWindow.start.isUtc, isFalse);
    expect(
      deal.pickupWindow.start,
      DateTime.parse('2026-01-01T10:30:00.000Z').toLocal(),
    );
  });

  test('PickupWindowModel converts UTC to local and checks isToday accurately', () {
    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day, 6, 30);
    final todayWindow = PickupWindowModel.fromJson({
      'start': todayLocal.toUtc().toIso8601String(),
      'end': todayLocal.add(const Duration(hours: 2)).toUtc().toIso8601String(),
    });

    expect(todayWindow.isToday, isTrue);

    final nextMonthLocal = DateTime(now.year, now.month + 1, now.day, 10, 0);
    final nextMonthWindow = PickupWindowModel.fromJson({
      'start': nextMonthLocal.toUtc().toIso8601String(),
      'end': nextMonthLocal.add(const Duration(hours: 2)).toUtc().toIso8601String(),
    });

    expect(nextMonthWindow.isToday, isFalse);
  });
}