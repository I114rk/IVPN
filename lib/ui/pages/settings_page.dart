import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_version.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/client_emulation.dart';
import '../../core/utils/network_info.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/elevation.dart';
import '../../services/core_manager.dart';
import '../../services/hwid_service.dart';
import '../../services/settings_controller.dart';
import '../../services/storage_service.dart';
import '../dialogs/emulate_client_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _port = TextEditingController();
  final TextEditingController _customUa = TextEditingController();
  final TextEditingController _openvpn = TextEditingController();

  List<CoreStatus>? _cores;
  final Map<String, double> _progress = {};
  String? _openvpnFound;
  bool _openvpnBusy = false;
  String? _lanIp;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().value;
    _port.text = '${settings.mixedPort}';
    _customUa.text = settings.customUserAgent ?? '';
    _openvpn.text = settings.openvpnPath ?? '';
    if (Platform.isAndroid) return;
    _loadCores();
    _resolveOpenVpn();
    _loadLanIp();
  }

  Future<void> _loadLanIp() async {
    final ip = await localIpv4();
    if (mounted) setState(() => _lanIp = ip);
  }

  Future<void> _copyLanAddress() async {
    final host = _lanIp;
    if (host == null) return;
    final port = context.read<SettingsController>().value.mixedPort;
    await Clipboard.setData(ClipboardData(text: '$host:$port'));
    if (mounted) {
      showAppSnack(context, context.tr('Адрес прокси скопирован'));
    }
  }

  Future<void> _openFirewallPorts() async {
    final port = context.read<SettingsController>().value.mixedPort;
    final commands = [
      'advfirewall firewall add rule name=IVPN-Proxy-TCP-$port '
          'dir=in action=allow protocol=TCP localport=$port',
      'advfirewall firewall add rule name=IVPN-Proxy-TCP-${port + 1} '
          'dir=in action=allow protocol=TCP localport=${port + 1}',
      'advfirewall firewall add rule name=IVPN-Proxy-UDP-$port '
          'dir=in action=allow protocol=UDP localport=$port',
    ];
    final inner = commands.map((command) => 'netsh $command').join('; ');
    final script =
        "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command',\"$inner\"";
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        script,
      ]);
      if (!mounted) return;
      if (result.exitCode == 0) {
        showAppSnack(
          context,
          context.tr(
            'Подтвердите запрос UAC, чтобы открыть порты в брандмауэре',
          ),
        );
      } else {
        showAppSnack(
          context,
          context.tr('Не удалось открыть порты: {error}', {
            'error': result.stderr,
          }),
          error: true,
        );
      }
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  void dispose() {
    _port.dispose();
    _customUa.dispose();
    _openvpn.dispose();
    super.dispose();
  }

  Future<void> _loadCores() async {
    final cores = await context.read<CoreManager>().status();
    if (mounted) setState(() => _cores = cores);
  }

  Future<void> _install(String name) async {
    final manager = context.read<CoreManager>();
    setState(() => _progress[name] = 0);
    try {
      void onProgress(double value) {
        if (mounted) setState(() => _progress[name] = value);
      }

      switch (name) {
        case 'sing-box':
          await manager.installSingbox(onProgress: onProgress);
          break;
        case 'Xray':
          await manager.installXray(onProgress: onProgress);
          break;
        case 'Wintun':
          await manager.installWintun(onProgress: onProgress);
          break;
      }
      await _loadCores();
      if (mounted) {
        showAppSnack(context, context.tr('{name} установлен', {'name': name}));
      }
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _progress.remove(name));
    }
  }

  Future<void> _resolveOpenVpn() async {
    setState(() => _openvpnBusy = true);
    final found = await context.read<CoreManager>().findOpenVpn(
      _openvpn.text.trim(),
    );
    if (mounted) {
      setState(() {
        _openvpnFound = found;
        _openvpnBusy = false;
      });
    }
  }

  Future<void> _applyOpenVpn() async {
    await context.read<SettingsController>().patch(
      openvpnPath: _openvpn.text.trim(),
    );
    await _resolveOpenVpn();
  }

  void _applyPort() {
    final value = int.tryParse(_port.text.trim());
    if (value == null || value < 1024 || value > 65535) {
      showAppSnack(
        context,
        context.tr('Порт должен быть от 1024 до 65535'),
        error: true,
      );
      return;
    }
    context.read<SettingsController>().patch(mixedPort: value);
    showAppSnack(
      context,
      context.tr('Порт изменён на {port}', {'port': value}),
    );
  }

  Future<void> _copyHwid() async {
    final value = await context.read<HwidService>().value;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showAppSnack(context, context.tr('HWID скопирован'));
  }

  Future<void> _chooseEmulation() async {
    final result = await EmulateClientDialog.show(context);
    if (result == null || !mounted) return;
    final settings = context.read<SettingsController>();
    if (result.isEmpty) {
      await settings.patch(clearEmulation: true);
      if (mounted) showAppSnack(context, context.tr('Эмуляция отключена'));
    } else {
      await settings.patch(emulatedClientId: result);
      final client = ClientEmulation.byId(result);
      if (mounted) {
        showAppSnack(
          context,
          context.tr('Включена эмуляция: {name}', {
            'name': client?.name ?? result,
          }),
        );
      }
    }
  }

  Future<void> _disableEmulation() async {
    await context.read<SettingsController>().patch(clearEmulation: true);
    if (mounted) showAppSnack(context, context.tr('Эмуляция отключена'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = context.watch<SettingsController>();
    final settings = controller.value;
    final emulation = settings.emulation;
    final storage = context.read<StorageService>();
    final isMobile = Platform.isAndroid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: context.tr('Настройки'),
                subtitle: context.tr('Внешний вид, подключение, HWID и ядра'),
              ),
              const SizedBox(height: 20),
              _section(
                title: context.tr('Внешний вид'),
                icon: Icons.palette_outlined,
                children: [
                  _label(context.tr('Язык')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownMenu<AppLanguage>(
                        width: 280,
                        initialSelection: settings.language,
                        dropdownMenuEntries: [
                          DropdownMenuEntry(
                            value: AppLanguage.system,
                            label: context.tr('Системный'),
                          ),
                          const DropdownMenuEntry(
                            value: AppLanguage.ru,
                            label: 'Русский',
                          ),
                          const DropdownMenuEntry(
                            value: AppLanguage.en,
                            label: 'English',
                          ),
                          const DropdownMenuEntry(
                            value: AppLanguage.de,
                            label: 'Deutsch',
                          ),
                        ],
                        onSelected: (language) {
                          if (language != null) {
                            controller.patch(language: language);
                          }
                        },
                      ),
                      const SizedBox(width: 14),
                      Text(
                        context.tr('Применяется сразу'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label(context.tr('Тема оформления')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<ThemePreference>(
                      segments: [
                        for (final item in ThemePreference.values)
                          ButtonSegment(
                            value: item,
                            label: Text(context.tr(item.label)),
                          ),
                      ],
                      selected: {settings.theme},
                      onSelectionChanged: (selection) =>
                          controller.patch(theme: selection.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isMobile)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Динамический цвет')),
                      subtitle: Text(
                        context.tr('Использовать акцентный цвет Windows'),
                      ),
                      value: settings.dynamicColor,
                      onChanged: (value) =>
                          controller.patch(dynamicColor: value),
                    ),
                  const SizedBox(height: 8),
                  _label(context.tr('Цветовая схема')),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final value in seedPalette)
                        _seedSwatch(
                          value,
                          selected: settings.seedColor == value,
                          onTap: () => controller.patch(seedColor: value),
                          scheme: scheme,
                        ),
                      if (!isMobile)
                        ActionChip(
                          avatar: Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: settings.seedColor == null
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          label: Text(context.tr('Акцент Windows')),
                          onPressed: () =>
                              controller.patch(clearSeedColor: true),
                        ),
                    ],
                  ),
                ],
              ),
              _section(
                title: context.tr('Подключение'),
                icon: Icons.tune_rounded,
                children: [
                  if (!isMobile) ...[
                    _label(context.tr('Режим')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<ConnectionMode>(
                        segments: const [
                          ButtonSegment(
                            value: ConnectionMode.tun,
                            icon: Icon(Icons.vpn_lock_outlined, size: 18),
                            label: Text('TUN'),
                          ),
                          ButtonSegment(
                            value: ConnectionMode.proxy,
                            icon: Icon(Icons.language_outlined, size: 18),
                            label: Text('Proxy'),
                          ),
                        ],
                        selected: {settings.mode},
                        onSelectionChanged: (selection) =>
                            controller.patch(mode: selection.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label(context.tr('Ядро по умолчанию')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<CoreEngine>(
                        segments: const [
                          ButtonSegment(
                            value: CoreEngine.singbox,
                            label: Text('Sing-box'),
                          ),
                          ButtonSegment(
                            value: CoreEngine.xray,
                            label: Text('Xray'),
                          ),
                          ButtonSegment(
                            value: CoreEngine.openvpn,
                            label: Text('OpenVPN'),
                          ),
                        ],
                        selected: {settings.engine},
                        onSelectionChanged: (selection) =>
                            controller.patch(engine: selection.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _port,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _applyPort(),
                            decoration: InputDecoration(
                              labelText: context.tr('Порт'),
                              suffixIcon: IconButton(
                                tooltip: context.tr('Применить'),
                                onPressed: _applyPort,
                                icon: const Icon(Icons.check_rounded, size: 18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              context.tr(
                                'Mixed-порт для Proxy-режима. Xray использует {socks} (SOCKS) и {http} (HTTP).',
                                {
                                  'socks': settings.mixedPort,
                                  'http': settings.mixedPort + 1,
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label(context.tr('TUN-стек')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', label: Text('System')),
                          ButtonSegment(value: 'gvisor', label: Text('GVisor')),
                          ButtonSegment(value: 'mixed', label: Text('Mixed')),
                        ],
                        selected: {settings.tunStack},
                        onSelectionChanged: (selection) =>
                            controller.patch(tunStack: selection.first),
                      ),
                    ),
                  ],
                  if (isMobile)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_lock_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr(
                                'На Android используется TUN через VpnService '
                                'и встроенное ядро sing-box. Режим Proxy '
                                'и выбор ядра недоступны.',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!isMobile)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Системный прокси')),
                      subtitle: Text(
                        context.tr(
                          'Автоматически включать прокси Windows в Proxy-режиме',
                        ),
                      ),
                      value: settings.setSystemProxy,
                      onChanged: (value) =>
                          controller.patch(setSystemProxy: value),
                    ),
                  if (!isMobile) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Доступ из локальной сети')),
                      subtitle: Text(
                        context.tr(
                          'Слушать прокси на всех интерфейсах (0.0.0.0). '
                          'Применяется после переподключения',
                        ),
                      ),
                      value: settings.allowLan,
                      onChanged: (value) => controller.patch(allowLan: value),
                    ),
                    if (settings.allowLan) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.devices_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    settings.mode == ConnectionMode.proxy
                                        ? context.tr(
                                            'Другие устройства могут использовать IVPN как прокси',
                                          )
                                        : context.tr(
                                            'В TUN-режиме прокси-порт не открывается — включите Proxy',
                                          ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _lanIp == null
                                        ? context.tr('Определение…')
                                        : '$_lanIp:${settings.mixedPort}',
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('Копировать адрес'),
                                  onPressed: _lanIp == null
                                      ? null
                                      : _copyLanAddress,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _openFirewallPorts,
                                  icon: const Icon(
                                    Icons.security_rounded,
                                    size: 18,
                                  ),
                                  label: Text(context.tr('Открыть порты')),
                                ),
                              ],
                            ),
                            Text(
                              context.tr(
                                'SOCKS/HTTP на одном порту (sing-box). Xray: SOCKS {socks}, HTTP {http}. Может потребоваться разрешение брандмауэра.',
                                {
                                  'socks': settings.mixedPort,
                                  'http': settings.mixedPort + 1,
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Автоподключение')),
                    subtitle: Text(
                      context.tr(
                        'Подключаться к выбранному серверу при запуске IVPN',
                      ),
                    ),
                    value: settings.autoConnect,
                    onChanged: (value) => controller.patch(autoConnect: value),
                  ),
                ],
              ),
              _section(
                title: context.tr('Подписки и HWID'),
                icon: Icons.fingerprint_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Отправлять HWID')),
                    subtitle: Text(
                      context.tr(
                        'Заголовки x-hwid, x-device-os, x-ver-os, x-device-model',
                      ),
                    ),
                    value: settings.sendHwid,
                    onChanged: (value) => controller.patch(sendHwid: value),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FutureBuilder<String>(
                      future: context.read<HwidService>().value,
                      builder: (context, snapshot) {
                        return Row(
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                snapshot.data ?? context.tr('Вычисление…'),
                                style: const TextStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr('Копировать HWID'),
                              onPressed: snapshot.hasData ? _copyHwid : null,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Автообновление подписок')),
                    subtitle: Text(
                      context.tr(
                        'Обновлять при запуске, если истёк интервал панели',
                      ),
                    ),
                    value: settings.autoRefreshSubscriptions,
                    onChanged: (value) =>
                        controller.patch(autoRefreshSubscriptions: value),
                  ),
                  const Divider(height: 28),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: emulation != null
                            ? scheme.tertiary.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.smart_toy_outlined,
                              color: emulation != null
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emulation == null
                                        ? context.tr('Эмуляция не включена')
                                        : context.tr('Эмуляция: {name}', {
                                            'name': emulation.name,
                                          }),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    emulation?.userAgent ??
                                        context.tr(
                                          'User-Agent отправляется как IVPN',
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _chooseEmulation,
                              child: Text(
                                emulation == null
                                    ? context.tr('Эмулировать клиент')
                                    : context.tr('Изменить'),
                              ),
                            ),
                          ],
                        ),
                        if (emulation != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _disableEmulation,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: Text(context.tr('Отключить эмуляцию')),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label(context.tr('User-Agent по умолчанию')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownMenu<UserAgentPreset>(
                        width: 280,
                        initialSelection: settings.userAgentPreset,
                        label: Text(context.tr('Формат')),
                        dropdownMenuEntries: [
                          for (final preset in UserAgentPreset.values)
                            DropdownMenuEntry(
                              value: preset,
                              label: context.tr(preset.label),
                            ),
                        ],
                        onSelected: (preset) {
                          if (preset != null) {
                            controller.patch(userAgentPreset: preset);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          emulation != null
                              ? context.tr('Переопределяется эмуляцией клиента')
                              : context.tr('Эффективный: {value}', {
                                  'value': settings.effectiveUserAgent,
                                }),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (settings.userAgentPreset == UserAgentPreset.custom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customUa,
                      enabled: emulation == null,
                      onSubmitted: (value) =>
                          controller.patch(customUserAgent: value.trim()),
                      decoration: InputDecoration(
                        labelText: context.tr('Свой User-Agent'),
                        hintText: 'my-client/1.0',
                      ),
                    ),
                  ],
                ],
              ),
              if (!isMobile)
                _section(
                  title: context.tr('Ядра'),
                  icon: Icons.memory_rounded,
                  trailing: [
                    IconButton(
                      tooltip: context.tr('Обновить статус'),
                      onPressed: _loadCores,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                  children: [
                    if (_cores == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else
                      for (final core in _cores!) _coreRow(core, theme, scheme),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Wintun нужен для TUN-режима. sing-box и Xray скачиваются '
                        'из официальных релизов GitHub.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 28),
                    _label('OpenVPN'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _openvpn,
                            decoration: InputDecoration(
                              labelText: context.tr('Путь к openvpn.exe'),
                              hintText:
                                  r'C:\Program Files\OpenVPN\bin\openvpn.exe',
                            ),
                            onSubmitted: (_) => _applyOpenVpn(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _openvpnBusy ? null : _applyOpenVpn,
                          icon: _openvpnBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded, size: 18),
                          label: Text(context.tr('Проверить')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _openvpnFound == null
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: _openvpnFound == null
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _openvpnFound ??
                                context.tr(
                                  'OpenVPN не найден — установите его или укажите путь',
                                ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              _section(
                title: context.tr('О приложении'),
                icon: Icons.info_outline_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: AppVersion.value,
                              builder: (context, snapshot) => Text(
                                'IVPN v${snapshot.data ?? '…'}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile
                                  ? 'Flutter · Material You · Android'
                                  : 'Flutter · Material You · Windows',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: ElevationService.isAdmin()
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              ElevationService.isAdmin()
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.person_outline_rounded,
                              size: 14,
                              color: ElevationService.isAdmin()
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ElevationService.isAdmin()
                                  ? context.tr('Администратор')
                                  : context.tr('Обычные права'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ElevationService.isAdmin()
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          storage.root.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          try {
                            Process.run('explorer', [storage.root.path]);
                          } catch (_) {}
                        },
                        child: Text(context.tr('Открыть')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Настройки, подписки и логи хранятся локально. '
                      'Приложение не собирает телеметрию.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
    List<Widget> trailing = const [],
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _seedSwatch(
    int value, {
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    final color = Color(0xFF000000 | (value & 0x00FFFFFF));
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final hex = (value & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return Tooltip(
      message: '#$hex',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: dark ? Colors.white : Colors.black87,
                )
              : null,
        ),
      ),
    );
  }

  Widget _coreRow(CoreStatus core, ThemeData theme, ColorScheme scheme) {
    final progress = _progress[core.name];
    final installing = progress != null;
    final icon = switch (core.name) {
      'Wintun' => Icons.lan_outlined,
      'Xray' => Icons.hub_outlined,
      _ => Icons.memory_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  core.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  core.installed
                      ? (core.version ?? context.tr('Установлен'))
                      : context.tr('Не установлен'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (installing)
            SizedBox(
              width: 110,
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 6,
              ),
            )
          else ...[
            if (core.installed)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OK',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            FilledButton.tonal(
              onPressed: () => _install(core.name),
              child: Text(
                core.installed
                    ? context.tr('Обновить')
                    : context.tr('Установить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
