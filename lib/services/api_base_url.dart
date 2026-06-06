import 'package:flutter/foundation.dart';

const String _defaultApiBaseUrl = 'https://emergencias-backend.onrender.com/api/v1';

String resolveApiBaseUrl() {
  const raw = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl);

  if (kIsWeb && raw.contains('10.0.2.2')) {
    return raw.replaceFirst('10.0.2.2', 'localhost');
  }

  return raw;
}

