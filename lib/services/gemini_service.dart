import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:convert';

class GeminiService {
  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? 'AIzaSyCmdqajiOQMf_3uuUYAaLo6VJqpysISblQ';

  final String _apiKey;
  GenerativeModel? _model;

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
    return _model!;
  }

  Future<String> sendMessage(String message) async {
    try {
      final content = [Content.text(message)];
      final response = await model.generateContent(content);
      return response.text ?? 'I apologize, I could not generate a response.';
    } catch (e) {
      return 'Error: Unable to connect to AI service. Please try again.';
    }
  }

  Future<Map<String, dynamic>> analyzeSentiment(String textInput) async {
    try {
      final prompt = '''
Analyze the sentiment of the following text and provide a mental health risk assessment.
Respond ONLY with a JSON object in this exact format:
{
  "sentiment": "positive/neutral/negative/concerning",
  "riskLevel": "low/medium/high/critical",
  "score": 0-10,
  "keywords": ["keyword1", "keyword2"],
  "recommendation": "brief recommendation"
}

Text to analyze: "$textInput"
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text ?? '{}';
      
      // Parse JSON from response
      final jsonStart = responseText.indexOf('{');
      final jsonEnd = responseText.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        try {
          final jsonStr = responseText.substring(jsonStart, jsonEnd);
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          return {
            'sentiment': parsed['sentiment'] ?? 'neutral',
            'riskLevel': parsed['riskLevel'] ?? 'low',
            'score': parsed['score'] ?? 5,
            'keywords': (parsed['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
            'recommendation': parsed['recommendation'] ?? 'Continue monitoring',
          };
        } catch (e) {
          // Fallback if JSON parsing fails
          return {
            'sentiment': 'neutral',
            'riskLevel': 'low',
            'score': 5,
            'keywords': <String>[],
            'recommendation': 'Continue monitoring',
          };
        }
      }
      
      return {
        'sentiment': 'neutral',
        'riskLevel': 'low',
        'score': 5,
        'keywords': <String>[],
        'recommendation': 'Unable to analyze',
      };
    } catch (e) {
      return {
        'sentiment': 'neutral',
        'riskLevel': 'low',
        'score': 5,
        'keywords': <String>[],
        'recommendation': 'Analysis unavailable',
      };
    }
  }
}
