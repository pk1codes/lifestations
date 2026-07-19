import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TextSafetyResult {
  const TextSafetyResult({required this.safe, this.reason});
  final bool safe;
  final String? reason;
}

class TextSafetyScanner {
  const TextSafetyScanner();
  static const _blocked = <String>{'escort', 'nude', 'weapon'};

  TextSafetyResult scan(String value) {
    final normalized = value.toLowerCase();
    for (final term in _blocked) {
      if (RegExp('\\b${RegExp.escape(term)}\\b').hasMatch(normalized)) {
        return TextSafetyResult(
          safe: false,
          reason: 'Contains disallowed content',
        );
      }
    }
    return const TextSafetyResult(safe: true);
  }
}

class SafeSearchResult {
  const SafeSearchResult({
    required this.safe,
    this.adult = 'UNKNOWN',
    this.violence = 'UNKNOWN',
  });
  final bool safe;
  final String adult;
  final String violence;
}

abstract interface class SafeSearchClient {
  Future<SafeSearchResult> inspect(Uint8List imageBytes);
}

class GoogleVisionSafeSearchClient implements SafeSearchClient {
  GoogleVisionSafeSearchClient({http.Client? client})
    : _client = client ?? http.Client();

  static const _key = String.fromEnvironment('VISION_API_KEY');
  static const _enableDev = bool.fromEnvironment('ENABLE_VISION_DEV');
  final http.Client _client;

  bool get enabled => _key.isNotEmpty && (kReleaseMode || _enableDev);

  @override
  Future<SafeSearchResult> inspect(Uint8List imageBytes) async {
    if (!enabled) return const SafeSearchResult(safe: true);
    final response = await _client.post(
      Uri.https('vision.googleapis.com', '/v1/images:annotate', {'key': _key}),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Encode(imageBytes)},
            'features': [
              {'type': 'SAFE_SEARCH_DETECTION', 'maxResults': 1},
            ],
          },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('SafeSearch unavailable (${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final responses = payload['responses'] as List<dynamic>? ?? const [];
    final annotation = responses.isEmpty
        ? const <String, dynamic>{}
        : (responses.first as Map<String, dynamic>)['safeSearchAnnotation']
                  as Map<String, dynamic>? ??
              const {};
    final adult = annotation['adult'] as String? ?? 'UNKNOWN';
    final violence = annotation['violence'] as String? ?? 'UNKNOWN';
    const unsafe = {'LIKELY', 'VERY_LIKELY'};
    return SafeSearchResult(
      safe: !unsafe.contains(adult) && !unsafe.contains(violence),
      adult: adult,
      violence: violence,
    );
  }
}
