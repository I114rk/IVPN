import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import '../../core/app_version.dart';
import '../../services/settings_controller.dart';
import '../../l10n/app_localizations.dart';

class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;
  late final Future<String> _version;

  @override
  void initState() {
    super.initState();
    _version = AppVersion.value;
    windowManager.addListener(this);
    unawaited(
      windowManager.isMaximized().then((value) {
        if (mounted) setState(() => _maximized = value);
      }),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final emulation = context.watch<SettingsController>().value.emulation;

    return Container(
      height: 50,
      color: scheme.surface,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.shield_rounded,
              size: 18,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'IVPN',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FutureBuilder<String>(
              future: _version,
              builder: (context, snapshot) => Text(
                'v${snapshot.data ?? '…'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
          if (emulation != null) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: 'User-Agent: ${emulation.userAgent}',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      size: 14,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('Эмуляция: {name}', {'name': emulation.name}),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _toggleMaximize,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _WindowButton(
            icon: Icons.remove_rounded,
            onPressed: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: _maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onPressed: _toggleMaximize,
          ),
          _WindowButton(
            icon: Icons.close_rounded,
            onPressed: () => windowManager.close(),
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _hovered
        ? (widget.isClose ? scheme.error : scheme.surfaceContainerHighest)
        : Colors.transparent;
    final foreground = _hovered && widget.isClose
        ? scheme.onError
        : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 50,
          color: background,
          child: Icon(widget.icon, size: 17, color: foreground),
        ),
      ),
    );
  }
}
