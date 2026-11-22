import 'package:get/get.dart';

import '../util/log_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
class AnalyticsService extends GetxService {
  final events = <AnalyticsEvent>[].obs;
  final Set<String> _trackedImpressions = <String>{};

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  /// Logs a `deal_impression` once per [source] + [dealId] until reset.
  void logImpression({
    required int dealId,
    required String source,
    int? position,
  }) {
    final dedupeKey = '$source:$dealId';
    if (!_trackedImpressions.add(dedupeKey)) return;

    logEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      if (position != null) 'position': position,
    });
  }

  /// Clears tracked impression keys (all or scoped by [source] prefix).
  void resetImpressions([String? source]) {
    if (source == null) {
      _trackedImpressions.clear();
    } else {
      _trackedImpressions.removeWhere((key) => key.startsWith('$source:'));
    }
  }
}