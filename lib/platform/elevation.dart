import 'dart:ffi';
import 'dart:io';

class ElevationService {
  static bool? _cachedAdmin;

  static bool isAdmin() {
    if (!Platform.isWindows) return false;
    if (_cachedAdmin != null) return _cachedAdmin!;
    try {
      final shell32 = DynamicLibrary.open('shell32.dll');
      final isUserAnAdmin =
          shell32.lookupFunction<Int32 Function(), int Function()>(
        'IsUserAnAdmin',
      );
      _cachedAdmin = isUserAnAdmin() != 0;
    } catch (_) {
      _cachedAdmin = false;
    }
    return _cachedAdmin!;
  }

  static Future<bool> relaunchElevated() async {
    if (!Platform.isWindows) return false;
    try {
      final executable = Platform.resolvedExecutable;
      final escaped = executable.replaceAll('"', '`"');
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-Command',
          'Start-Process -FilePath "$escaped" -Verb RunAs',
        ],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
