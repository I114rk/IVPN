import 'dart:io';

abstract class DeviceInfoService {
  Future<String> machineId();
  Future<String> osName();
  Future<String> osVersion();
  Future<String> deviceModel();
  Future<int?> accentColor();
}

class DeviceInfo {
  static DeviceInfoService create() {
    if (Platform.isWindows) return WindowsDeviceInfoService();
    return GenericDeviceInfoService();
  }
}

class GenericDeviceInfoService implements DeviceInfoService {
  String? _machineId;

  @override
  Future<String> machineId() async {
    _machineId ??= '${Platform.localHostname}-${Platform.operatingSystem}';
    return _machineId!;
  }

  @override
  Future<String> osName() async {
    final name = Platform.operatingSystem;
    if (name.isEmpty) return 'Unknown';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Future<String> osVersion() async => Platform.operatingSystemVersion;

  @override
  Future<String> deviceModel() async => Platform.localHostname;

  @override
  Future<int?> accentColor() async => null;
}

class WindowsDeviceInfoService implements DeviceInfoService {
  String? _machineId;

  static const _cryptographyKey =
      r'HKLM\SOFTWARE\Microsoft\Cryptography';
  static const _currentVersionKey =
      r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion';
  static const _biosKey = r'HKLM\HARDWARE\DESCRIPTION\System\BIOS';
  static const _dwmKey = r'HKCU\Software\Microsoft\Windows\DWM';

  @override
  Future<String> machineId() async {
    _machineId ??=
        await _readRegistry(_cryptographyKey, 'MachineGuid') ??
            Platform.localHostname;
    return _machineId!;
  }

  @override
  Future<String> osName() async {
    final product = await _readRegistry(_currentVersionKey, 'ProductName') ?? '';
    final build = int.tryParse(
          await _readRegistry(_currentVersionKey, 'CurrentBuildNumber') ?? '',
        ) ??
        0;
    if (build >= 22000) return 'Windows 11';
    if (product.isNotEmpty) return product;
    return 'Windows';
  }

  @override
  Future<String> osVersion() async {
    final build =
        await _readRegistry(_currentVersionKey, 'CurrentBuildNumber') ?? '';
    final display =
        await _readRegistry(_currentVersionKey, 'DisplayVersion') ?? '';
    final ubr = await _readRegistry(_currentVersionKey, 'UBR') ?? '';
    final buildFull = ubr.isNotEmpty ? '$build.$ubr' : build;
    if (display.isNotEmpty) return '$buildFull ($display)';
    return buildFull.isEmpty ? Platform.operatingSystemVersion : buildFull;
  }

  @override
  Future<String> deviceModel() async {
    final model = await _readRegistry(_biosKey, 'SystemProductName') ?? '';
    if (model.isNotEmpty && model.toLowerCase() != 'system product name') {
      return model;
    }
    final manufacturer =
        await _readRegistry(_biosKey, 'SystemManufacturer') ?? '';
    if (manufacturer.isNotEmpty) return '$manufacturer PC';
    return Platform.localHostname;
  }

  @override
  Future<int?> accentColor() async {
    final raw = await _readRegistry(_dwmKey, 'ColorizationColor');
    if (raw == null || raw.isEmpty) return null;
    final parsed = int.tryParse(raw.replaceFirst('0x', ''), radix: 16);
    return parsed;
  }

  Future<String?> _readRegistry(String key, String value) async {
    try {
      final result = await Process.run(
        'reg',
        ['query', key, '/v', value],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final output = result.stdout.toString();
      for (final line in output.split(RegExp(r'\r?\n'))) {
        final match =
            RegExp('^\\s*${RegExp.escape(value)}\\s+REG_\\w+\\s+(.*)\$')
                .firstMatch(line);
        if (match != null) return match.group(1)?.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
