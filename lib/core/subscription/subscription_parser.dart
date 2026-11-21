import 'dart:convert';

import '../models/proxy_profile.dart';
import '../utils/base64_utils.dart';
import 'mihomo_parser.dart';
import 'share_link_parser.dart';
import 'singbox_parser.dart';
import 'xray_parser.dart';

class ParsedSubscription {
  final List<ProxyProfile> profiles;
  final String format;
  final Map<String, dynamic>? rawSingbox;
  final dynamic rawXray;

  const ParsedSubscription({
    required this.profiles,
    required this.format,
    this.rawSingbox,
    this.rawXray,
  });
}

class SubscriptionFormatException implements Exception {
  final String message;
  const SubscriptionFormatException(this.message);

  @override
  String toString() => message;
}

class SubscriptionParser {
  static ParsedSubscription parse(
    String body, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const SubscriptionFormatException('Пустой ответ от сервера');
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          if (map['outbounds'] is List) {
            return ParsedSubscription(
              format: 'sing-box',
              profiles: SingboxParser.parseConfig(
                map,
                subscriptionId: subscriptionId,
                subscriptionName: subscriptionName,
              ),
              rawSingbox: map,
            );
          }
        } else if (decoded is List) {
          return ParsedSubscription(
            format: 'xray',
            profiles: XrayParser.parse(
              decoded,
              subscriptionId: subscriptionId,
              subscriptionName: subscriptionName,
            ),
            rawXray: decoded,
          );
        }
      } on FormatException {
        // fall through to other formats
      }
    }

    if (RegExp(r'^\s*proxies\s*:', multiLine: true).hasMatch(trimmed)) {
      return ParsedSubscription(
        format: 'mihomo',
        profiles: MihomoParser.parse(
          trimmed,
          subscriptionId: subscriptionId,
          subscriptionName: subscriptionName,
        ),
      );
    }

    if (!trimmed.contains('://')) {
      final decoded = tryBase64DecodeUtf8(trimmed);
      if (decoded != null && decoded.contains('://')) {
        return ParsedSubscription(
          format: 'base64',
          profiles: ShareLinkParser.parseLines(
            decoded,
            subscriptionId: subscriptionId,
            subscriptionName: subscriptionName,
          ),
        );
      }
    }

    if (trimmed.contains('://')) {
      return ParsedSubscription(
        format: 'links',
        profiles: ShareLinkParser.parseLines(
          trimmed,
          subscriptionId: subscriptionId,
          subscriptionName: subscriptionName,
        ),
      );
    }

    throw const SubscriptionFormatException(
      'Не удалось распознать формат подписки',
    );
  }
}
