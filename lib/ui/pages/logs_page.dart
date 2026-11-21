import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/log_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../services/log_service.dart';
import '../../services/storage_service.dart';
import '../utils/ui_helpers.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late final LogService _logs = context.read<LogService>();
  final List<LogEntry> _entries = [];
  final Set<LogLevel> _levels = LogLevel.values.toSet();
  StreamSubscription<LogEntry>? _subscription;

  @override
  void initState() {
    super.initState();
    _entries.addAll(_logs.entries);
    _subscription = _logs.stream.listen((entry) {
      if (mounted) setState(() => _entries.add(entry));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final storage = context.read<StorageService>();
    final filtered = _entries
        .where((entry) => _levels.contains(entry.level))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: PageHeader(
            title: context.tr('Логи'),
            subtitle: context.tr('{count} записей', {'count': filtered.length}),
            actions: [
              IconButton(
                tooltip: context.tr('Открыть папку логов'),
                onPressed: () {
                  try {
                    Process.run('explorer', [storage.logsDir.path]);
                  } catch (_) {}
                },
                icon: const Icon(Icons.folder_open_rounded),
              ),
              IconButton(
                tooltip: context.tr('Очистить'),
                onPressed: () {
                  _logs.clear();
                  setState(_entries.clear);
                },
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Wrap(
            spacing: 8,
            children: [
              for (final level in LogLevel.values)
                FilterChip(
                  label: Text(level.label),
                  selected: _levels.contains(level),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _levels.add(level);
                      } else {
                        _levels.remove(level);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(28, 0, 20, 24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.tr('Логи пусты'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[filtered.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _colorFor(entry.level, scheme),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.formatted,
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: _colorFor(entry.level, scheme),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Color _colorFor(LogLevel level, ColorScheme scheme) => switch (level) {
    LogLevel.debug => scheme.onSurfaceVariant.withValues(alpha: 0.7),
    LogLevel.info => scheme.onSurface,
    LogLevel.warn => scheme.tertiary,
    LogLevel.error => scheme.error,
  };
}
