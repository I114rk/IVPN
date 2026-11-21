import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/client_emulation.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_controller.dart';

class EmulateClientDialog extends StatelessWidget {
  const EmulateClientDialog({super.key});

  /// Returns:
  ///  - null when the dialog was cancelled,
  ///  - an empty string to disable emulation,
  ///  - otherwise the emulated client id.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const EmulateClientDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = context.watch<SettingsController>().value.emulatedClientId;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(context.tr('Эмуляция клиента'))),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: 560,
        height: 540,
        child: ListView(
          children: [
            Text(
              context.tr(
                'IVPN будет отправлять User-Agent и заголовки устройства выбранного клиента. '
                'Это влияет на формат, который отдаёт панель Remnawave.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _ClientTile(
              name: context.tr('Не эмулировать'),
              description: context.tr('Стандартный User-Agent IVPN'),
              selected: current == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            const Divider(height: 24),
            for (final client in ClientEmulation.catalog)
              _ClientTile(
                name: client.name,
                description: client.description,
                userAgent: client.userAgent,
                core: client.core,
                selected: current == client.id,
                onTap: () => Navigator.of(context).pop(client.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Закрыть')),
        ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
    this.userAgent,
    this.core,
  });

  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? userAgent;
  final String? core;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: selected
                        ? scheme.onPrimary
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
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : null,
                              ),
                            ),
                          ),
                          if (core != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                core!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer.withValues(
                                  alpha: 0.75,
                                )
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (userAgent != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          userAgent!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 10.5,
                            color: selected
                                ? scheme.onSecondaryContainer.withValues(
                                    alpha: 0.65,
                                  )
                                : scheme.onSurfaceVariant.withValues(
                                    alpha: 0.75,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
