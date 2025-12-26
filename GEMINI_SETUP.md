# Gemini API Configuration

To enable AI-powered chatbot and sentiment analysis:

1. Get your Gemini API key from: https://makersuite.google.com/app/apikey

2. Update the API key in `lib/services/gemini_service.dart`:
   ```dart
   GeminiService({String? apiKey})
       : _apiKey = apiKey ?? 'YOUR_GEMINI_API_KEY_HERE';
   ```

3. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key.

## Features Using Gemini AI:

- **AI Chatbot**: Natural language conversations with mental wellness support
- **Sentiment Analysis**: Automatic detection of emotional states in:
  - Chatbot conversations
  - Mood tracker notes
  - Community forum posts
  - Journal entries
- **Risk Detection**: Flags high-risk conversations to counsellors
- **Smart Responses**: Context-aware mental health support

## Important Notes:

- Keep your API key secure and never commit it to public repositories
- Consider using environment variables for production deployments
- The free tier has rate limits; monitor usage for production apps
- Sentiment analysis helps identify students who may need counsellor support
