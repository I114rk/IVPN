import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/subscription.dart';
import '../../core/utils/byte_format.dart';
import '../../services/connection_controller.dart';
import '../../services/settings_controller.dart';
import '../../services/subscription_controller.dart';
import '../dialogs/add_subscription_dialog.dart';
import '../utils/ui_helpers.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final Set<String> _refreshing = {};

  Future<void> _add() async {
    final subscription = await AddSubscriptionDialog.show(context);
    if (subscription == null || !mounted) return;
    final controller = context.read<SubscriptionController>();
    final duplicates = controller.duplicateCountIn(subscription);
    if (duplicates > 0) {
      showAppSnack(
        context,
        'Добавлено серверов: ${subscription.profiles.length}. '
        'С одинаковым IP: $duplicates',
        warning: true,
      );
    } else {
      showAppSnack(
        context,
        'Добавлено серверов: ${subscription.profiles.length}',
      );
    }
  }

  Future<void> _refresh(Subscription subscription) async {
    setState(() => _refreshing.add(subscription.id));
    final controller = context.read<SubscriptionController>();
    try {
      final updated = await controller.refresh(subscription.id);
      if (!mounted) return;
      final duplicates = controller.duplicateCountIn(updated);
      if (duplicates > 0) {
        showAppSnack(
          context,
          'Подписка обновлена. Серверов с одинаковым IP: $duplicates',
          warning: true,
        );
      } else {
        showAppSnack(context, 'Подписка обновлена');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _refreshing.remove(subscription.id));
    }
  }

  Future<void> _delete(Subscription subscription) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить подписку?',
      message:
          '«${subscription.displayName}» и ${subscription.profiles.length} серверов будут удалены.',
    );
    if (!confirmed || !mounted) return;

    final connection = context.read<ConnectionController>();
    final controller = context.read<SubscriptionController>();
    final active = connection.activeProfile;
    if (active != null &&
        subscription.profiles.any((profile) => profile.id == active.id)) {
      await connection.disconnect();
    }
    await controller.remove(subscription.id);
    if (mounted) showAppSnack(context, 'Подписка удалена');
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subscriptions = context.watch<SubscriptionController>();
    final settings = context.watch<SettingsController>();
    final emulation = settings.value.emulation;
    final items = subscriptions.subscriptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          child: PageHeader(
            title: 'Подписки',
            subtitle:
                '${items.length} подписок · ${subscriptions.allProfiles.length} серверов',
            actions: [
              if (emulation != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          size: 16, color: scheme.onTertiaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        emulation.name,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                tooltip: 'Обновить все',
                onPressed: subscriptions.isBusy
                    ? null
                    : () async {
                        await subscriptions.refreshAll();
                        if (context.mounted) {
                          showAppSnack(context, 'Подписки обновлены');
                        }
                      },
                icon: subscriptions.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
              FilledButton.icon(
                onPressed: subscriptions.isBusy ? null : _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: Icons.rss_feed_rounded,
                  title: 'Пока нет подписок',
                  message:
                      'Вставьте ссылку Remnawave — IVPN сам определит формат '
                      'и отправит HWID при необходимости.',
                  action: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить подписку'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 20, 28),
                  children: [
                    for (final subscription in items)
                      _buildCard(
                        context,
                        subscription,
                        subscriptions,
                        scheme,
                        theme,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    Subscription subscription,
    SubscriptionController controller,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final duplicates = controller.duplicateCountIn(subscription);
    final duplicateHosts = controller.duplicateHostsIn(subscription);
    final refreshing = _refreshing.contains(subscription.id);
    final usage = subscription.usage;

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.rss_feed_rounded,
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subscription.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if ((subscription.webPageUrl ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => _openUrl(subscription.webPageUrl),
                  child: const Text('Открыть'),
                ),
            ],
          ),
          if ((subscription.announce ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 18, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subscription.announce!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (usage == null)
            Row(
              children: [
                Icon(Icons.data_usage_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Сервер не передал данные о трафике',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Text('Трафик', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${formatBytes(usage.used)} / '
                  '${usage.hasTotal ? formatBytes(usage.total) : 'Безлимит'}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (usage.hasTotal)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: usage.ratio,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  usage.hasTotal
                      ? 'Осталось ${formatBytes((usage.total - usage.used).clamp(0, usage.total))}'
                      : 'Безлимитный трафик',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (usage.expireDate != null) ...[
                  Icon(Icons.event_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    usage.isExpired
                        ? 'Истекла ${formatDate(usage.expireDate)}'
                        : 'до ${formatDate(usage.expireDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: usage.isExpired
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                context,
                '${subscription.profiles.length} серверов',
                scheme: scheme,
              ),
              _chip(
                context,
                subscription.format,
                scheme: scheme,
              ),
              if (subscription.hwidActive)
                _chip(
                  context,
                  'HWID активен',
                  scheme: scheme,
                  icon: Icons.verified_user_outlined,
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                ),
              if (subscription.hwidLimitReached)
                _chip(
                  context,
                  'Лимит устройств',
                  scheme: scheme,
                  icon: Icons.devices_other_rounded,
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                ),
              if (subscription.hwidNotSupported)
                _chip(
                  context,
                  'HWID не отправлен',
                  scheme: scheme,
                  icon: Icons.warning_amber_rounded,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
              if (duplicates > 0)
                Tooltip(
                  message: duplicateHosts.entries
                      .take(10)
                      .map((entry) => '${entry.key} × ${entry.value}')
                      .join('\n'),
                  child: _chip(
                    context,
                    '$duplicates дублей IP',
                    scheme: scheme,
                    icon: Icons.error_outline_rounded,
                    background: scheme.error,
                    foreground: scheme.onError,
                  ),
                ),
            ],
          ),
          if ((subscription.error ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subscription.error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: refreshing ? null : () => _refresh(subscription),
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Обновить'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () => _delete(subscription),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Удалить'),
              ),
              const Spacer(),
              Text(
                subscription.updatedAt == null
                    ? 'Не обновлялась'
                    : 'Обновлено ${formatRelative(subscription.updatedAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    required ColorScheme scheme,
    IconData? icon,
    Color? background,
    Color? foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13, color: foreground ?? scheme.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground ?? scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
