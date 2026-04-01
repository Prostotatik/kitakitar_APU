import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:kitakitar_mobile/config/ai_config.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatService {
  ChatSession? _chat;
  final List<ChatMessage> messages = [];
  late String _systemPrefix;

  void startSession(List<DetectedMaterial> materials, String? preparationTip) {
    final materialsDesc = materials
        .map((m) => '${m.type} (~${m.estimatedWeight.toStringAsFixed(2)} kg)')
        .join(', ');

    _systemPrefix = '''
[SYSTEM]
You are a friendly recycling assistant inside the KitaKitar app.
The app allows users to scan their trash to find out its material, weight, and AI advice, then they can click the "Show on Map" button to find suitable recycling centers.
After submitting trash, recycling center's manager will give user a QR code to scan to receive points that can be redeemed for rewards.

SCAN CONTEXT — the user scanned waste and the AI detected: $materialsDesc.
${preparationTip != null ? 'AI preparation tip: $preparationTip' : ''}

RULES:
- Only answer questions about recycling, waste preparation, sorting, recycling centers, and the environment.
- Naturally weave in why recycling matters — but keep it subtle and warm, not preachy.
- Be concise: 2-4 sentences unless the user asks for more detail.
- If the question is NOT about recycling/waste/environment, reply ONLY: "I'm here to help with recycling questions! Ask me anything about preparing your waste or how recycling works."
- If the question is about something you don't have in SYSTEM promt, reply ONLY: "Sorry! I'm not sure about question! Ask me anything else."
- Reply in the same language the user writes in.
[/SYSTEM]

User message: ''';

    final model = GenerativeModel(
      model: 'gemma-3-27b-it',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 512,
      ),
    );

    _chat = model.startChat();
    messages.clear();
  }

  Future<String> sendMessage(String userMessage) async {
    if (_chat == null) {
      return 'Chat session not started.';
    }

    messages.add(ChatMessage(text: userMessage, isUser: true));

    try {
      final fullMessage = '$_systemPrefix$userMessage';
      final response = await _chat!.sendMessage(Content.text(fullMessage));
      final reply = (response.text ?? 'Sorry, I couldn\'t generate a response.').trim();
      messages.add(ChatMessage(text: reply, isUser: false));
      return reply;
    } catch (e) {
      debugPrint('[ChatService] Error: $e');
      const fallback = 'Something went wrong. Please try again.';
      messages.add(ChatMessage(text: fallback, isUser: false));
      return fallback;
    }
  }
}
