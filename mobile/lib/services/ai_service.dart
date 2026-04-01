import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:kitakitar_mobile/config/ai_config.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

class AIService {
  static const _prompt = '''
Analyze this photo of waste/recycling materials.

Return a valid JSON object with this exact structure (no markdown, no code blocks):
{
  "detectedMaterials": [
    {
      "type": "plastic",
      "estimatedWeight": 1.5
    }
  ],
  "preparationTip": "Brief advice in English for preparing this waste for drop-off at a recycling point."
}

Rules:
- type: use one of: plastic, paper, glass, metal, aluminum, batteries, electronics, food, cardboard, tires, used_oil, hazardous, other
- estimatedWeight: approximate weight in kg (0.1 to 100)
- If multiple waste types, add each to detectedMaterials with its own weight
- preparationTip: one short sentence in English, e.g. "Pour out liquids, keep caps on bottles.", "Rinse and flatten containers.", "Remove batteries if present." Adapt to what you see (bottles, cans, paper, etc.). If nothing specific, use a general tip like "Keep items dry and separate by type."
- If nothing recognizable, return {"detectedMaterials": [], "preparationTip": "Sort by material type before drop-off."}
''';

  GenerativeModel? _model;

  GenerativeModel get _generativeModel {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
      ),
    );
    return _model!;
  }

  /// Detects waste materials in photo. Returns materials + optional preparation tip.
  Future<ScanResult> detectMaterials(String imagePath) async {
    if (useMockResponse) {
      debugPrint('[AIService] useMockResponse=true — returning mock (plastic 0.05, paper 0.02)');
      return _getMockResponse();
    }
    if (geminiApiKey.isEmpty) {
      debugPrint('[AIService] No GEMINI_API_KEY — using mock.');
      return _getMockResponse();
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await _generativeModel.generateContent([
        Content.multi([TextPart(_prompt), imagePart]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('[AIService] Gemini returned empty response');
        return ScanResult(materials: []);
      }

      final result = _parseResponse(text);
      debugPrint('[AIService] AI response (raw JSON): $text');
      debugPrint('[AIService] Parsed: ${jsonEncode(result.toMap())}');
      return result;
    } catch (e, stack) {
      debugPrint('[AIService] Gemini API error, using mock: $e');
      debugPrint('[AIService] Stack: $stack');
      return _getMockResponse();
    }
  }

  ScanResult _parseResponse(String text) {
    try {
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'\s*```'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final list = json['detectedMaterials'] as List?;
      final materials = (list ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => DetectedMaterial(
                type: (m['type'] ?? 'other').toString().toLowerCase(),
                estimatedWeight: (m['estimatedWeight'] ?? 0).toDouble(),
              ))
          .where((m) => m.type.isNotEmpty && m.estimatedWeight > 0)
          .toList();
      final tip = json['preparationTip'] as String?;
      return ScanResult(materials: materials, preparationTip: tip?.trim().isNotEmpty == true ? tip : null);
    } catch (_) {
      return ScanResult(materials: []);
    }
  }

  ScanResult _getMockResponse() {
    return ScanResult(
      materials: [
        DetectedMaterial(type: 'plastic', estimatedWeight: 0.05),
        DetectedMaterial(type: 'paper', estimatedWeight: 0.02),
      ],
      preparationTip: 'Rinse containers if needed; keep caps on bottles for recycling.',
    );
  }
}
