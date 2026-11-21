import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Derives a stable HWID that satisfies Remnawave's validation regex
/// `/^[a-zA-Z0-9=-]{10,64}$/` (32 hex characters here).
String deriveHwid(List<String> components) {
  final normalized = components
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join('|');
  final digest = sha256.convert(utf8.encode(normalized)).bytes;
  final hex = digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return hex.substring(0, 32);
}
