import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/gemini_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

final geminiServiceProvider = Provider((ref) => GeminiService());
final firestoreProvider = Provider((ref) => FirestoreService());

class ChatbotPage extends ConsumerStatefulWidget {
  const ChatbotPage({super.key});

  @override
  ConsumerState<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends ConsumerState<ChatbotPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final firestore = ref.read(firestoreProvider);
      final history = await firestore.chatHistory(user.uid).first;

      setState(() {
        _messages = history.isEmpty
            ? [
                {
                  'sender': 'bot',
                  'text':
                      'Hi! I\'m PutraBot, your mental wellness AI assistant powered by Gemini. How are you feeling today?',
                  'timestamp': DateTime.now(),
                }
              ]
            : history;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final userMessage = {
      'sender': 'you',
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      // Save user message to Firestore
      await ref.read(firestoreProvider).saveChatMessage(
            userId: user.uid,
            sender: 'you',
            text: text,
          );

      // Get response from Gemini
      final gemini = ref.read(geminiServiceProvider);
      final response = await gemini.sendMessage(text);

      // Analyze sentiment
      final sentiment = await gemini.analyzeSentiment(text);
      final riskLevel = sentiment['riskLevel'] as String;

      final botMessage = {
        'sender': 'bot',
        'text': response,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sentiment': sentiment,
      };

      // Save bot response to Firestore
      await ref.read(firestoreProvider).saveChatMessage(
            userId: user.uid,
            sender: 'bot',
            text: response,
            sentiment: sentiment,
          );

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      // Flag high-risk conversations and notify counsellors
      if (riskLevel == 'high' || riskLevel == 'critical') {
        final profile = ref.read(userProfileProvider).value;
        if (profile != null) {
          await ref.read(firestoreProvider).flagHighRiskStudent(
                studentId: user.uid,
                studentName: profile.displayName,
                riskLevel: riskLevel,
                sentiment: sentiment['sentiment'] as String? ?? 'concerning',
                message: text,
              );
        }
        _showRiskAlert(context, riskLevel);
      }

      _scrollToBottom();
    } catch (e) {
      final errorMessage = {
        'sender': 'bot',
        'text':
            'I\'m having trouble connecting. Please try again or contact a counsellor directly.',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      setState(() {
        _messages.add(errorMessage);
        _isTyping = false;
      });

      // Save error message to Firestore
      await ref.read(firestoreProvider).saveChatMessage(
            userId: user.uid,
            sender: 'bot',
            text: errorMessage['text'] as String,
          );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showRiskAlert(BuildContext context, String level) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Available'),
        content: Text(
          level == 'critical'
              ? 'I notice you might be going through a difficult time. A counsellor has been notified and will reach out soon. If you need immediate help, please contact emergency services.'
              : 'I\'m flagging this conversation for a counsellor to review. They may reach out to offer additional support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'PutraBot',
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.psychology,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PutraBot powered by Gemini • Your chat history is saved securely',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isBot = msg['sender'] == 'bot';
                  final sentiment = msg['sentiment'] as Map<String, dynamic>?;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: isBot
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: isBot
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isBot
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                color: isBot ? null : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (sentiment != null &&
                            sentiment['riskLevel'] != 'low')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ ${sentiment['riskLevel']} risk detected',
                              style: TextStyle(
                                fontSize: 11,
                                color: sentiment['riskLevel'] == 'critical'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('AI is thinking...',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isTyping,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isTyping ? null : _send,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
