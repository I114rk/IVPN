import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/app_settings.dart';
import 'services/settings_controller.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';

class IvpnApp extends StatelessWidget {
  const IvpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final seed = settings.effectiveSeedColor;

    return MaterialApp(
      title: 'IVPN',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(seedColor: seed, brightness: Brightness.light),
      darkTheme: buildAppTheme(seedColor: seed, brightness: Brightness.dark),
      themeMode: switch (settings.value.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      home: const AppShell(),
    );
  }
}
