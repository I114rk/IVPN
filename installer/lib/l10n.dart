import 'dart:io';

import 'package:ivpn/l10n/app_localizations.dart';

String get installerLanguageCode {
  final raw = Platform.localeName.replaceAll('_', '-').toLowerCase();
  final code = raw.split('-').first;
  return switch (code) {
    'ru' => 'ru',
    'de' => 'de',
    _ => 'en',
  };
}

String tr(String source, [Map<String, Object?> values = const {}]) =>
    AppLocalizations.translate(installerLanguageCode, source, values);
