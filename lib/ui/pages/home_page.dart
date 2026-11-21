import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/engine.dart';
import '../../core/models/lan_client.dart';
import '../../core/models/proxy_profile.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/network_info.dart';
import '../../platform/elevation.dart';
import '../../services/connection_controller.dart';
import '../../services/settings_controller.dart';
import '../../services/subscription_controller.dart';
import '../utils/ui_helpers.dart';
import '../widgets/connect_orb.dart';
import '../widgets/protocol_avatar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _ticker;
  String? _lanIp;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadLanIp();
  }

  Future<void> _loadLanIp() async {
    final ip = await localIpv4();
    if (mounted) setState(() => _lanIp = ip);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _toggle(
    ConnectionController connection,
    ProxyProfile? profile,
  ) async {
    if (connection.isConnected || connection.isConnecting) {
      await connection.disconnect();
      return;
    }
    if (profile == null) {
      widget.onNavigate(1);
      return;
    }
    try {
      await connection.connect(profile);
    } catch (error) {
      if (!mounted) return;
      await showConnectionError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = context.watch<ConnectionController>();
    final settings = context.watch<SettingsController>();
    final subscriptions = context.watch<SubscriptionController>();

    final profiles = subscriptions.allProfiles;
    final selected = subscriptions.profileById(
      settings.value.selectedProfileId,
    );
    final display = connection.activeProfile ?? selected;
    final duplicates = subscriptions.duplicateProfileIds;

    final statusText = connection.isConnected
        ? 'Защищено'
        : connection.isConnecting
        ? 'Подключение…'
        : 'Не подключено';
    final statusColor = connection.isConnected
        ? scheme.primary
        : connection.isConnecting
        ? scheme.tertiary
        : scheme.onSurfaceVariant;

    if (profiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Обзор',
              subtitle: 'Подключение и быстрые настройки',
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.rss_feed_rounded,
                title: 'Нет серверов',
                message:
                    'Добавьте подписку Remnawave или ссылку на конфигурацию, '
                    'чтобы начать пользоваться IVPN.',
                action: FilledButton.icon(
                  onPressed: () => widget.onNavigate(2),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Добавить подписку'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Обзор',
            subtitle: 'Подключение и быстрые настройки',
            actions: [
              _MetaChip(
                icon: settings.value.mode == ConnectionMode.tun
                    ? Icons.vpn_lock_rounded
                    : Icons.language_rounded,
                label: settings.value.mode.label,
              ),
              _MetaChip(
                icon: Icons.memory_rounded,
                label: settings.value.engine.label,
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 860;
              final main = _buildMainCard(
                context,
                connection,
                settings,
                subscriptions,
                display,
                statusText,
                statusColor,
              );
              final side = _buildSidePanel(
                context,
                connection,
                settings,
                statusColor,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: main),
                    const SizedBox(width: 20),
                    SizedBox(width: 320, child: side),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [main, const SizedBox(height: 20), side],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildRecentServers(context, subscriptions, settings, duplicates),
          if (settings.value.allowLan) ...[
            const SizedBox(height: 20),
            _buildLanDevices(context, connection, settings),
          ],
        ],
      ),
    );
  }

  Widget _buildLanDevices(
    BuildContext context,
    ConnectionController connection,
    SettingsController settings,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clients = connection.lanClients;
    final online = clients.where((client) => client.isActive).length;
    final address = _lanIp == null
        ? 'адрес:порт'
        : '$_lanIp:${settings.value.mixedPort}';

    Widget content;
    if (settings.value.mode != ConnectionMode.proxy) {
      content = Text(
        'Прокси-порт открывается только в режиме Proxy.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (connection.engineState.type == EngineType.xray) {
      content = Text(
        'Статистика подключений доступна только с ядром sing-box.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (clients.isEmpty) {
      content = Text(
        'Пока никто не подключён. Укажите на устройстве в вашей сети прокси '
        '$address.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      content = Column(
        children: [
          for (var index = 0; index < clients.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            _buildLanClientRow(context, clients[index], scheme, theme),
          ],
        ],
      );
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.devices_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                'Устройства в локальной сети',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: online > 0
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$online онлайн',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: online > 0
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                address,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildLanClientRow(
    BuildContext context,
    LanClient client,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: client.isActive
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.devices_other_rounded,
              size: 18,
              color: client.isActive
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      client.ip,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: client.isActive
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        client.isActive ? 'онлайн' : 'офлайн',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: client.isActive
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  client.hosts.isEmpty
                      ? 'Нет активных запросов'
                      : client.hosts.take(3).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    formatBytes(client.download),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.upload_rounded, size: 13, color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    formatBytes(client.upload),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                client.isActive
                    ? '${client.activeConnections} соед.'
                    : formatRelative(client.lastSeen),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    ConnectionController connection,
    SettingsController settings,
    SubscriptionController subscriptions,
    ProxyProfile? display,
    String statusText,
    Color statusColor,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final subscription = display == null
        ? null
        : subscriptions.subscriptionOf(display);
    final needsAdmin =
        settings.value.mode == ConnectionMode.tun &&
        !ElevationService.isAdmin();

    return SectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: theme.textTheme.labelLarge?.copyWith(color: statusColor),
              ),
              const Spacer(),
              _MetaChip(
                icon: settings.value.mode == ConnectionMode.tun
                    ? Icons.vpn_lock_rounded
                    : Icons.language_rounded,
                label: settings.value.mode.label,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConnectOrb(
            connected: connection.isConnected,
            busy: connection.isConnecting,
            onPressed: () => _toggle(connection, display),
          ),
          const SizedBox(height: 16),
          if (display == null)
            Row(
              children: [
                Icon(Icons.dns_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Сервер не выбран',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => widget.onNavigate(1),
                  child: const Text('Выбрать'),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ProtocolAvatar(
                    profile: display,
                    error: subscriptions.isDuplicate(display),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${display.endpoint} · ${display.protocol.label}'
                          '${subscription != null ? ' · ${subscription.displayName}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate(1),
                    child: const Text('Сменить'),
                  ),
                ],
              ),
            ),
          if (needsAdmin) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 18,
                  color: scheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TUN-режим требует прав администратора',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (connection.lastError != null && !connection.isConnected) ...[
            const SizedBox(height: 14),
            Text(
              connection.lastError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    ConnectionController connection,
    SettingsController settings,
    Color statusColor,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сессия', style: theme.textTheme.titleSmall),
              const SizedBox(height: 16),
              _StatRow(
                icon: Icons.timer_outlined,
                label: 'Длительность',
                value: formatDuration(connection.sessionDuration),
              ),
              const SizedBox(height: 14),
              _StatRow(
                icon: Icons.download_rounded,
                label: 'Получено',
                value: formatBytes(connection.download),
              ),
              const SizedBox(height: 14),
              _StatRow(
                icon: Icons.upload_rounded,
                label: 'Отправлено',
                value: formatBytes(connection.upload),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Режим подключения', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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
                  selected: {settings.value.mode},
                  onSelectionChanged: (selection) {
                    settings.patch(mode: selection.first);
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                settings.value.mode == ConnectionMode.tun
                    ? 'Весь трафик через TUN-интерфейс. Требует прав администратора.'
                    : 'Системный прокси 127.0.0.1:${settings.value.mixedPort}'
                          '${settings.value.allowLan ? ' · доступен в локальной сети' : ''}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Движок: ${settings.value.engine.label}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(4),
                child: const Text('Настройки'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentServers(
    BuildContext context,
    SubscriptionController subscriptions,
    SettingsController settings,
    Set<String> duplicates,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profiles = subscriptions.allProfiles.take(6).toList();
    if (profiles.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Быстрый выбор', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onNavigate(1),
                child: const Text('Все серверы'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final profile in profiles)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => settings.patch(selectedProfileId: profile.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    ProtocolAvatar(
                      profile: profile,
                      size: 34,
                      error: duplicates.contains(profile.id),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: duplicates.contains(profile.id)
                                  ? scheme.error
                                  : null,
                            ),
                          ),
                          Text(
                            profile.endpoint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.value.selectedProfileId == profile.id)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    IconButton(
                      tooltip: 'Подключиться',
                      onPressed: () => _connectProfile(profile),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _connectProfile(ProxyProfile profile) async {
    final connection = context.read<ConnectionController>();
    try {
      await connection.connect(profile);
    } catch (error) {
      if (!mounted) return;
      await showConnectionError(context, error);
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
