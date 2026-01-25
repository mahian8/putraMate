import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';
import 'counsellor_detail_page.dart';
import 'package:intl/intl.dart';

final _fsProvider = Provider((ref) => FirestoreService());

class CounsellorCatalogPage extends ConsumerStatefulWidget {
  const CounsellorCatalogPage({super.key});

  @override
  ConsumerState<CounsellorCatalogPage> createState() =>
      _CounsellorCatalogPageState();
}

class _CounsellorCatalogPageState extends ConsumerState<CounsellorCatalogPage> {
  String _selectedFilter = 'all'; // 'all', 'available', 'aiRecommendation'
  List<String> _recommendedCounsellorIds = [];
  bool _isLoadingRecommendations = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(_fsProvider).counsellors();

    return PrimaryScaffold(
      title: 'Counsellors',
      body: StreamBuilder<List<UserProfile>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final counsellors = snapshot.data ?? [];

          if (counsellors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No counsellors available yet'),
                  const SizedBox(height: 8),
                  const Text(
                    'Please ask your admin to add counsellors',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Filter counsellors based on selection
          List<UserProfile> filteredCounsellors = counsellors.where((c) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return (c.displayName.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q) ||
                (c.expertise?.toLowerCase().contains(q) ?? false));
          }).toList();

          return Column(
            children: [
              // Search + Filter
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText:
                                  'Find counsellor by name, email, or expertise',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (val) =>
                                setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text('Find'),
                          onPressed: () => setState(
                              () => _searchQuery = _searchCtrl.text.trim()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Results for "$_searchQuery"',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All Counsellors'),
                            selected: _selectedFilter == 'all',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = 'all');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Available Now'),
                            selected: _selectedFilter == 'available',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = 'available');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.psychology,
                                    size: 16,
                                    color: _selectedFilter == 'aiRecommendation'
                                        ? Theme.of(context).colorScheme.primary
                                        : null),
                                const SizedBox(width: 4),
                                const Text('AI Recommendation'),
                              ],
                            ),
                            selected: _selectedFilter == 'aiRecommendation',
                            onSelected: (selected) async {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = 'aiRecommendation';
                                  _isLoadingRecommendations = true;
                                });
                                await _loadAIRecommendations();
                                if (mounted) {
                                  setState(
                                      () => _isLoadingRecommendations = false);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildCounsellorsList(filteredCounsellors),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounsellorsList(List<UserProfile> counsellors) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllLeaves(counsellors.map((c) => c.uid).toList()),
      builder: (context, leavesSnapshot) {
        // Get all leaves data
        final allLeaves = <String, List<Map<String, dynamic>>>{};
        for (final leave in leavesSnapshot.data ?? []) {
          final uid = leave['counsellorId'] as String?;
          if (uid != null) {
            allLeaves.putIfAbsent(uid, () => []).add(leave);
          }
        }

        // Apply filtering
        List<UserProfile> filtered = counsellors;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (_selectedFilter == 'available') {
          filtered = counsellors.where((c) {
            if (!c.isActive) return false;
            final leaves = allLeaves[c.uid] ?? [];
            bool onLeaveNow = leaves.any((l) {
              final s = (l['startDate'] as int? ?? 0);
              final e = (l['endDate'] as int? ?? 0);
              return s <= nowMs && e >= nowMs;
            });
            return !onLeaveNow;
          }).toList();
        } else if (_selectedFilter == 'aiRecommendation') {
          if (_isLoadingRecommendations) {
            // Show loading state
            filtered = counsellors;
          } else if (_recommendedCounsellorIds.isNotEmpty) {
            // Filter and sort by AI recommendations
            filtered = counsellors
                .where((c) => _recommendedCounsellorIds.contains(c.uid))
                .toList();
            // Sort by recommendation order
            filtered.sort((a, b) {
              final aIndex = _recommendedCounsellorIds.indexOf(a.uid);
              final bIndex = _recommendedCounsellorIds.indexOf(b.uid);
              return aIndex.compareTo(bIndex);
            });
          } else {
            // No recommendations available
            filtered = [];
          }
        }

        if (_isLoadingRecommendations &&
            _selectedFilter == 'aiRecommendation') {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('AI is analyzing your profile...'),
              ],
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedFilter == 'aiRecommendation'
                      ? Icons.psychology_outlined
                      : Icons.filter_list_off,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 'aiRecommendation'
                      ? 'No recommendations available yet'
                      : 'No counsellors match this filter',
                ),
                const SizedBox(height: 8),
                if (_selectedFilter == 'aiRecommendation')
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Keep tracking your mood to get personalized recommendations',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedFilter = 'all'),
                  child: const Text('View All Counsellors'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final c = filtered[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.email,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    // Status: inactive / on leave now / upcoming leave
                    Consumer(builder: (context, ref, _) {
                      final fs = ref.watch(_fsProvider);
                      if (!c.isActive) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Inactive',
                              style: TextStyle(color: Colors.redAccent)),
                        );
                      }
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: fs.userLeaves(c.uid),
                        builder: (context, snap) {
                          final nowMs = DateTime.now().millisecondsSinceEpoch;
                          final leaves = snap.data ?? [];
                          Map<String, dynamic>? active;
                          for (final l in leaves) {
                            final s = (l['startDate'] as int? ?? 0);
                            final e = (l['endDate'] as int? ?? 0);
                            if (s <= nowMs && e >= nowMs) {
                              active = l;
                              break;
                            }
                          }
                          if (active != null) {
                            final e = DateTime.fromMillisecondsSinceEpoch(
                                active['endDate'] as int);
                            final type =
                                (active['leaveType'] as String?) ?? 'leave';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Out of service now • until ${DateFormat('MMM d, y').format(e)} ($type)',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }
                          leaves.sort((a, b) => (a['startDate'] as int)
                              .compareTo(b['startDate'] as int));
                          final upcoming = leaves.firstWhere(
                              (l) => (l['startDate'] as int) >= nowMs,
                              orElse: () => {});
                          if (upcoming.isNotEmpty) {
                            final s = DateTime.fromMillisecondsSinceEpoch(
                                upcoming['startDate'] as int);
                            final e = DateTime.fromMillisecondsSinceEpoch(
                                upcoming['endDate'] as int);
                            final type =
                                (upcoming['leaveType'] as String?) ?? 'leave';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Leave scheduled: ${DateFormat('MMM d').format(s)} - ${DateFormat('MMM d, y').format(e)} ($type)',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final fs = ref.watch(_fsProvider);
                      final isInactive = !c.isActive;
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: fs.userLeaves(c.uid),
                        builder: (context, snap) {
                          final nowMs = DateTime.now().millisecondsSinceEpoch;
                          final leaves = snap.data ?? [];
                          final onLeaveNow = leaves.any((l) {
                            final s = (l['startDate'] as int? ?? 0);
                            final e = (l['endDate'] as int? ?? 0);
                            return s <= nowMs && e >= nowMs;
                          });
                          final canBook = !isInactive && !onLeaveNow;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CounsellorDetailPage(counsellor: c),
                                  ),
                                ),
                                child: const Text('View Details'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: canBook
                                    ? () => context.pushNamed(
                                          AppRoute.booking.name,
                                          queryParameters: {
                                            'cid': c.uid,
                                            'cname': c.displayName,
                                          },
                                        )
                                    : null,
                                child: const Text('Book'),
                              ),
                            ],
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllLeaves(
      List<String> counsellorIds) async {
    try {
      final fs = ref.read(_fsProvider);
      final result = <Map<String, dynamic>>[];
      for (final uid in counsellorIds) {
        try {
          final leaves = await fs.userLeaves(uid).first;
          for (final l in leaves) {
            result.add({'counsellorId': uid, ...l});
          }
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadAIRecommendations() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final fs = ref.read(_fsProvider);
      final gemini = GeminiService();

      // Fetch recent mood entries (last 30 days)
      final moodEntries = await fs.getRecentMoodEntries(user.uid);
      final recentMoods = moodEntries
          .where((m) => m.timestamp
              .isAfter(DateTime.now().subtract(const Duration(days: 30))))
          .toList();

      // Fetch appointment history to understand past interactions
      final appointments = await fs.appointmentsForUser(user.uid).first;
      final pastAppointments =
          appointments.where((a) => a.end.isBefore(DateTime.now())).toList();

      // Build context for AI
      final moodContext = recentMoods.isEmpty
          ? 'No recent mood entries'
          : recentMoods.map((m) {
              return 'Date: ${DateFormat('MMM d').format(m.timestamp)}, '
                  'Mood: ${m.moodScore}/10, '
                  'Note: ${m.note.isNotEmpty ? m.note : "none"}';
            }).join('; ');

      final appointmentContext = pastAppointments.isEmpty
          ? 'No previous counselling sessions'
          : 'Had ${pastAppointments.length} previous sessions';

      // Get all counsellors
      final counsellors = await fs.counsellors().first;
      final counsellorContext = counsellors.map((c) {
        return '- ${c.displayName} (ID: ${c.uid}): '
            '${c.expertise ?? "General counselling"}, '
            '${c.designation ?? "Counsellor"}';
      }).join('\n');

      // Create AI prompt
      final prompt = '''
Based on the student's mental health profile, recommend the most suitable counsellors.

STUDENT PROFILE:
Recent Mood History (last 30 days): $moodContext
Counselling History: $appointmentContext

AVAILABLE COUNSELLORS:
$counsellorContext

Provide recommendations as a JSON array with counsellor UIDs in priority order (most suitable first).
Consider:
- Mood patterns (low scores suggest need for depression/anxiety specialist)
- Expertise alignment (match counsellor expertise with student needs)
- Previous positive experiences (if any)
- Limit to top 3-5 recommendations

Respond ONLY with JSON format: {"recommendations": ["uid1", "uid2", "uid3"]}
''';

      final response = await gemini.sendMessage(prompt);

      // Parse AI response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        try {
          final jsonStr = response.substring(jsonStart, jsonEnd);

          // Try parsing with regex
          final match = RegExp(r'"recommendations"\s*:\s*\[([^\]]+)\]')
              .firstMatch(jsonStr);
          if (match != null) {
            final uidList = match.group(1);
            if (uidList != null) {
              final uids = uidList
                  .split(',')
                  .map((s) => s.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();

              if (mounted) {
                setState(() {
                  _recommendedCounsellorIds = uids;
                });
              }
              return;
            }
          }
        } catch (e) {
          // Parsing failed, will show empty state
        }
      }

      // Fallback: if AI fails, recommend based on simple heuristics
      if (_recommendedCounsellorIds.isEmpty && recentMoods.isNotEmpty) {
        final avgMood =
            recentMoods.map((m) => m.moodScore).reduce((a, b) => a + b) /
                recentMoods.length;

        // If mood is consistently low, prioritize mental health specialists
        final filtered = avgMood < 5
            ? counsellors
                .where((c) =>
                    c.expertise?.toLowerCase().contains('mental') == true ||
                    c.expertise?.toLowerCase().contains('depression') == true ||
                    c.expertise?.toLowerCase().contains('anxiety') == true)
                .toList()
            : counsellors;

        if (mounted) {
          setState(() {
            _recommendedCounsellorIds =
                filtered.take(3).map((c) => c.uid).toList();
          });
        }
      }
    } catch (e) {
      // Error loading recommendations
      if (mounted) {
        setState(() {
          _recommendedCounsellorIds = [];
        });
      }
    }
  }
}
