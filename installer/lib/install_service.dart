import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:ivpn/core/models/app_settings.dart';
import 'package:ivpn/core/models/subscription.dart';
import 'package:ivpn/core/subscription/subscription_client.dart';
import 'package:ivpn/core/utils/ids.dart';
import 'package:ivpn/platform/device_info.dart';
import 'package:ivpn/services/hwid_service.dart';
import 'package:path/path.dart' as p;

class InstallException implements Exception {
  final String message;
  const InstallException(this.message);

  @override
  String toString() => message;
}

class InstallOptions {
  final String installDir;
  final bool desktopShortcut;
  final bool startMenuShortcut;
  final bool launchAfterInstall;
  final String subscriptionUrl;
  final String subscriptionName;
  final bool sendHwid;

  const InstallOptions({
    required this.installDir,
    this.desktopShortcut = true,
    this.startMenuShortcut = true,
    this.launchAfterInstall = true,
    this.subscriptionUrl = '',
    this.subscriptionName = '',
    this.sendHwid = true,
  });
}

class InstallResult {
  final String executablePath;
  final int serversAdded;
  final String? subscriptionTitle;

  const InstallResult({
    required this.executablePath,
    this.serversAdded = 0,
    this.subscriptionTitle,
  });
}

class InstallService {
  InstallService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String get defaultInstallDir {
    final local =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(local, 'Programs', 'IVPN');
  }

