import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import '../../core/models/app_settings.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../../services/connection_controller.dart';
import '../../services/hwid_service.dart';
import '../../services/settings_controller.dart';
import '../pages/home_page.dart';
import '../pages/logs_page.dart';
import '../pages/servers_page.dart';
import '../pages/settings_page.dart';
import '../pages/subscriptions_page.dart';
import '../widgets/app_title_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _index = 0;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) return;
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final connection = context.read<ConnectionController>();
    await connection.disconnect();
    await windowManager.destroy();
  }

  void _go(int index) {
    setState(() => _index = index);
  }

  Widget _buildPages() {
    return IndexedStack(
      index: _index,
      children: [
        HomePage(onNavigate: _go),
        ServersPage(onNavigate: _go),
        const SubscriptionsPage(),
        const LogsPage(),
        const SettingsPage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return _buildMobile(context);

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extended = constraints.maxWidth >= 1080;
                return Row(
                  children: [
                    NavigationRail(
                      extended: extended,
                      minExtendedWidth: 208,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      selectedIndex: _index,
                      onDestinationSelected: _go,
                      groupAlignment: -0.9,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.shield_outlined),
                          selectedIcon: Icon(Icons.shield_rounded),
                          label: _RailLabel('Обзор'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.dns_outlined),
                          selectedIcon: Icon(Icons.dns_rounded),
                          label: _RailLabel('Серверы'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.rss_feed_outlined),
                          selectedIcon: Icon(Icons.rss_feed_rounded),
                          label: _RailLabel('Подписки'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.terminal_outlined),
                          selectedIcon: Icon(Icons.terminal_rounded),
                          label: _RailLabel('Логи'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings_rounded),
                          label: _RailLabel('Настройки'),
                        ),
                      ],
                    ),
                    VerticalDivider(
                      width: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    Expanded(child: _buildPages()),
                  ],
                );
              },
            ),
          ),
          const _StatusBar(),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _MobileStatusBar(),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: _buildPages()),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield_rounded),
            label: context.tr('Обзор'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns_rounded),
            label: context.tr('Серверы'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.rss_feed_outlined),
            selectedIcon: const Icon(Icons.rss_feed_rounded),
            label: context.tr('Подписки'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal_outlined),
            selectedIcon: const Icon(Icons.terminal_rounded),
            label: context.tr('Логи'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('Настройки'),
          ),
        ],
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(context.tr(text));
}

class _MobileStatusBar extends StatelessWidget {
  const _MobileStatusBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = context.watch<ConnectionController>();

    final (statusText, statusColor) = switch (connection.engineState.status) {
      _ when connection.isConnected => (
        connection.activeProfile?.displayName ?? context.tr('Подключено'),
        scheme.primary,
      ),
      _ when connection.isConnecting => (
        context.tr('Подключение…'),
        scheme.tertiary,
      ),
      _ when connection.lastError != null => (
        context.tr('Ошибка'),
        scheme.error,
      ),
      _ => (context.tr('Отключено'), scheme.onSurfaceVariant),
    };

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: statusColor),
            ),
          ),
          if (connection.isConnected) ...[
            Icon(
              Icons.arrow_downward_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              formatBytes(connection.download),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_upward_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              formatBytes(connection.upload),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = context.watch<ConnectionController>();
    final settings = context.watch<SettingsController>();
    final hwid = context.read<HwidService>();

    final (statusText, statusColor) = switch (connection.engineState.status) {
      _ when connection.isConnected => (
        context.tr('Подключено · {name}', {
          'name': connection.activeProfile?.displayName ?? '',
        }),
        scheme.primary,
      ),
      _ when connection.isConnecting => (
        context.tr('Подключение…'),
        scheme.tertiary,
      ),
      _ when connection.lastError != null => (
        context.tr('Ошибка'),
        scheme.error,
      ),
      _ => (context.tr('Отключено'), scheme.onSurfaceVariant),
    };

    final emulation = settings.value.emulation;

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ),
          const SizedBox(width: 16),
          _divider(scheme),
          const SizedBox(width: 16),
          Text(
            '${settings.value.engine.label} · ${settings.value.mode.label}'
            '${settings.value.allowLan && settings.value.mode == ConnectionMode.proxy ? ' · LAN' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (emulation != null) ...[
            const SizedBox(width: 16),
            _divider(scheme),
            const SizedBox(width: 16),
            Text(
              context.tr('Эмуляция: {name}', {'name': emulation.name}),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const Spacer(),
          FutureBuilder<String>(
            future: hwid.value,
            builder: (context, snapshot) {
              final value = snapshot.data;
              return Text(
                value == null ? 'HWID …' : 'HWID ${value.substring(0, 8)}…',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) =>
      Container(width: 1, height: 12, color: scheme.outlineVariant);
}
