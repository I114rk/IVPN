import 'package:flutter/material.dart';

class ConnectOrb extends StatefulWidget {
  const ConnectOrb({
    super.key,
    required this.connected,
    required this.busy,
    required this.onPressed,
    this.size = 196,
  });

  final bool connected;
  final bool busy;
  final VoidCallback? onPressed;
  final double size;

  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _ConnectOrbState extends State<ConnectOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ConnectOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected ||
        oldWidget.busy != widget.busy) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.connected || widget.busy) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final active = widget.connected || widget.busy;
    final label = widget.busy
        ? 'ПОДКЛЮЧЕНИЕ'
        : widget.connected
            ? 'ОТКЛЮЧИТЬ'
            : 'ПОДКЛЮЧИТЬ';

    return SizedBox(
      width: widget.size + 72,
      height: widget.size + 72,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Container(
                  width: widget.size + 12 + t * 40,
                  height: widget.size + 12 + t * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary
                        .withValues(alpha: 0.10 * (1 - t) + 0.02),
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.connected
                      ? LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.connected
                      ? null
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: widget.connected
                        ? Colors.transparent
                        : scheme.outlineVariant,
                  ),
                  boxShadow: widget.connected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.busy ? null : widget.onPressed,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.busy
                                ? Icons.sync_rounded
                                : Icons.power_settings_new_rounded,
                            size: widget.size * 0.28,
                            color: widget.connected
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                              color: widget.connected
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
