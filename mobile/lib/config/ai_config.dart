import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini API key for waste recognition (KitaKitar project).
///
/// Источники (приоритет по порядку):
/// 1. `.env` → `GEMINI_API_KEY` (runtime)
/// 2. `--dart-define=GEMINI_API_KEY=...` (compile-time)
final String geminiApiKey = (() {
  final envValue = dotenv.maybeGet('GEMINI_API_KEY');
  if (envValue != null && envValue.isNotEmpty) {
    return envValue;
  }
  return const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
})();

/// Set to true to always use mock response (plastic 0.05, paper 0.02 + tip). No API call.
const bool useMockResponse = false;
