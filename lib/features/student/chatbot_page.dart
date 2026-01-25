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
      final firestore = ref.read(firestoreProvider);
      final gemini = ref.read(geminiServiceProvider);

      // Save user message to Firestore
      await firestore.saveChatMessage(
        userId: user.uid,
        sender: 'you',
        text: text,
      );

      // Get recent mood entries for context
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
      final isStruggling = moodAnalysis['isStruggling'] as bool;
      final moodSeverity = moodAnalysis['severity'] as String;
      final moodSummary = moodAnalysis['summary'] as String;

      // Check existing high-risk flags on student
      final existingFlags = await firestore.highRiskFlags(user.uid).first;
      final hasActiveFlag =
          existingFlags.any((f) => (f['resolved'] as bool? ?? false) == false);

      // Build mood context for Gemini
      String? moodContext;
      if (moodEntries.isNotEmpty) {
        moodContext = moodSummary;
      }

      final convo = _messages
          .map((msg) => {
                'isUser': msg['sender'] == 'you',
                'text': msg['text'] as String,
              })
          .toList();

      // Run model calls in parallel to cut perceived latency
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

      // Check for booking intent or mood-based urgent need
      final bookingIntent = await bookingIntentFuture;
      var hasBookingIntent =
          bookingIntent['hasBookingIntent'] as bool? ?? false;
      var confidence = bookingIntent['confidence'] as String? ?? 'low';
      var urgency = bookingIntent['urgency'] as String? ?? 'none';

      // Override with mood-based urgency if struggling
      if (isStruggling && moodSeverity == 'critical') {
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

      // Force urgent booking intent if there is an active flag
      if (hasActiveFlag || riskLevel == 'high' || riskLevel == 'critical') {
        hasBookingIntent = true;
        confidence = 'high';
        urgency = 'urgent';
      }

      // Extract problem keywords for counselor matching
      List<String> problemKeywords = [];
      List<String>? recommendedCounselors;
      String? topCounselorId;
      String? topCounselorName;
      String? topCounselorExpertise;
      List<DateTime>? availableSlots;

      if (hasBookingIntent &&
          (confidence == 'high' || confidence == 'medium')) {
        problemKeywords = await gemini.extractProblemKeywords(text);
        // Fetch best-fit counselors; if keywords are empty, fall back to all active counsellors
        var counselors = <UserProfile>[];
        if (problemKeywords.isNotEmpty) {
          counselors =
              await firestore.getCounselorsByExpertise(problemKeywords);
        }
        if (counselors.isEmpty) {
          counselors = await firestore.counsellors().first;
        }

        if (counselors.isNotEmpty) {
          // If flagged/urgent, prioritize counsellors with mental health keywords
          if (hasActiveFlag || riskLevel == 'critical' || riskLevel == 'high') {
            counselors.sort((a, b) {
              final aScore = _suitabilityScore(a.expertise ?? '');
              final bScore = _suitabilityScore(b.expertise ?? '');
              return bScore.compareTo(aScore);
            });
          }

          final topCounselor = counselors.first;
          topCounselorId = topCounselor.uid;
          topCounselorName = topCounselor.displayName;
          topCounselorExpertise = topCounselor.expertise;

          // Get available slots
          availableSlots =
              await firestore.getCounselorAvailableSlots(topCounselorId);

          recommendedCounselors = counselors.take(3).map((c) => c.uid).toList();
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
        'topCounselorId': topCounselorId,
        'topCounselorName': topCounselorName,
        'topCounselorExpertise': topCounselorExpertise,
        'availableSlots': availableSlots,
        'hasActiveFlag': hasActiveFlag,
      };

      // Save bot response to Firestore
      await firestore.saveChatMessage(
        userId: user.uid,
        sender: 'bot',
        text: response,
        sentiment: sentiment,
      );

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      // Show risk alert with urgency; if already flagged, emphasize booking
      if (hasActiveFlag ||
          riskLevel == 'high' ||
          riskLevel == 'critical' ||
          urgency == 'urgent') {
        _showRiskAlert(context, 'critical');
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

  Future<void> _autoBookCounselor({
    required String counselorId,
    required String counselorName,
    required DateTime dateTime,
  }) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final firestore = ref.read(firestoreProvider);
      final end = dateTime.add(const Duration(minutes: 45));

      // Create the appointment automatically
      await firestore.createAppointment(
        studentId: user.uid,
        counsellorId: counselorId,
        start: dateTime,
        end: end,
        topic: 'Auto-booked from AI Chat',
        initialProblem: 'Booked through AI assistant recommendation',
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Appointment booked with $counselorName!'),
          duration: const Duration(seconds: 3),
        ),
      );

      // Add system message to chat
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text':
              '✅ Your appointment with $counselorName has been confirmed for ${dateTime.day}/${dateTime.month} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}. You can view it in your appointments.',
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

  void _navigateToCounselorDetail(String counselorId) {
    if (mounted) {
      // Fetch counselor profile and navigate
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
  }

  void _showRiskAlert(BuildContext context, String level) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Available'),
        content: Text(
          level == 'critical'
              ? 'I notice you might be going through a difficult time. Please consider booking a counselling session. If you need immediate help, please contact emergency services.'
              : 'I\'m here to support you. Consider booking a session with one of our professional counsellors for personalized guidance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showRecommendedCounselors(
      BuildContext context, List<String> counselorIds) {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (consumerContext, ref, _) {
          return AlertDialog(
            title: const Text('Recommended Counselors'),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<UserProfile>>(
                future: Future.wait(
                  counselorIds.map((id) async {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(id)
                        .get();
                    return UserProfile.fromJson(doc.data()!);
                  }),
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final counselors = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: counselors.length,
                    itemBuilder: (context, index) {
                      final counselor = counselors[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(counselor.displayName[0]),
                          ),
                          title: Text(counselor.displayName),
                          subtitle: Text(
                            counselor.expertise ?? 'General Counseling',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            // Use parent widget's navigation method
                            _navigateToCounselorDetail(counselor.uid);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/student/counsellors');
                },
                child: const Text('Browse All'),
              ),
            ],
          );
        },
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
                  final hasBookingIntent =
                      msg['bookingIntent'] as bool? ?? false;
                  final urgency = msg['urgency'] as String? ?? 'none';
                  final recommendedCounselors =
                      (msg['recommendedCounselors'] as List?)?.cast<String>();
                  final problemKeywords =
                      (msg['problemKeywords'] as List?)?.cast<String>();
                  final topCounselorId = msg['topCounselorId'] as String?;
                  final topCounselorName = msg['topCounselorName'] as String?;
                  final topCounselorExpertise =
                      msg['topCounselorExpertise'] as String?;
                  final availableSlots =
                      (msg['availableSlots'] as List?)?.cast<DateTime>();

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
                        if (hasBookingIntent && isBot)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (problemKeywords != null &&
                                    problemKeywords.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      children: problemKeywords
                                          .take(3)
                                          .map((keyword) {
                                        return Chip(
                                          label: Text(
                                            keyword,
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                if (recommendedCounselors != null &&
                                    recommendedCounselors.isNotEmpty)
                                  FilledButton.icon(
                                    onPressed: () {
                                      _showRecommendedCounselors(
                                          context, recommendedCounselors);
                                    },
                                    icon: Icon(
                                      urgency == 'urgent'
                                          ? Icons.warning_amber_rounded
                                          : Icons.person_search,
                                      color: urgency == 'urgent'
                                          ? Colors.orange
                                          : null,
                                    ),
                                    label: Text(
                                      urgency == 'urgent'
                                          ? 'View Matched Counselors (Urgent)'
                                          : 'View Matched Counselors',
                                    ),
                                    style: urgency == 'urgent'
                                        ? FilledButton.styleFrom(
                                            backgroundColor: Colors.orange
                                                .withValues(alpha: 0.2),
                                          )
                                        : null,
                                  )
                                else
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      context.go('/student/counsellors');
                                    },
                                    icon: Icon(
                                      urgency == 'urgent'
                                          ? Icons.warning_amber_rounded
                                          : Icons.calendar_today,
                                      color: urgency == 'urgent'
                                          ? Colors.orange
                                          : null,
                                    ),
                                    label: Text(
                                      urgency == 'urgent'
                                          ? 'Book Urgent Session'
                                          : 'Browse Counsellors',
                                    ),
                                    style: urgency == 'urgent'
                                        ? FilledButton.styleFrom(
                                            backgroundColor: Colors.orange
                                                .withValues(alpha: 0.2),
                                          )
                                        : null,
                                  ),
                                if (topCounselorId != null &&
                                    topCounselorName != null &&
                                    availableSlots != null &&
                                    availableSlots.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainer,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🎯 AI Suggested: $topCounselorName',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                        if (topCounselorExpertise != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Expertise: $topCounselorExpertise',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          'Available times:',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: availableSlots
                                              .take(3)
                                              .map((slot) {
                                            return Chip(
                                              label: Text(
                                                '${slot.day}/${slot.month} ${slot.hour}:${slot.minute.toString().padLeft(2, '0')}',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () {
                                              final firstSlot =
                                                  availableSlots.first;
                                              _autoBookCounselor(
                                                counselorId: topCounselorId,
                                                counselorName: topCounselorName,
                                                dateTime: firstSlot,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.check_circle,
                                              size: 18,
                                            ),
                                            label:
                                                const Text('Let AI Book This'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
