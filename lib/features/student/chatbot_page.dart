import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/gemini_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_providers.dart';
import '../../models/user_profile.dart';
import '../common/common_widgets.dart';
import 'counsellor_detail_page.dart';

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
  List<Map<String, dynamic>> _messages = [];
  String? _currentConversationId;
  bool _isTyping = false;
  bool _isLoading = true;
  bool _autoBookConsent = false;
  bool _showSidebar = false;

  bool _userRequestedBooking(String text) {
    final lower = text.toLowerCase();
    return lower.contains('book for me') ||
        lower.contains('book one for me') ||
        lower.contains('schedule for me') ||
        lower.contains('can you book') ||
        lower.contains('please book') ||
        lower.contains('make an appointment') ||
        lower.contains('set an appointment');
  }

  @override
  void initState() {
    super.initState();
    _startNewConversation();
  }

  Future<void> _startNewConversation() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _messages = [];
    });

    try {
      final firestore = ref.read(firestoreProvider);
      final conversationId = await firestore.createChatConversation(user.uid);

      // Initial greeting message
      final greetingText =
          'Hi there! 👋 I\'m PutraBot, your mental wellness AI assistant. I\'m here to listen, support you, and help match you with the perfect counselor for what you\'re experiencing.\n\nTell me: How are you feeling today and what\'s on your mind? The more you share, the better I can help!';

      // Save greeting to Firestore
      await firestore.saveChatMessageToConversation(
        userId: user.uid,
        conversationId: conversationId,
        sender: 'bot',
        text: greetingText,
        metadata: {'showMoodButtons': true},
      );

      setState(() {
        _currentConversationId = conversationId;
        _messages = [
          {
            'sender': 'bot',
            'text': greetingText,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'showMoodButtons': true,
          }
        ];
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('Error starting conversation: $e');
      setState(() {
        _isLoading = false;
        // Show greeting anyway even if save fails
        _messages = [
          {
            'sender': 'bot',
            'text':
                'Hi there! 👋 I\'m PutraBot, your mental wellness AI assistant. I\'m here to listen, support you, and help match you with the perfect counselor for what you\'re experiencing.\n\nTell me: How are you feeling today and what\'s on your mind? The more you share, the better I can help!',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'showMoodButtons': true,
          }
        ];
      });
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _currentConversationId = conversationId;
      _showSidebar = false;
    });

    try {
      final firestore = ref.read(firestoreProvider);
      final messages = await firestore
          .getConversationMessages(user.uid, conversationId)
          .first;

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      print('Error loading conversation: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendQuickMood(String mood, int score) {
    _handleSend(mood, moodScore: score);
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    await _handleSend(text);
  }

  Future<void> _handleSend(String text, {int? moodScore}) async {
    if (text.isEmpty || _isTyping) return;

    final user = ref.read(authStateProvider).value;
    if (user == null || _currentConversationId == null) return;

    final userMessage = {
      'sender': 'you',
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final firestore = ref.read(firestoreProvider);
      final gemini = ref.read(geminiServiceProvider);

      // Save user message
      await firestore.saveChatMessageToConversation(
        userId: user.uid,
        conversationId: _currentConversationId!,
        sender: 'you',
        text: text,
      );

      // Get mood data
      final moodEntries = await firestore.getRecentMoodEntries(user.uid);
      final moodData = moodEntries
          .map((m) => {
                'moodScore': m.moodScore,
                'note': m.note,
                'timestamp': m.timestamp.millisecondsSinceEpoch,
              })
          .toList();

      // Analyze mood patterns
      final moodAnalysis = gemini.analyzeMoodPattern(moodData);
      final isStruggling = moodAnalysis['isStruggling'] == true;
      final moodSeverity = moodAnalysis['severity']?.toString() ?? 'none';
      final moodSummary = moodAnalysis['summary']?.toString() ?? '';
      final shouldFlagUrgent = moodAnalysis['shouldFlagUrgent'] == true;

      // Check flags
      List<Map<String, dynamic>> existingFlags = [];
      try {
        existingFlags = await firestore.highRiskFlags(user.uid).first;
      } catch (_) {
        // Student users are not allowed to read flags; treat as none
        existingFlags = const [];
      }
      // Treat anything other than explicit true as unresolved to avoid cast issues
      final hasActiveFlag = existingFlags.any((f) => f['resolved'] != true);

      // Build context
      String? moodContext;
      if (moodEntries.isNotEmpty) {
        moodContext = moodSummary;
      }

      final convo = _messages
          .where((msg) => msg['sender'] != 'bot' || msg['text'] is String)
          .map((msg) => {
                'isUser': msg['sender'] == 'you',
                'text': msg['text'] as String,
              })
          .toList();

      // Run AI analysis
      final responseFuture = gemini.sendMessage(
        text,
        conversationHistory: convo,
        moodContext: moodContext,
      );
      final sentimentFuture = gemini.analyzeSentiment(text);
      final bookingIntentFuture = gemini.detectBookingIntent(text);

      final response = await responseFuture;
      final sentiment = await sentimentFuture;
      final riskLevel = sentiment['riskLevel'] as String;

      final bookingIntent = await bookingIntentFuture;
      var hasBookingIntent = (bookingIntent['hasBookingIntent'] == true ||
          bookingIntent['hasBookingIntent'] == 'true');
      var confidence = bookingIntent['confidence']?.toString() ?? 'low';
      var urgency = bookingIntent['urgency']?.toString() ?? 'none';

      // Override with mood urgency
      if ((isStruggling && moodSeverity == 'critical') || shouldFlagUrgent) {
        hasBookingIntent = true;
        confidence = 'high';
        urgency = 'urgent';
      } else if (isStruggling && moodSeverity == 'concerning') {
        if (!hasBookingIntent || confidence == 'low') {
          hasBookingIntent = true;
          confidence = 'medium';
          urgency = 'normal';
        }
      }

      // Force urgent if crisis
      if (hasActiveFlag || riskLevel == 'high' || riskLevel == 'critical') {
        hasBookingIntent = true;
        confidence = 'high';
        urgency = 'urgent';
      }

      // Extract keywords and match counselors
      List<String> problemKeywords = [];
      List<UserProfile>? recommendedCounselors;
      UserProfile? topCounselor;
      List<DateTime>? availableSlots;

      if (hasBookingIntent &&
          (confidence == 'high' || confidence == 'medium')) {
        problemKeywords = await gemini.extractProblemKeywords(text);

        var counselors = <UserProfile>[];
        if (problemKeywords.isNotEmpty) {
          counselors =
              await firestore.getCounselorsByExpertise(problemKeywords);
        }
        if (counselors.isEmpty) {
          counselors = await firestore.counsellors().first;
        }

        if (counselors.isNotEmpty) {
          if (hasActiveFlag || riskLevel == 'critical' || riskLevel == 'high') {
            counselors.sort((a, b) {
              final aScore = _suitabilityScore(a.expertise ?? '');
              final bScore = _suitabilityScore(b.expertise ?? '');
              return bScore.compareTo(aScore);
            });
          }

          topCounselor = counselors.first;
          availableSlots =
              await firestore.getCounselorAvailableSlots(topCounselor.uid);
          recommendedCounselors = counselors.take(3).toList();
        }
      }

      final botMessage = {
        'sender': 'bot',
        'text': response,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sentiment': sentiment,
        'bookingIntent': hasBookingIntent &&
            (confidence == 'high' || confidence == 'medium'),
        'urgency': urgency,
        'recommendedCounselors': recommendedCounselors,
        'problemKeywords': problemKeywords,
        'topCounselor': topCounselor,
        'availableSlots': availableSlots,
        'hasActiveFlag': hasActiveFlag,
      };

      // Auto-book if the user explicitly asked and we have slots
      final explicitBooking = _userRequestedBooking(text);
      final canAutoBook = explicitBooking &&
          topCounselor != null &&
          (availableSlots?.isNotEmpty ?? false);

      if (canAutoBook) {
        await _autoBookCounselor(
          counselor: topCounselor!,
          dateTime: availableSlots!.first,
        );

        // Add an acknowledgement message and exit early
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text':
                'I went ahead and booked the earliest available session with ${topCounselor!.displayName}. If you prefer a different time, let me know!',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _isTyping = false;
        });
        _scrollToBottom();
        return;
      }

      // Save bot response
      await firestore.saveChatMessageToConversation(
        userId: user.uid,
        conversationId: _currentConversationId!,
        sender: 'bot',
        text: response,
        sentiment: sentiment,
        metadata: {
          if (hasBookingIntent) 'bookingIntent': true,
          if (urgency != 'none') 'urgency': urgency,
        },
      );

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      // Show alert if critical
      if (hasActiveFlag ||
          riskLevel == 'high' ||
          riskLevel == 'critical' ||
          urgency == 'urgent') {
        _showCriticalAlert(context, riskLevel);
      }

      _scrollToBottom();
    } catch (e, stackTrace) {
      print('❌ Chat error: $e');
      print('Stack trace: $stackTrace');

      final errorMessage = {
        'sender': 'bot',
        'text':
            'I\'m having trouble connecting. Please try again or contact a counsellor directly.\n\nError: ${e.toString()}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      setState(() {
        _messages.add(errorMessage);
        _isTyping = false;
      });
    }
  }

  Future<void> _autoBookCounselor({
    required UserProfile counselor,
    required DateTime dateTime,
  }) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final firestore = ref.read(firestoreProvider);
      final end = dateTime.add(const Duration(minutes: 45));

      await firestore.createAppointment(
        studentId: user.uid,
        counsellorId: counselor.uid,
        start: dateTime,
        end: end,
        topic: 'AI Chat Recommendation',
        initialProblem: 'Booked through AI assistant',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Appointment booked with ${counselor.displayName}!'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text':
              '✅ Your appointment with ${counselor.displayName} is confirmed for ${dateTime.day}/${dateTime.month} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}. You can view it in your appointments. Looking forward to your session!',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking: $e')),
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

  int _suitabilityScore(String expertise) {
    final lower = expertise.toLowerCase();
    int score = 0;
    if (lower.contains('mental') ||
        lower.contains('depression') ||
        lower.contains('anxiety')) {
      score += 3;
    }
    if (lower.contains('stress') ||
        lower.contains('trauma') ||
        lower.contains('crisis')) {
      score += 2;
    }
    if (lower.contains('counsel') || lower.contains('therapy')) {
      score += 1;
    }
    return score;
  }

  void _showCriticalAlert(BuildContext context, String riskLevel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ We\'re Here to Help'),
        content: Text(
          riskLevel == 'critical'
              ? 'I notice you might be going through a really difficult time. Professional support can make a real difference. Let me help you book an urgent session right now.'
              : 'It sounds like you could really benefit from talking to a counselor. They can provide personalized support tailored to what you\'re experiencing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _scrollToBottom();
            },
            child: const Text('Book Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
            'Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      await ref
          .read(firestoreProvider)
          .deleteChatConversation(user.uid, conversationId);

      if (conversationId == _currentConversationId) {
        _startNewConversation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return PrimaryScaffold(
      title: 'PutraBot',
      body: Row(
        children: [
          // Sidebar for conversation history
          if (_showSidebar)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // New chat button
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          _startNewConversation();
                          setState(() => _showSidebar = false);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Chat'),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Conversation history
                  Expanded(
                    child: user == null
                        ? const Center(child: Text('Not logged in'))
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: ref
                                .read(firestoreProvider)
                                .getChatConversations(user.uid),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final conversations = snapshot.data!;

                              if (conversations.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No past conversations yet.\nStart a new chat!',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: conversations.length,
                                itemBuilder: (context, index) {
                                  final convo = conversations[index];
                                  final isActive =
                                      convo['id'] == _currentConversationId;

                                  return ListTile(
                                    selected: isActive,
                                    leading:
                                        const Icon(Icons.chat_bubble_outline),
                                    title: Text(
                                      convo['title'] ?? 'New Chat',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _formatTimestamp(
                                          convo['updatedAt'] as int?),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18),
                                      onPressed: () =>
                                          _confirmDeleteConversation(
                                              convo['id']),
                                    ),
                                    onTap: () => _loadConversation(convo['id']),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

          // Main chat area
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_showSidebar ? Icons.close : Icons.menu),
                        onPressed: () {
                          setState(() => _showSidebar = !_showSidebar);
                        },
                      ),
                      Icon(Icons.psychology,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PutraBot powered by Gemini • AI-matched counselor recommendations',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'New Chat',
                        onPressed: _startNewConversation,
                      ),
                    ],
                  ),
                ),

                // Messages
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
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
                  ),

                // Typing indicator
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
                        Text('PutraBot is thinking...',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),

                // Input area
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
                            hintText: 'Tell me what\'s on your mind...',
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isBot = msg['sender'] == 'bot';
    final text = msg['text'] as String?;
    final showMoodButtons = msg['showMoodButtons'] == true;
    final sentiment = msg['sentiment'] as Map<String, dynamic>?;
    final hasBookingIntent = msg['bookingIntent'] == true;
    final urgency = msg['urgency']?.toString() ?? 'none';
    final recommendedCounselors =
        msg['recommendedCounselors'] as List<UserProfile>?;
    final problemKeywords = msg['problemKeywords'] as List<String>?;
    final topCounselor = msg['topCounselor'] as UserProfile?;
    final availableSlots = msg['availableSlots'] as List<DateTime>?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Align(
            alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBot
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text ?? '',
                style: TextStyle(
                  color: isBot ? null : Colors.white,
                ),
              ),
            ),
          ),

          // Quick mood buttons (only on first message)
          if (showMoodButtons && isBot) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick mood check:',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _MoodButton(
                        emoji: '😊',
                        label: 'Happy',
                        onTap: () => _sendQuickMood('Feeling happy', 9),
                      ),
                      _MoodButton(
                        emoji: '😐',
                        label: 'Okay',
                        onTap: () => _sendQuickMood('Feeling okay', 6),
                      ),
                      _MoodButton(
                        emoji: '😟',
                        label: 'Not Great',
                        onTap: () => _sendQuickMood('Not feeling great', 3),
                      ),
                      _MoodButton(
                        emoji: '😞',
                        label: 'Struggling',
                        onTap: () => _sendQuickMood('Really struggling', 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Risk indicator
          if (sentiment != null && sentiment['riskLevel'] != 'low' && isBot)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                '⚠️ ${sentiment['riskLevel']} risk detected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: sentiment['riskLevel'] == 'critical'
                      ? Colors.red
                      : Colors.orange,
                ),
              ),
            ),

          // Problem keywords
          if (problemKeywords != null &&
              problemKeywords.isNotEmpty &&
              hasBookingIntent &&
              isBot)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: Wrap(
                spacing: 4,
                children: problemKeywords
                    .take(4)
                    .map((keyword) => Chip(
                          label: Text(
                            keyword,
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                        ))
                    .toList(),
              ),
            ),

          // Counselor recommendations
          if (recommendedCounselors != null &&
              recommendedCounselors.isNotEmpty &&
              hasBookingIntent &&
              isBot)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '🎯 AI-Matched Counselors',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recommendedCounselors.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, i) {
                        final counselor = recommendedCounselors[i];
                        return _CounselorCard(
                          counselor: counselor,
                          onViewDetails: () =>
                              _navigateToCounselorDetail(counselor.uid),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Top counselor booking section
          if (topCounselor != null &&
              availableSlots != null &&
              availableSlots.isNotEmpty &&
              hasBookingIntent &&
              isBot)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: urgency == 'urgent'
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: urgency == 'urgent'
                        ? Colors.orange
                        : Theme.of(context).colorScheme.primary,
                    width: urgency == 'urgent' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '🎯 ${topCounselor.displayName}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (urgency == 'urgent') ...[
                          const SizedBox(width: 4),
                          const Chip(
                            label: Text('URGENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                )),
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ],
                    ),
                    if (topCounselor.expertise != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📚 ${topCounselor.expertise}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Available times:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: availableSlots.take(4).map((slot) {
                        return Chip(
                          label: Text(
                            '${slot.day}/${slot.month} ${slot.hour}:${slot.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _autoBookConsent,
                          onChanged: (v) {
                            setState(() => _autoBookConsent = v ?? false);
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: Text(
                            'Let AI book automatically',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.go('/student/counsellors');
                            },
                            icon: const Icon(Icons.list, size: 18),
                            label: const Text('Browse All'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _autoBookConsent
                                ? () {
                                    final firstSlot = availableSlots.first;
                                    _autoBookCounselor(
                                      counselor: topCounselor,
                                      dateTime: firstSlot,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Book Now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToCounselorDetail(String counselorId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(counselorId)
        .get()
        .then((doc) {
      if (doc.exists && mounted) {
        final counselor = UserProfile.fromJson(doc.data()!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CounsellorDetailPage(counsellor: counselor),
          ),
        );
      }
    });
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _MoodButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _MoodButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CounselorCard extends StatelessWidget {
  final UserProfile counselor;
  final VoidCallback onViewDetails;

  const _CounselorCard({
    required this.counselor,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      counselor.displayName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      counselor.displayName,
                      style: Theme.of(context).textTheme.labelMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                counselor.designation ?? 'Counselor',
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  counselor.expertise ?? 'General counseling',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onViewDetails,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('View Profile',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
