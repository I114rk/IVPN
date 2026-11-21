import '../core/models/app_settings.dart';
import '../core/models/subscription.dart';
import 'storage_service.dart';

class StateStore {
  StateStore(this._storage);

  final StorageService _storage;
  Map<String, dynamic> _state = {};

  Future<void> load() async {
    _state = await _storage.loadState();
  }

  AppSettings get settings {
    final raw = _state['settings'];
    if (raw is Map) return AppSettings.fromJson(raw.cast<String, dynamic>());
    return const AppSettings();
  }

  List<Subscription> get subscriptions {
    final raw = _state['subscriptions'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Subscription.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> saveSettings(AppSettings settings) async {
    _state['settings'] = settings.toJson();
    await _persist();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    _state['subscriptions'] =
        subscriptions.map((subscription) => subscription.toJson()).toList();
    await _persist();
  }

  Future<void> _persist() => _storage.saveState(_state);
}
