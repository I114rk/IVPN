import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/utils/network_info.dart';

class IpInfoController extends ChangeNotifier {
  IpInfoController({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _publicIp;
  String? _localIp;
  String? _error;
  bool _loading = false;
  DateTime? _updatedAt;

  String? get publicIp => _publicIp;
  String? get localIp => _localIp;
  String? get error => _error;
  bool get isLoading => _loading;
  DateTime? get updatedAt => _updatedAt;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final localFuture = localIpv4();
    try {
      _publicIp = await _fetchPublicIp();
      if (_publicIp == null) throw const FormatException('Invalid IP response');
    } catch (error) {
      _error = error.toString();
    }
    _localIp = await localFuture;
    _updatedAt = DateTime.now();
    _loading = false;
    notifyListeners();
  }

  Future<String?> _fetchPublicIp() async {
    const endpoints = [
      'https://api64.ipify.org?format=json',
      'https://api.ipify.org?format=json',
    ];
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final response = await _client
            .get(
              Uri.parse(endpoint),
              headers: const {'accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(response.body);
        final value = decoded is Map ? decoded['ip']?.toString().trim() : null;
        if (value != null && InternetAddress.tryParse(value) != null)
          return value;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
