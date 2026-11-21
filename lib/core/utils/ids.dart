import 'dart:convert';

import 'package:crypto/crypto.dart';

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

String shortHash(String input, [int length = 20]) {
  final digest = sha256Hex(input);
  return length >= digest.length ? digest : digest.substring(0, length);
}

String randomId([int bytes = 8]) {
  final now = DateTime.now().microsecondsSinceEpoch.toString();
  return shortHash('$now-${identityHashCode(now)}', bytes * 2);
}
