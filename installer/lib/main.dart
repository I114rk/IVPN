import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivpn/platform/device_info.dart';
import 'package:ivpn/ui/theme/app_theme.dart';
import 'package:window_manager/legacy.dart';

import 'install_service.dart';
import 'l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(940, 660),
    minimumSize: Size(860, 600),
    center: true,
    title: 'IVPN Setup',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const InstallerApp());
}

class InstallerApp extends StatefulWidget {
  const InstallerApp({super.key});

  @override
  State<InstallerApp> createState() => _InstallerAppState();
}

class _InstallerAppState extends State<InstallerApp> {
  int _seed = seedPalette.first;

  @override
  void initState() {
    super.initState();
    DeviceInfo.create().accentColor().then((value) {
      if (value == null || !mounted) return;
      setState(() => _seed = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IVPN Setup',
      theme: buildAppTheme(seedColor: _seed, brightness: Brightness.light),
      darkTheme: buildAppTheme(seedColor: _seed, brightness: Brightness.dark),
      home: const InstallerPage(),
    );
  }
}

class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});

  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  final _service = InstallService();
  final _pathController = TextEditingController();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  int _step = 0;
  bool _desktopShortcut = true;
  bool _startMenuShortcut = true;
  bool _launchAfter = true;
  bool _sendHwid = true;
  bool _installing = false;
  double _progress = 0;
  String _status = '';
  String? _error;
  InstallResult? _result;

  @override
  void initState() {
    super.initState();
    _pathController.text = InstallService.defaultInstallDir;
  }

  @override
  void dispose() {
    _pathController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          _TitleBar(title: 'IVPN Setup', scheme: scheme),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroPanel(step: _step),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 28, 36, 22),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildWelcome(context);
      case 1:
        return _buildOptions(context);
      case 2:
        return _buildProgress(context);
      default:
        return _buildDone(context);
    }
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Добро пожаловать'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('Мастер установит IVPN и поможет сразу добавить подписку.'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.shield_rounded,
                  title: tr('Безопасное подключение'),
                  text: tr(
                    'sing-box, Xray, WireGuard и OpenVPN в одном клиенте. '
                    'Режимы TUN и системного прокси.',
                  ),
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.rss_feed_rounded,
                  title: tr('Подписка за один шаг'),
                  text: tr(
                    'Вставьте ссылку — серверы, HWID и лимит устройств '
                    'настроятся автоматически.',
                  ),
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.palette_outlined,
                  title: 'Material You',
                  text: tr('Цветовая схема подстраивается под акцент Windows.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(tr('Продолжить')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Параметры установки'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('Выберите папку и дополнительные действия.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: tr('Папка установки'),
                    prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                    suffixIcon: IconButton(
                      tooltip: tr('Выбрать папку'),
                      onPressed: _installing ? null : _browse,
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _check(
                  value: _desktopShortcut,
                  onChanged: (value) =>
                      setState(() => _desktopShortcut = value),
                  title: tr('Ярлык на рабочем столе'),
                ),
                _check(
                  value: _startMenuShortcut,
                  onChanged: (value) =>
                      setState(() => _startMenuShortcut = value),
                  title: tr('Ярлык в меню «Пуск»'),
                ),
                _check(
                  value: _launchAfter,
                  onChanged: (value) => setState(() => _launchAfter = value),
                  title: tr('Запустить IVPN после установки'),
                ),
                const SizedBox(height: 12),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.rss_feed_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('Подписка'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('необязательно'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: tr('Название (необязательно)'),
                    prefixIcon: const Icon(
                      Icons.label_outline_rounded,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: tr('Ссылка на подписку'),
                    hintText: 'https://example.com/sub/…',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _sendHwid,
                  onChanged: (value) => setState(() => _sendHwid = value),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(tr('Отправлять HWID при активации')),
                  subtitle: Text(tr('Нужно для учёта устройств в Remnawave')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: _error!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _installing ? null : () => setState(() => _step = 0),
              child: Text(tr('Назад')),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _installing ? null : _install,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(tr('Установить')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (_progress * 100).clamp(0, 100).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Установка IVPN'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress <= 0 ? null : _progress,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          tr('Не закрывайте окно мастера.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 46,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr('IVPN установлен'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Приложение готово к работе.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _resultRow(
                  tr('Папка'),
                  File(result.executablePath).parent.path,
                ),
                if (result.subscriptionTitle != null) ...[
                  const SizedBox(height: 8),
                  _resultRow(tr('Подписка'), result.subscriptionTitle!),
                ],
                if (result.serversAdded > 0) ...[
                  const SizedBox(height: 8),
                  _resultRow(
                    tr('Серверов добавлено'),
                    '${result.serversAdded}',
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _launchInstalled,
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              label: Text(tr('Запустить IVPN')),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _openInstallFolder,
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              label: Text(tr('Открыть папку')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => windowManager.destroy(),
            child: Text(tr('Закрыть')),
          ),
        ),
      ],
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: _installing
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _resultRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _browse() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = 'Выберите папку установки IVPN'
$dialog.ShowNewFolderButton = $true
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $dialog.SelectedPath }
''';
    try {
      final result = await Process.run('powershell', [
        '-STA',
        '-NoProfile',
        '-Command',
        script,
      ]);
      final path = result.stdout.toString().trim();
      if (!mounted || path.isEmpty) return;
      setState(() => _pathController.text = path);
    } catch (_) {}
  }

  Future<void> _install() async {
    if (_installing) return;
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = tr('Укажите папку установки'));
      return;
    }
    final directory = Directory(path);
    if (await directory.exists()) {
      final entries = await directory.list().take(1).toList();
      if (entries.isNotEmpty) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('Папка не пуста')),
            content: Text(
              'Файлы в «$path» будут заменены. '
              'Подписки и настройки сохранятся.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('Отмена')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('Продолжить')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() {
      _step = 2;
      _progress = 0.01;
      _status = tr('Подготовка…');
      _error = null;
      _installing = true;
    });

    try {
      final data = await rootBundle.load('assets/payload.zip');
      final payload = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final result = await _service.install(
        InstallOptions(
          installDir: path,
          desktopShortcut: _desktopShortcut,
          startMenuShortcut: _startMenuShortcut,
          launchAfterInstall: _launchAfter,
          subscriptionUrl: _urlController.text.trim(),
          subscriptionName: _nameController.text.trim(),
          sendHwid: _sendHwid,
        ),
        payload,
        onProgress: (message, progress) {
          if (!mounted) return;
          setState(() {
            _status = message;
            _progress = progress;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _installing = false;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _step = 1;
        _progress = 0;
        _error = error is InstallException
            ? error.message
            : tr('Не удалось установить: {error}', {'error': error});
      });
    }
  }

  Future<void> _launchInstalled() async {
    final result = _result;
    if (result == null) return;
    try {
      await Process.start(
        result.executablePath,
        const [],
        workingDirectory: File(result.executablePath).parent.path,
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }

  Future<void> _openInstallFolder() async {
    final result = _result;
    if (result == null) return;
    try {
      await Process.start('explorer.exe', [
        File(result.executablePath).parent.path,
      ], mode: ProcessStartMode.detached);
    } catch (_) {}
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            _WindowButton(
              icon: Icons.remove_rounded,
              tooltip: tr('Свернуть'),
              onTap: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: tr('Закрыть'),
              onTap: () => windowManager.destroy(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      icon: Icon(icon),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'IVPN',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              tr('VPN-клиент для Windows'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 28),
            _heroFeature(
              Icons.rss_feed_rounded,
              tr('Подписки'),
              'Remnawave, HWID',
            ),
            _heroFeature(Icons.bolt_rounded, tr('Движки'), 'sing-box, Xray'),
            _heroFeature(Icons.lan_rounded, tr('Режимы'), 'TUN, Proxy, LAN'),
            const Spacer(),
            Row(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: index <= step ? 0.9 : 0.25,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'v1.0.1',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
