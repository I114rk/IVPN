import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import '../utils/base64_utils.dart';
import 'subscription_parser.dart';

class SubscriptionFetchResult {
  final ParsedSubscription parsed;
  final SubscriptionUsage? usage;
  final String? title;
  final String? announce;
  final String? supportUrl;
  final String? webPageUrl;
  final int? updateIntervalHours;
  final bool hwidActive;
  final bool hwidLimitReached;
  final bool hwidNotSupported;

  const SubscriptionFetchResult({
    required this.parsed,
    this.usage,
    this.title,
    this.announce,
    this.supportUrl,
    this.webPageUrl,
    this.updateIntervalHours,
    this.hwidActive = false,
    this.hwidLimitReached = false,
    this.hwidNotSupported = false,
  });
}

class SubscriptionRequestException implements Exception {
  final String message;
  final int? statusCode;
  final bool hwidRequired;

  const SubscriptionRequestException(
    this.message, {
    this.statusCode,
    this.hwidRequired = false,
  });

  @override
  String toString() => message;
}

class SubscriptionClient {
  SubscriptionClient([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SubscriptionFetchResult> fetch({
    required String url,
    required String userAgent,
    required String subscriptionId,
    required String subscriptionName,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const SubscriptionRequestException(
        'Некорректная ссылка подписки',
      );
    }

    final request = http.Request('GET', uri)
      ..headers['User-Agent'] = userAgent
      ..headers['Accept'] = '*/*';
    request.headers.addAll(headers);

    http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      throw SubscriptionRequestException(
        'Не удалось подключиться к серверу подписки: $error',
      );
    }

    final body = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      throw _buildError(response.statusCode, response.headers, body);
    }

    ParsedSubscription parsed;
    try {
      parsed = SubscriptionParser.parse(
        body,
        subscriptionId: subscriptionId,
        subscriptionName: subscriptionName,
      );
    } on SubscriptionFormatException catch (error) {
      throw SubscriptionRequestException(error.message);
    } catch (error) {
      throw SubscriptionRequestException('Ошибка разбора подписки: $error');
    }

    if (parsed.profiles.isEmpty) {
      throw const SubscriptionRequestException(
        'Подписка не содержит поддерживаемых серверов',
      );
    }

    final headersMap = response.headers;
    return SubscriptionFetchResult(
      parsed: parsed,
      usage: SubscriptionUsage.parseHeader(_header(headersMap, 'subscription-userinfo')),
      title: _decodeTitle(_header(headersMap, 'profile-title')),
      announce: _decodeTitle(_header(headersMap, 'announce')),
      supportUrl: _header(headersMap, 'support-url'),
      webPageUrl: _header(headersMap, 'profile-web-page-url'),
      updateIntervalHours:
          int.tryParse(_header(headersMap, 'profile-update-interval') ?? ''),
      hwidActive: _header(headersMap, 'x-hwid-active') == 'true',
      hwidLimitReached:
          _header(headersMap, 'x-hwid-max-devices-reached') == 'true' ||
              _header(headersMap, 'x-hwid-limit') == 'true',
      hwidNotSupported:
          _header(headersMap, 'x-hwid-not-supported') == 'true',
    );
  }

  SubscriptionRequestException _buildError(
    int statusCode,
    Map<String, String> headers,
    String body,
  ) {
    final hwidNotSupported = _header(headers, 'x-hwid-not-supported') == 'true';
    final hwidLimit = _header(headers, 'x-hwid-max-devices-reached') == 'true' ||
        _header(headers, 'x-hwid-limit') == 'true';

    if (hwidLimit) {
      return SubscriptionRequestException(
        'Достигнут лимит устройств для этой подписки (HWID).',
        statusCode: statusCode,
      );
    }
    if (hwidNotSupported) {
      return SubscriptionRequestException(
        'Панель требует HWID, но запрос отправлен без него. Включите HWID в настройках.',
        statusCode: statusCode,
        hwidRequired: true,
      );
    }
    return switch (statusCode) {
      403 => SubscriptionRequestException(
          'Доступ запрещён (403). Проверьте ссылку подписки.',
          statusCode: statusCode,
        ),
      404 => SubscriptionRequestException(
          'Подписка не найдена (404). Проверьте ссылку или HWID.',
          statusCode: statusCode,
        ),
      451 => SubscriptionRequestException(
          'Доступ ограничен по требованию правообладателя (451).',
          statusCode: statusCode,
        ),
      _ => SubscriptionRequestException(
          'Сервер вернул ошибку HTTP $statusCode',
          statusCode: statusCode,
        ),
    };
  }

  static String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  static String? _decodeTitle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    var text = value.trim();
    if (text.toLowerCase().startsWith('base64:')) {
      text = text.substring(7);
      final decoded = tryBase64DecodeUtf8(text);
      if (decoded != null) text = decoded;
    }
    try {
      return Uri.decodeComponent(text);
    } catch (_) {
      return text;
    }
  }

  void dispose() => _client.close();
}
