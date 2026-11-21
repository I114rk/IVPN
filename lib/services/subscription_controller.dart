import 'package:flutter/foundation.dart';

import '../core/models/proxy_profile.dart';
import '../core/models/subscription.dart';
import '../core/subscription/subscription_client.dart';
import '../core/utils/ids.dart';
import 'hwid_service.dart';
import 'log_service.dart';
import 'settings_controller.dart';
import 'state_store.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController(
    this._store,
    this._logs,
    this._hwid,
    this._settings,
    this._client,
  );

  final StateStore _store;
  final LogService _logs;
  final HwidService _hwid;
  final SettingsController _settings;
  final SubscriptionClient _client;

  List<Subscription> _subscriptions = [];
  bool _busy = false;
  String? _busySubscriptionId;

  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isBusy => _busy;
  String? get busySubscriptionId => _busySubscriptionId;

  List<ProxyProfile> get allProfiles =>
      [for (final subscription in _subscriptions) ...subscription.profiles];

  Future<void> init() async {
    _subscriptions = _store.subscriptions;
    notifyListeners();
  }

  ProxyProfile? profileById(String? id) {
    if (id == null) return null;
    for (final subscription in _subscriptions) {
      for (final profile in subscription.profiles) {
        if (profile.id == id) return profile;
      }
    }
    return null;
  }

  Subscription? subscriptionOf(ProxyProfile profile) {
    for (final subscription in _subscriptions) {
      if (subscription.profiles.any((item) => item.id == profile.id)) {
        return subscription;
      }
    }
    return null;
  }

  Future<Subscription> add({required String name, required String url}) async {
    final id = randomId(8);
    final now = DateTime.now();
    _setBusy(true, id);
    try {
      final result = await _fetch(url: url, id: id, name: name);
      final subscription = Subscription(
        id: id,
        name: name.trim().isEmpty ? _hostOf(url) : name.trim(),
        url: url.trim(),
        addedAt: now,
        updatedAt: now,
        format: result.parsed.format,
        title: result.title,
        announce: result.announce,
        supportUrl: result.supportUrl,
        webPageUrl: result.webPageUrl,
        updateIntervalHours: result.updateIntervalHours,
        hwidActive: result.hwidActive,
        hwidLimitReached: result.hwidLimitReached,
        hwidNotSupported: result.hwidNotSupported,
        usage: result.usage,
        profiles: result.parsed.profiles,
      );
      _subscriptions.add(subscription);
      await _persist();
      final duplicates = duplicateCountIn(subscription);
      if (duplicates > 0) {
        _logs.warn(
          'sub',
          '«${subscription.displayName}»: $duplicates серверов с одинаковым IP',
        );
      }
      return subscription;
    } finally {
      _setBusy(false, null);
    }
  }

  Future<Subscription> refresh(String id) async {
    final index = _subscriptions.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw StateError('Подписка не найдена');
    }
    final current = _subscriptions[index];
    _setBusy(true, id);
    try {
      final result = await _fetch(
        url: current.url,
        id: current.id,
        name: current.name,
      );
      final updated = _applyResult(current, result);
      _subscriptions[index] = updated;
      await _persist();
      final duplicates = duplicateCountIn(updated);
      if (duplicates > 0) {
        _logs.warn(
          'sub',
          '«${updated.displayName}»: $duplicates серверов с одинаковым IP',
        );
      }
      return updated;
    } catch (error) {
      _subscriptions[index] = current.copyWith(error: error.toString());
      await _persist();
      rethrow;
    } finally {
      _setBusy(false, null);
    }
  }

  Future<void> refreshAll() async {
    for (final subscription in List<Subscription>.of(_subscriptions)) {
      try {
        await refresh(subscription.id);
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    final removed = _subscriptions.where((item) => item.id == id).toList();
    _subscriptions.removeWhere((item) => item.id == id);
    await _persist();
    final selectedId = _settings.value.selectedProfileId;
    if (selectedId != null &&
        removed.any(
          (subscription) =>
              subscription.profiles.any((profile) => profile.id == selectedId),
        )) {
      await _settings.patch(clearSelectedProfile: true);
    }
    notifyListeners();
  }

  Subscription _applyResult(
    Subscription base,
    SubscriptionFetchResult result,
  ) {
    return Subscription(
      id: base.id,
      name: base.name,
      url: base.url,
      addedAt: base.addedAt,
      updatedAt: DateTime.now(),
      format: result.parsed.format,
      title: result.title,
      announce: result.announce,
      supportUrl: result.supportUrl,
      webPageUrl: result.webPageUrl,
      updateIntervalHours: result.updateIntervalHours,
      hwidActive: result.hwidActive,
      hwidLimitReached: result.hwidLimitReached,
      hwidNotSupported: result.hwidNotSupported,
      usage: result.usage ?? base.usage,
      profiles: result.parsed.profiles,
    );
  }

  Future<SubscriptionFetchResult> _fetch({
    required String url,
    required String id,
    required String name,
  }) async {
    final settings = _settings.value;
    final emulation = settings.emulation;
    final headers = settings.sendHwid
        ? await _hwid.headers(
            deviceOs: emulation?.deviceOs,
            deviceOsVersion: emulation?.deviceOsVersion,
            deviceModel: emulation?.deviceModel,
          )
        : <String, String>{};
    return _client.fetch(
      url: url,
      userAgent: settings.effectiveUserAgent,
      subscriptionId: id,
      subscriptionName: name,
      headers: headers,
    );
  }

  // --- duplicate detection by server address / IP -------------------------

  static String _normalizeHost(String host) =>
      host.trim().toLowerCase().replaceAll('[', '').replaceAll(']', '');

  Map<String, int> _serverCounts([Iterable<ProxyProfile>? profiles]) {
    final counts = <String, int>{};
    for (final profile in profiles ?? allProfiles) {
      final key = _normalizeHost(profile.server);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Set<String> get duplicateProfileIds {
    final counts = _serverCounts();
    final ids = <String>{};
    for (final subscription in _subscriptions) {
      for (final profile in subscription.profiles) {
        if ((counts[_normalizeHost(profile.server)] ?? 0) > 1) {
          ids.add(profile.id);
        }
      }
    }
    return ids;
  }

  bool isDuplicate(ProxyProfile profile) =>
      duplicateProfileIds.contains(profile.id);

  int duplicateCountIn(Subscription subscription) {
    final counts = _serverCounts(subscription.profiles);
    var count = 0;
    for (final profile in subscription.profiles) {
      if ((counts[_normalizeHost(profile.server)] ?? 0) > 1) count++;
    }
    return count;
  }

  Map<String, int> duplicateHostsIn(Subscription subscription) {
    final counts = _serverCounts(subscription.profiles);
    return {
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key: entry.value,
    };
  }

  String _hostOf(String url) {
    final uri = Uri.tryParse(url.trim());
    final host = uri?.host ?? '';
    return host.isEmpty ? 'Подписка' : host;
  }

  void _setBusy(bool busy, String? id) {
    _busy = busy;
    _busySubscriptionId = id;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.saveSubscriptions(_subscriptions);
    notifyListeners();
  }
}
