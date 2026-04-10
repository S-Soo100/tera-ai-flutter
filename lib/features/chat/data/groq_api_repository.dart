import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final groqApiRepositoryProvider = Provider<GroqApiRepository>((ref) {
  return GroqApiRepository();
});

class GroqApiRepository {
  static const _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  Future<GroqResponse> sendChat({
    required List<Map<String, String>> messages,
    int maxTokens = 1024,
    double temperature = 0.3,
  }) async {
    if (_apiKey.isEmpty) {
      return const GroqResponse(
        content: '',
        promptTokens: 0,
        completionTokens: 0,
        success: false,
        error: 'GROQ_API_KEY not set',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        return const GroqResponse(
          content: '',
          promptTokens: 0,
          completionTokens: 0,
          success: false,
          error: 'rate_limit',
        );
      }

      if (response.statusCode != 200) {
        return GroqResponse(
          content: '',
          promptTokens: 0,
          completionTokens: 0,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      final content =
          (choices[0] as Map<String, dynamic>)['message']['content'] as String;
      final usage = json['usage'] as Map<String, dynamic>;

      return GroqResponse(
        content: content,
        promptTokens: usage['prompt_tokens'] as int,
        completionTokens: usage['completion_tokens'] as int,
        success: true,
      );
    } on http.ClientException catch (e) {
      return GroqResponse(
        content: '',
        promptTokens: 0,
        completionTokens: 0,
        success: false,
        error: 'network_error: ${e.message}',
      );
    } catch (e) {
      return GroqResponse(
        content: '',
        promptTokens: 0,
        completionTokens: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
}

class GroqResponse {
  final String content;
  final int promptTokens;
  final int completionTokens;
  final bool success;
  final String? error;

  const GroqResponse({
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.success,
    this.error,
  });
}
