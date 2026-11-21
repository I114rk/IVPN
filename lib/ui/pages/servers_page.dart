import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/proxy_profile.dart';
import '../../core/models/subscription.dart';
import '../../core/utils/latency.dart';
import '../../services/connection_controller.dart';
import '../../services/settings_controller.dart';
import '../../services/subscription_controller.dart';
import '../utils/ui_helpers.dart';
import '../widgets/protocol_avatar.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  final TextEditingController _search = TextEditingController();
  final Map<String, int?> _latency = {};
  String _query = '';
  bool _onlyDuplicates = false;
  bool _pinging = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ProxyProfile profile) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return profile.name.toLowerCase().contains(query) ||
        profile.server.toLowerCase().contains(query) ||
        profile.protocol.label.toLowerCase().contains(query) ||
        (profile.subscriptionName ?? '').toLowerCase().contains(query);
  }

  Future<void> _pingAll() async {
    if (_pinging) return;
    final profiles = context.read<SubscriptionController>().allProfiles;
    if (profiles.isEmpty) return;
    setState(() => _pinging = true);
    final results = <String, int?>{};
    for (var index = 0; index < profiles.length; index += 8) {
      final batch = profiles.skip(index).take(8).toList();
      await Future.wait(
        batch.map((profile) async {
          results[profile.id] = await measureLatency(
            profile.server,
            profile.port,
          );
        }),
      );
      if (!mounted) return;
      setState(() => _latency.addAll(results));
    }
    if (mounted) setState(() => _pinging = false);
  }

  Future<void> _connect(ProxyProfile profile) async {
    final connection = context.read<ConnectionController>();
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
    final subscriptions = context.watch<SubscriptionController>();
    final settings = context.watch<SettingsController>();
    final duplicates = subscriptions.duplicateProfileIds;

    final groups = <Subscription, List<ProxyProfile>>{};
    for (final subscription in subscriptions.subscriptions) {
      final items = subscription.profiles
          .where(
            (profile) =>
                _matches(profile) &&
                (!_onlyDuplicates || duplicates.contains(profile.id)),
          )
          .toList();
      if (items.isNotEmpty) groups[subscription] = items;
    }
    final totalProfiles = subscriptions.allProfiles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Серверы',
                subtitle: totalProfiles == 0
                    ? 'Список пуст'
                    : '$totalProfiles серверов · ${duplicates.length} с повторяющимся IP',
                actions: [
                  FilterChip(
                    label: const Text('Дубликаты'),
                    avatar: duplicates.isEmpty
                        ? null
                        : Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: scheme.error,
                          ),
                    selected: _onlyDuplicates,
                    onSelected: (value) =>
                        setState(() => _onlyDuplicates = value),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pinging ? null : _pingAll,
                    icon: _pinging
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    label: const Text('Пинг'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final controller = context.read<SubscriptionController>();
                      await controller.refreshAll();
                      if (context.mounted) {
                        showAppSnack(context, 'Подписки обновлены');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Обновить'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 460,
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени, адресу или протоколу',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? EmptyState(
                  icon: Icons.dns_outlined,
                  title: totalProfiles == 0
                      ? 'Нет серверов'
                      : 'Ничего не найдено',
                  message: totalProfiles == 0
                      ? 'Добавьте подписку, чтобы здесь появились серверы.'
                      : 'Измените поисковый запрос или отключите фильтр дубликатов.',
                  action: totalProfiles == 0 && widget.onNavigate != null
                      ? FilledButton.icon(
                          onPressed: () => widget.onNavigate!(2),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Добавить подписку'),
                        )
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 20, 28),
                  children: [
                    for (final entry in groups.entries)
                      _buildGroup(
                        context,
                        entry.key,
                        entry.value,
                        settings.value.selectedProfileId,
                        duplicates,
                        scheme,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGroup(
    BuildContext context,
    Subscription subscription,
    List<ProxyProfile> profiles,
    String? selectedId,
    Set<String> duplicates,
    ColorScheme scheme,
  ) {
    final theme = Theme.of(context);
    final duplicateCount = profiles
        .where((profile) => duplicates.contains(profile.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  subscription.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subscription.format,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (duplicateCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$duplicateCount дублей IP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final profile in profiles)
          _buildTile(
            context,
            profile,
            selected: profile.id == selectedId,
            duplicate: duplicates.contains(profile.id),
            scheme: scheme,
          ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    ProxyProfile profile, {
    required bool selected,
    required bool duplicate,
    required ColorScheme scheme,
  }) {
    final theme = Theme.of(context);
    final latency = _latency[profile.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: duplicate
            ? scheme.errorContainer.withValues(alpha: 0.28)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: duplicate
              ? scheme.error.withValues(alpha: 0.75)
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: duplicate ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.read<SettingsController>().patch(
            selectedProfileId: profile.id,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ProtocolAvatar(profile: profile, error: duplicate),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: duplicate ? scheme.error : null,
                              ),
                            ),
                          ),
                          if (duplicate) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ДУБЛЬ IP',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onError,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.endpoint} · ${profile.protocol.label} · ${profile.securityLabel}',
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
                if (_pinging && latency == null)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (latency != null)
                  _latencyChip(context, latency, scheme),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Подключиться',
                  onPressed: () => _connect(profile),
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: duplicate ? scheme.error : scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _latencyChip(BuildContext context, int latency, ColorScheme scheme) {
    final color = latency < 120
        ? scheme.primary
        : latency < 300
        ? scheme.tertiary
        : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$latency ms',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
