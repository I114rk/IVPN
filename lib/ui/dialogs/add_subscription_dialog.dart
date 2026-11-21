import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/subscription.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_controller.dart';
import '../../services/subscription_controller.dart';

class AddSubscriptionDialog extends StatefulWidget {
  const AddSubscriptionDialog({super.key});

  static Future<Subscription?> show(BuildContext context) {
    return showDialog<Subscription>(
      context: context,
      builder: (_) => const AddSubscriptionDialog(),
    );
  }

  @override
  State<AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<AddSubscriptionDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = context.tr('Укажите ссылку на подписку'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subscription = await context.read<SubscriptionController>().add(
        name: _name.text,
        url: url,
      );
      if (mounted) Navigator.of(context).pop(subscription);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final emulation = settings.value.emulation;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(context.tr('Добавить подписку')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: context.tr('Название (необязательно)'),
                hintText: context.tr('Моя подписка'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              enabled: !_loading,
              autofocus: true,
              onSubmitted: (_) => _loading ? null : _submit(),
              decoration: InputDecoration(
                labelText: context.tr('Ссылка подписки'),
                hintText: 'https://sub.example.com/api/sub/…',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Отправлять HWID')),
              subtitle: Text(
                context.tr('Remnawave использует HWID для привязки устройства'),
              ),
              value: settings.value.sendHwid,
              onChanged: _loading
                  ? null
                  : (value) => settings.patch(sendHwid: value),
            ),
            if (emulation != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('Эмуляция клиента: {name}', {
                          'name': emulation.name,
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('Отмена')),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded, size: 18),
          label: Text(context.tr('Добавить')),
        ),
      ],
    );
  }
}
