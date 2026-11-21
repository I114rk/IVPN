import 'dart:convert';

String normalizeBase64(String input) {
  var value = input.trim().replaceAll(RegExp(r'\s+'), '');
  value = value.replaceAll('-', '+').replaceAll('_', '/');
  final remainder = value.length % 4;
  if (remainder == 2) {
    value += '==';
  } else if (remainder == 3) {
    value += '=';
  } else if (remainder == 1) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

String? tryBase64DecodeUtf8(String input) {
  try {
    final normalized = normalizeBase64(input);
    if (normalized.isEmpty) return null;
    return utf8.decode(base64Decode(normalized), allowMalformed: true);
  } catch (_) {
    return null;
  }
}

bool looksLikeBase64(String input) {
  final value = input.trim();
  if (value.length < 8) return false;
  return RegExp(r'^[A-Za-z0-9+/=_\-\r\n]+$').hasMatch(value);
}

String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
