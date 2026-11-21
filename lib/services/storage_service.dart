import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  late final Directory root;
  late final Directory coresDir;
  late final Directory configsDir;
  late final Directory logsDir;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final base = await getApplicationSupportDirectory();
    root = Directory(base.path);
    coresDir = Directory(p.join(root.path, 'cores'));
    configsDir = Directory(p.join(root.path, 'configs'));
    logsDir = Directory(p.join(root.path, 'logs'));
    for (final directory in [root, coresDir, configsDir, logsDir]) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
    _initialized = true;
  }

  File get stateFile => File(p.join(root.path, 'state.json'));
  File get logFile => File(p.join(logsDir.path, 'ivpn.log'));

  Future<Map<String, dynamic>> loadState() async {
    try {
      if (!await stateFile.exists()) return {};
      final content = await stateFile.readAsString();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      return decoded is Map ? decoded.cast<String, dynamic>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    try {
      final temporary = File('${stateFile.path}.tmp');
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state),
        flush: true,
      );
      if (await stateFile.exists()) {
        await stateFile.delete();
      }
      await temporary.rename(stateFile.path);
    } catch (_) {}
  }
}
