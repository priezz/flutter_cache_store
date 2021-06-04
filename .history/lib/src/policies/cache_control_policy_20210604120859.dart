import 'timestamp_based_policy.dart';

/// Implements a very basic Policy of HTTP `Cache-Control`
class CacheControlPolicy extends TimestampBasedPolicy {
  /// When cached files reach [maxCount], files with least age to live will be removed first.
  /// Be careful of [minAge]. Your app may still need it for a while.
  /// Both [minAge] and [maxAge] will override `max-age` or `s-maxage` header.
  /// Set [maxAge] to `null` to make it follow `max-age` or `s-maxage` rule.
  CacheControlPolicy({
    int maxCount = 999,
    Duration minAge = const Duration(seconds: 30),
    Duration maxAge = const Duration(days: 30),
  })  : this.minAge = minAge?.inSeconds,
        this.maxAge = maxAge?.inSeconds,
        super(maxCount);

  final int maxAge;
  final int minAge;
  static const _KEY = 'CACHE_STORE:HTML';
  String get storeKey => _KEY;

  int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<void> onDownloaded(
      final CacheItem item, final Map<String, String> headers) async {
    final cc = (headers['cache-control'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .map((s) => s.startsWith('max-age=') || s.startsWith('s-maxage=')
            ? s.split('=')[1]
            : null)
        .where((s) => s != null);

    var age = cc.isEmpty ? 0 : int.tryParse(cc.first) ?? 0;
    if (minAge != null && age < minAge) age = minAge;
    if (maxAge != null && age > maxAge) age = maxAge;

    item.payload = TimestampPayload(now() + age);
  }

  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems) async {
    final ts = now();
    final expired = <CacheItem>[];
    final list = allItems.where((item) {
      if ((getTimestamp(item) ?? 0) > ts) return true;
      expired.add(item);
      return false;
    }).toList();

    if (maxCount == null || list.length <= maxCount) {
      saveItems(list);
      return expired;
    }

    list.sort((a, b) => (getTimestamp(a) ?? 0) - (getTimestamp(b) ?? 0));
    expired.addAll(list.sublist(maxCount));

    saveItems(list.sublist(0, maxCount));
    return expired;
  }
}
