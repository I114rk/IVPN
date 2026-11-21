import 'dart:ffi';
import 'dart:io';

class SystemProxyService {
  static const _key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  Map<String, String>? _previous;

  Future<void> enable(String host, int port) async {
    if (!Platform.isWindows) return;
    await _capture();
    await _setString('ProxyServer', '$host:$port');
    await _setString('ProxyOverride', '<local>');
    await _setDword('ProxyEnable', 1);
    _notify();
  }

  Future<void> disable() async {
    if (!Platform.isWindows) return;
    await _setDword('ProxyEnable', 0);
    final previous = _previous;
    if (previous != null) {
      final server = previous['ProxyServer'] ?? '';
      final override = previous['ProxyOverride'] ?? '';
      if (server.isNotEmpty) await _setString('ProxyServer', server);
      if (override.isNotEmpty) await _setString('ProxyOverride', override);
      final enabled = int.tryParse(previous['ProxyEnable'] ?? '0') ?? 0;
      await _setDword('ProxyEnable', enabled);
    }
    _previous = null;
    _notify();
  }

  Future<void> cleanupIfOurs(Set<int> ports) async {
    if (!Platform.isWindows) return;
    final enabled = await _read('ProxyEnable');
    final server = await _read('ProxyServer');
    if (enabled != '1' || server == null) return;
    for (final port in ports) {
      if (server == '127.0.0.1:$port' || server == 'localhost:$port') {
        await _setDword('ProxyEnable', 0);
        _notify();
        return;
      }
    }
  }

  Future<void> _capture() async {
    _previous ??= {
      'ProxyEnable': await _read('ProxyEnable') ?? '0',
      'ProxyServer': await _read('ProxyServer') ?? '',
      'ProxyOverride': await _read('ProxyOverride') ?? '',
    };
  }

  Future<String?> _read(String name) async {
    try {
      final result = await Process.run(
        'reg',
        ['query', _key, '/v', name],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final output = result.stdout.toString();
      for (final line in output.split(RegExp(r'\r?\n'))) {
        final match =
            RegExp('^\\s*${RegExp.escape(name)}\\s+REG_\\w+\\s+(.*)\$')
                .firstMatch(line);
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          if (value.startsWith('0x')) {
            return int.tryParse(value.substring(2), radix: 16)?.toString();
          }
          return value;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setString(String name, String value) async {
    try {
      await Process.run(
        'reg',
        ['add', _key, '/v', name, '/t', 'REG_SZ', '/d', value, '/f'],
        runInShell: false,
      );
    } catch (_) {}
  }

  Future<void> _setDword(String name, int value) async {
    try {
      await Process.run(
        'reg',
        [
          'add',
          _key,
          '/v',
          name,
          '/t',
          'REG_DWORD',
          '/d',
          value.toString(),
          '/f',
        ],
        runInShell: false,
      );
    } catch (_) {}
  }

  void _notify() {
    if (!Platform.isWindows) return;
    try {
      final wininet = DynamicLibrary.open('wininet.dll');
      final setOption = wininet.lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
          int Function(Pointer<Void>, int, Pointer<Void>, int)>(
        'InternetSetOptionW',
      );
      setOption(nullptr, 39, nullptr, 0);
      setOption(nullptr, 37, nullptr, 0);
    } catch (_) {}
  }
}