  Future<InstallResult> install(
    InstallOptions options,
    Uint8List payload, {
    void Function(String message, double progress)? onProgress,
  }) async {
    final installDir = Directory(options.installDir);
    await installDir.create(recursive: true);

    onProgress?.call('Распаковка файлов…', 0.02);
    await _extract(payload, installDir, onProgress);

    final executable = File(p.join(installDir.path, 'ivpn.exe'));
    if (!await executable.exists()) {
      throw const InstallException('В установочном пакете не найден ivpn.exe');
    }

    var serversAdded = 0;
    String? subscriptionTitle;
    if (options.subscriptionUrl.trim().isNotEmpty) {
      onProgress?.call('Добавление подписки…', 0.82);
      final subscription = await _fetchSubscription(options);
      await _mergeState(subscription);
      serversAdded = subscription.profiles.length;
      subscriptionTitle = subscription.displayName;
    }

    onProgress?.call('Создание ярлыков…', 0.9);
    if (options.desktopShortcut) {
      await _createShortcut(
        p.join(await _desktopDirectory(), 'IVPN.lnk'),
        executable.path,
        installDir.path,
      );
    }
    if (options.startMenuShortcut) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        await _createShortcut(
          p.join(
            appData,
            'Microsoft',
            'Windows',
            'Start Menu',
            'Programs',
            'IVPN.lnk',
          ),
          executable.path,
          installDir.path,
        );
      }
    }

    onProgress?.call('Регистрация в системе…', 0.96);
    await _writeUninstaller(installDir.path);
    await _registerUninstall(installDir.path, executable.path);

    if (options.launchAfterInstall) {
      onProgress?.call('Запуск IVPN…', 0.99);
      try {
        await Process.start(
          executable.path,
          const [],
          workingDirectory: installDir.path,
          mode: ProcessStartMode.detached,
        );
      } catch (_) {}
    }

    onProgress?.call('Готово', 1);
    return InstallResult(
      executablePath: executable.path,
      serversAdded: serversAdded,
      subscriptionTitle: subscriptionTitle,
    );
  }

  Future<void> _extract(
    Uint8List payload,
    Directory target,
    void Function(String message, double progress)? onProgress,
  ) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(payload);
    } catch (_) {
      throw const InstallException('Повреждён установочный пакет');
    }
    final files = archive.where((file) => file.isFile).toList();
    if (files.isEmpty) {
      throw const InstallException('Установочный пакет пуст');
    }
    var index = 0;
    final targetPath = p.normalize(p.absolute(target.path));
    for (final file in files) {
      final relative = file.name.replaceAll('\\', '/');
      final destinationPath = p.normalize(
        p.absolute(p.joinAll([targetPath, ...relative.split('/')])),
      );
      if (p.isAbsolute(relative) || !p.isWithin(targetPath, destinationPath)) {
        throw const InstallException(
          'Установочный пакет содержит неверный путь',
        );
      }
      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(file.content, flush: false);
      index++;
      onProgress?.call(
        'Распаковка: ${p.basename(relative)}',
        0.05 + 0.72 * index / files.length,
      );
    }
  }

  Future<Subscription> _fetchSubscription(InstallOptions options) async {
    final url = options.subscriptionUrl.trim();
    final name = options.subscriptionName.trim();
    final id = randomId(8);
    try {
      final headers = options.sendHwid
          ? await HwidService(DeviceInfo.create()).headers()
          : const <String, String>{};
      final result = await SubscriptionClient(_client).fetch(
        url: url,
        userAgent: const AppSettings().effectiveUserAgent,
        subscriptionId: id,
        subscriptionName: name,
        headers: headers,
      );
      final now = DateTime.now();
      return Subscription(
        id: id,
        name: name.isEmpty ? _hostOf(url) : name,
        url: url,
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
    } on SubscriptionRequestException catch (error) {
      throw InstallException(error.message);
    } on InstallException {
      rethrow;
    } catch (error) {
      throw InstallException('Не удалось добавить подписку: $error');
    }
  }

  Future<void> _mergeState(Subscription subscription) async {
    final directory = _stateDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'state.json'));

    var state = <String, dynamic>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) state = decoded.cast<String, dynamic>();
      } catch (_) {}
    }

    final subscriptions =
        ((state['subscriptions'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .where((item) => item['url']?.toString() != subscription.url)
            .toList()
          ..add(subscription.toJson());
    state['subscriptions'] = subscriptions;

    final settings = ((state['settings'] as Map?) ?? const {})
        .cast<String, dynamic>();
    if (subscription.profiles.isNotEmpty) {
      settings['selectedProfileId'] = subscription.profiles.first.id;
    }
    state['settings'] = settings;

    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Directory _stateDirectory() {
    final appData =
        Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return Directory(p.join(appData, 'com.ivpn', 'ivpn'));
  }

  Future<void> _createShortcut(
    String linkPath,
    String target,
    String workingDirectory,
  ) async {
    try {
      await Directory(p.dirname(linkPath)).create(recursive: true);
      String quote(String value) => value.replaceAll("'", "''");
      final script =
          '''
\$shell = New-Object -ComObject WScript.Shell
\$shortcut = \$shell.CreateShortcut('${quote(linkPath)}')
\$shortcut.TargetPath = '${quote(target)}'
\$shortcut.WorkingDirectory = '${quote(workingDirectory)}'
\$shortcut.Description = 'IVPN — VPN client'
\$shortcut.IconLocation = '${quote(target)},0'
\$shortcut.Save()
''';
      await Process.run('powershell', ['-NoProfile', '-Command', script]);
    } catch (_) {}
  }

  Future<String> _desktopDirectory() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "[Environment]::GetFolderPath('Desktop')",
      ]);
      final path = result.stdout.toString().trim();
      if (path.isNotEmpty) return path;
    } catch (_) {}
    final profile = Platform.environment['USERPROFILE'] ?? '';
    return p.join(profile, 'Desktop');
  }

  Future<void> _writeUninstaller(String installDir) async {
    String quote(String value) => value.replaceAll("'", "''");
    final script =
        '''
\$ErrorActionPreference = 'SilentlyContinue'
Stop-Process -Name 'ivpn' -Force
Remove-Item -LiteralPath (Join-Path \$env:USERPROFILE 'Desktop\\IVPN.lnk') -Force
Remove-Item -LiteralPath (Join-Path \$env:APPDATA 'Microsoft\\Windows\\Start Menu\\Programs\\IVPN.lnk') -Force
Remove-Item -LiteralPath 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\IVPN' -Recurse -Force
Start-Sleep -Milliseconds 250
Remove-Item -LiteralPath '${quote(installDir)}' -Recurse -Force
''';
    await File(p.join(installDir, 'uninstall.ps1')).writeAsString(script);
  }

  Future<void> _registerUninstall(String installDir, String executable) async {
    final uninstaller = p.join(installDir, 'uninstall.ps1');
    final uninstallCommand =
        'powershell -NoProfile -ExecutionPolicy Bypass -File "$uninstaller"';
    final entries = <List<String>>[
      ['DisplayName', 'IVPN'],
      ['DisplayVersion', '1.0.0'],
      ['Publisher', 'IVPN'],
      ['InstallLocation', installDir],
      ['DisplayIcon', executable],
      ['UninstallString', uninstallCommand],
      ['NoModify', '1', 'REG_DWORD'],
      ['NoRepair', '1', 'REG_DWORD'],
    ];
    for (final entry in entries) {
      final type = entry.length > 2 ? entry[2] : 'REG_SZ';
      try {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\IVPN',
          '/v',
          entry[0],
          '/t',
          type,
          '/d',
          entry[1],
          '/f',
        ]);
      } catch (_) {}
    }
  }

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? 'Подписка' : host;
  }

  void dispose() => _client.close();
}
