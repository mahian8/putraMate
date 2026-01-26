import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class GeminiService {
  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? 'AIzaSyA4rMKMrKRlQuM_-Bztklth6d9FDNt1hYY';

  final String _apiKey;
  GenerativeModel? _model;

  static const String _systemContext = '''
You are PutraBot, a compassionate and professional mental wellness AI assistant for PutraMate, a university counselling platform. Your role is to:

1. Provide empathetic, supportive responses to students discussing mental health, stress, anxiety, depression, or academic challenges
2. NEVER provide medical advice or diagnoses - always recommend professional counsellors for serious concerns
3. Detect when students need professional help and suggest booking a counsellor
4. Be culturally sensitive and use inclusive, non-judgmental language
5. Keep responses concise (2-4 sentences) unless detailed guidance is requested
6. Use active listening techniques: acknowledge feelings, ask clarifying questions, validate emotions
7. Provide practical coping strategies when appropriate (breathing exercises, time management, study tips)
8. Recognize crisis situations (suicidal thoughts, self-harm, severe distress) and IMMEDIATELY recommend professional help

PutraMate Services Available:
- Professional counsellors specializing in academic stress, relationships, mental health
- Easy online booking system for one-on-one sessions
- Peer community support forum

Important Guidelines:
- If a student mentions suicidal thoughts, self-harm, or crisis: respond with "I'm very concerned about what you've shared. Please speak with a counsellor immediately or contact emergency services. Would you like me to help you book an urgent counselling session?"
- If discussing ongoing mental health issues (depression, anxiety lasting weeks): "It sounds like you could benefit from talking to one of our professional counsellors. Would you like to book a session?"
- For academic stress, exam anxiety, relationship issues: offer brief coping strategies THEN suggest booking if needed
- Always be warm, hopeful, and encouraging
''';

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash-002',
      apiKey: _apiKey,
      systemInstruction: Content.text(_systemContext),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 512,
      ),
    );
    return _model!;
  }

  Future<String> sendMessage(String message,
      {List<Map<String, dynamic>>? conversationHistory,
      String? moodContext}) async {
    try {
      final List<Content> contents = [];

      // Add mood context if available
      if (moodContext != null && moodContext.isNotEmpty) {
        contents.add(
            Content('user', [TextPart('MOOD HISTORY CONTEXT: $moodContext')]));
        contents.add(Content('model', [
          TextPart(
              'I understand. I have reviewed the student\'s recent mood patterns and will consider this in my response.')
        ]));
      }

      // Add conversation history (last 8 messages for context)
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final recentMessages =
            conversationHistory.reversed.take(8).toList().reversed;
        for (final msg in recentMessages) {
          final isUser = msg['isUser'] as bool? ?? true;
          final text = msg['text'] as String? ?? '';
          contents.add(Content(isUser ? 'user' : 'model', [TextPart(text)]));
        }
      }

      // Add current message
      contents.add(Content.text(message));

      final response = await model.generateContent(contents);
      return response.text ?? 'I apologize, I could not generate a response.';
    } catch (e) {
      // Log the underlying failure to help diagnose key/config/connectivity issues.
      // This is safe to surface in logs but the returned string stays generic for users.
      // ignore: avoid_print
      print('Gemini sendMessage error: $e');
      return 'Error: Unable to connect to AI service. Please check your network or API key and try again.';
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
            'keywords':
                (parsed['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
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

  /// Detects if user message indicates they want to book a counsellor
  Future<Map<String, dynamic>> detectBookingIntent(String message) async {
    try {
      final prompt = '''
Analyze this message and determine if the user wants to book/schedule a counselling session.

User message: "$message"

Respond with ONLY a JSON object (no markdown formatting):
{
  "hasBookingIntent": true/false,
  "confidence": "high"/"medium"/"low",
  "urgency": "urgent"/"normal"/"none",
  "reason": "brief explanation"
}

Intent indicators:
- Direct requests: "book", "schedule", "appointment", "session", "meet with counsellor"
- Indirect: "I need help", "talk to someone", "see a counsellor", "get professional help"
- Crisis keywords: "can't cope", "want to die", "hurt myself" = URGENT
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text?.trim() ?? '{}';

      // Remove markdown code blocks if present
      final cleanJson =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      // Parse JSON from response
      final jsonStart = cleanJson.indexOf('{');
      final jsonEnd = cleanJson.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = cleanJson.substring(jsonStart, jsonEnd);
        return json.decode(jsonStr) as Map<String, dynamic>;
      }

      return {
        'hasBookingIntent': false,
        'confidence': 'low',
        'urgency': 'none',
        'reason': 'Unable to parse response',
      };
    } catch (e) {
      return {
        'hasBookingIntent': false,
        'confidence': 'low',
        'urgency': 'none',
        'reason': 'Error analyzing intent: $e',
      };
    }
  }

  /// Extract problem keywords from student message for counselor matching
  Future<List<String>> extractProblemKeywords(String message) async {
    try {
      final prompt = '''
Extract key mental health and counseling topics from this student message.

Student message: "$message"

Respond with ONLY a JSON array of relevant keywords (no markdown):
["keyword1", "keyword2", "keyword3"]

Relevant topics to identify:
- Mental health: anxiety, depression, stress, trauma, PTSD, grief, self-esteem
- Academic: exam stress, performance anxiety, study skills, time management, procrastination
- Social: relationships, family issues, peer pressure, loneliness, social anxiety
- Behavioral: addiction, eating disorders, sleep problems, anger management
- Life transitions: adjustment, career counseling, identity issues

Focus on broad categorization (e.g., "anxiety" not "test anxiety").
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text?.trim() ?? '[]';

      // Remove markdown code blocks if present
      final cleanJson =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      // Parse JSON array
      final arrayStart = cleanJson.indexOf('[');
      final arrayEnd = cleanJson.lastIndexOf(']') + 1;
      if (arrayStart >= 0 && arrayEnd > arrayStart) {
        final jsonStr = cleanJson.substring(arrayStart, arrayEnd);
        final parsed = json.decode(jsonStr) as List<dynamic>;
        return parsed.map((e) => e.toString()).toList();
      }

      return [];
    } catch (e) {
      // ignore: avoid_print
      print('Gemini extractProblemKeywords error: $e');
      return [];
    }
  }

  /// Analyze mood entries to detect struggling patterns
  Map<String, dynamic> analyzeMoodPattern(
      List<Map<String, dynamic>> moodEntries) {
    if (moodEntries.isEmpty) {
      return {
        'isStruggling': false,
        'severity': 'none',
        'summary': '',
      };
    }

    // Calculate average mood score
    final scores = moodEntries.map((m) => m['moodScore'] as int? ?? 5).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;

    // Count low mood entries (score <= 3)
    final lowMoodCount = scores.where((s) => s <= 3).length;
    final lowMoodRatio = lowMoodCount / scores.length;

    // Detect declining trend (compare first half vs second half)
    final halfPoint = scores.length ~/ 2;
    final recentAvg =
        scores.take(halfPoint).reduce((a, b) => a + b) / halfPoint;
    final olderAvg = scores.skip(halfPoint).reduce((a, b) => a + b) /
        (scores.length - halfPoint);
    final isDecreasing = recentAvg < olderAvg - 1;

    // Determine severity
    String severity;
    bool isStruggling;
    if (avgScore <= 3 || lowMoodRatio >= 0.6) {
      severity = 'critical';
      isStruggling = true;
    } else if (avgScore <= 4 || lowMoodRatio >= 0.4 || isDecreasing) {
      severity = 'concerning';
      isStruggling = true;
    } else if (avgScore <= 5) {
      severity = 'watchful';
      isStruggling = true;
    } else {
      severity = 'stable';
      isStruggling = false;
    }

    // Build summary
    final summary = isStruggling
        ? 'Student has tracked ${moodEntries.length} mood entries in the past 7 days. '
            'Average mood: ${avgScore.toStringAsFixed(1)}/10. '
            '${lowMoodCount} low mood entries detected.'
            '${isDecreasing ? ' Mood appears to be declining.' : ''}'
        : 'Recent mood tracking shows relatively stable patterns.';

    return {
      'isStruggling': isStruggling,
      'severity': severity,
      'avgScore': avgScore,
      'lowMoodCount': lowMoodCount,
      'summary': summary,
    };
  }

  /// Generate counselor booking suggestion with available time slots
  Future<Map<String, dynamic>> generateBookingSuggestion({
    required String counselorName,
    required String counselorExpertise,
    required List<DateTime> availableSlots,
  }) async {
    try {
      final timeSlotsText = availableSlots
          .take(5)
          .map((dt) =>
              '${dt.day}/${dt.month} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}')
          .join(', ');

      final prompt = '''
Generate a brief, encouraging booking suggestion message for a student to book with a counselor.

Counselor: $counselorName (Expertise: $counselorExpertise)
Available times: $timeSlotsText

Create a friendly 1-2 sentence message that:
1. Shows the counselor's expertise relevant to their issue
2. Suggests they book one of the available times
3. Is encouraging and positive

Keep it conversational and warm.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final message = response.text ?? 'Would you like to book a session?';

      return {
        'success': true,
        'message': message,
        'availableSlots': availableSlots.take(5).toList(),
        'firstAvailable':
            availableSlots.isNotEmpty ? availableSlots.first : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'I\'d like to help you book a session. Would you like to proceed?',
        'error': '$e',
      };
    }
  }
}
