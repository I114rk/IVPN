import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'log_service.dart';
import 'storage_service.dart';

class CoreDownloadException implements Exception {
  final String message;
  const CoreDownloadException(this.message);

  @override
  String toString() => message;
}

class CoreStatus {
  final String name;
  final String path;
  final bool installed;
  final String? version;

  const CoreStatus({
    required this.name,
    required this.path,
    required this.installed,
    this.version,
  });
}

class CoreManager {
  CoreManager(this._storage, this._logs);

  final StorageService _storage;
  final LogService _logs;
  final http.Client _client = http.Client();

  static const String wintunUrl =
      'https://www.wintun.net/builds/wintun-0.14.1.zip';

  String get singboxPath => p.join(_storage.coresDir.path, 'sing-box.exe');
  String get xrayPath => p.join(_storage.coresDir.path, 'xray.exe');
  String get wintunPath => p.join(_storage.coresDir.path, 'wintun.dll');

  bool get hasSingbox => File(singboxPath).existsSync();
  bool get hasXray => File(xrayPath).existsSync();
  bool get hasWintun => File(wintunPath).existsSync();

  Future<String> installSingbox({
    void Function(double progress)? onProgress,
  }) async {
    _logs.info('core', 'Скачивание sing-box...');
    final release = await _latestRelease('SagerNet/sing-box');
    final asset = _findAsset(
      release,
      (name) => name.toLowerCase().endsWith('windows-amd64.zip'),
    );
    final bytes = await _download(
      asset['browser_download_url'].toString(),
      onProgress,
    );
    await _extractBinary(
      bytes: bytes,
      nameMatcher: (name) => name.toLowerCase().endsWith('sing-box.exe'),
      destination: singboxPath,
    );
    final version = (release['tag_name'] ?? '').toString();
    _logs.info('core', 'sing-box $version установлен');
    return version;
  }

  Future<String> installXray({
    void Function(double progress)? onProgress,
  }) async {
    _logs.info('core', 'Скачивание Xray...');
    final release = await _latestRelease('XTLS/Xray-core');
    final asset = _findAsset(
      release,
      (name) => name.toLowerCase() == 'xray-windows-64.zip',
    );
    final bytes = await _download(
      asset['browser_download_url'].toString(),
      onProgress,
    );
    await _extractBinary(
      bytes: bytes,
      nameMatcher: (name) => name.toLowerCase().endsWith('xray.exe'),
      destination: xrayPath,
    );
    final version = (release['tag_name'] ?? '').toString();
    _logs.info('core', 'Xray $version установлен');
    return version;
  }

  Future<void> installWintun({
    void Function(double progress)? onProgress,
  }) async {
    _logs.info('core', 'Скачивание Wintun...');
    final bytes = await _download(wintunUrl, onProgress);
    await _extractBinary(
      bytes: bytes,
      nameMatcher: (name) =>
          name.toLowerCase().contains('amd64') &&
          name.toLowerCase().endsWith('wintun.dll'),
      destination: wintunPath,
    );
    _logs.info('core', 'Wintun установлен');
  }

  Future<List<CoreStatus>> status() async {
    return [
      CoreStatus(
        name: 'sing-box',
        path: singboxPath,
        installed: hasSingbox,
        version: hasSingbox ? await detectVersion(singboxPath) : null,
      ),
      CoreStatus(
        name: 'Xray',
        path: xrayPath,
        installed: hasXray,
        version: hasXray ? await detectVersion(xrayPath) : null,
      ),
      CoreStatus(
        name: 'Wintun',
        path: wintunPath,
        installed: hasWintun,
      ),
    ];
  }

  Future<String?> detectVersion(String executable) async {
    try {
      final result = await Process.run(executable, ['version']);
      final text = '${result.stdout}\n${result.stderr}';
      for (final line in text.split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> findOpenVpn(String? configured) async {
    if (configured != null &&
        configured.trim().isNotEmpty &&
        File(configured.trim()).existsSync()) {
      return configured.trim();
    }
    const candidates = [
      r'C:\Program Files\OpenVPN\bin\openvpn.exe',
      r'C:\Program Files (x86)\OpenVPN\bin\openvpn.exe',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    try {
      final result = await Process.run('where', ['openvpn.exe']);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && File(trimmed).existsSync()) return trimmed;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _latestRelease(String repository) async {
    final uri =
        Uri.parse('https://api.github.com/repos/$repository/releases/latest');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'IVPN/1.0',
      },
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw CoreDownloadException(
        'GitHub API вернул ${response.statusCode}. '
        'Возможно, превышен лимит запросов — повторите позже.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const CoreDownloadException('Некорректный ответ GitHub API');
    }
    return decoded.cast<String, dynamic>();
  }

  Map<String, dynamic> _findAsset(
    Map<String, dynamic> release,
    bool Function(String name) matcher,
  ) {
    final assets = (release['assets'] as List?) ?? const [];
    for (final item in assets) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final name = (map['name'] ?? '').toString();
      if (matcher(name)) return map;
    }
    throw const CoreDownloadException(
      'В последнем релизе не найден архив для Windows',
    );
  }

  Future<List<int>> _download(
    String url,
    void Function(double progress)? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url))
      ..headers['User-Agent'] = 'IVPN/1.0';
    final response =
        await _client.send(request).timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      throw CoreDownloadException(
        'Не удалось скачать файл: HTTP ${response.statusCode}',
      );
    }
    final total = response.contentLength ?? 0;
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call((received / total).clamp(0.0, 1.0));
      }
    }
    onProgress?.call(1);
    return builder.takeBytes();
  }

  Future<void> _extractBinary({
    required List<int> bytes,
    required bool Function(String name) nameMatcher,
    required String destination,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? found;
    for (final file in archive) {
      if (file.isFile && nameMatcher(file.name)) {
        found = file;
        break;
      }
    }
    if (found == null) {
      throw const CoreDownloadException(
        'В архиве не найден нужный исполняемый файл',
      );
    }
    final data = Uint8List.fromList(found.content);
    await File(destination).writeAsBytes(data, flush: true);
  }

  void dispose() => _client.close();
}
