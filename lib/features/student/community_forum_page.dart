import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/forum_post.dart';
import '../../providers/auth_providers.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../common/common_widgets.dart';

final firestoreProvider = Provider((ref) => FirestoreService());
final geminiServiceProvider = Provider((ref) => GeminiService());

class CommunityForumPage extends ConsumerStatefulWidget {
  const CommunityForumPage({super.key, this.embedded = false});

  // When embedded inside another scaffold (e.g., Counsellor Dashboard),
  // avoid wrapping with PrimaryScaffold to prevent duplicate footers.
  final bool embedded;

  @override
  ConsumerState<CommunityForumPage> createState() => _CommunityForumPageState();
}

class _CommunityForumPageState extends ConsumerState<CommunityForumPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _showCommentDialog(BuildContext context, ForumPost post) {
    final commentController = TextEditingController();
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(userProfileProvider).value;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a comment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Post: ${post.title}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your comment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty ||
                  user == null ||
                  profile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment cannot be empty')),
                );
                return;
              }

              try {
                await ref.read(firestoreProvider).addForumComment(
                      postId: post.id,
                      userId: user.uid,
                      userName: profile.displayName,
                      content: commentController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment added!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPost() async {
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(userProfileProvider).value;

    if (user == null || profile == null || _title.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final content = _content.text.trim();

      // Analyze post content for concerning sentiment
      Map<String, dynamic> sentiment = {};
      if (content.isNotEmpty) {
        final gemini = ref.read(geminiServiceProvider);
        sentiment = await gemini.analyzeSentiment('$_title ${_content.text}');
      }

      final post = ForumPost(
        id: '',
        authorId: user.uid,
        authorName: profile.displayName,
        title: _title.text.trim(),
        content: content,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreProvider).addForumPost(post);

      // Flag concerning forum posts to counsellors
      if (sentiment['riskLevel'] == 'high' ||
          sentiment['riskLevel'] == 'critical') {
        await ref.read(firestoreProvider).flagHighRiskStudent(
              studentId: user.uid,
              studentName: profile.displayName,
              riskLevel: sentiment['riskLevel'] ?? 'medium',
              sentiment: sentiment['sentiment'] ?? 'concerning',
              message:
                  'Forum post: "${_title.text.trim()}" - ${content.substring(0, (content.length > 100 ? 100 : content.length))}...',
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (sentiment['riskLevel'] == 'high' ||
                      sentiment['riskLevel'] == 'critical')
                  ? 'Post published. A counsellor may reach out to support you.'
                  : 'Post published!',
            ),
          ),
        );
        setState(() {
          _title.clear();
          _content.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      // When embedded, return a simple message without a scaffold
      if (widget.embedded) {
        return const Center(child: Text('Please sign in'));
      }
      return const PrimaryScaffold(
        title: 'Community forum',
        body: Center(child: Text('Please sign in')),
      );
    }

    final postsStream = ref.watch(firestoreProvider).communityPosts();

    final body = StreamBuilder<List<ForumPost>>(
      stream: postsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading posts: ${snapshot.error}'),
            ),
          );
        }
        final posts = snapshot.data ?? [];

        return Column(
          children: [
            SectionCard(
              title: 'Share an update',
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _content,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Content'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _addPost,
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : const Text('Post'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: posts.isEmpty
                  ? const EmptyState(message: 'No posts yet')
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final hasLiked = post.likes
                            .contains(ref.watch(authStateProvider).value?.uid);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'by ${post.authorName} • ${DateFormat('MMM d').format(post.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        hasLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: hasLiked ? Colors.red : null,
                                      ),
                                      onPressed: () async {
                                        final userId = ref
                                            .read(authStateProvider)
                                            .value
                                            ?.uid;
                                        if (userId != null) {
                                          try {
                                            if (hasLiked) {
                                              await ref
                                                  .read(firestoreProvider)
                                                  .unlikeForumPost(
                                                      post.id, userId);
                                            } else {
                                              await ref
                                                  .read(firestoreProvider)
                                                  .likeForumPost(
                                                      post.id, userId);
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    Text('${post.likes.length} likes',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.comment_outlined),
                                      onPressed: () {
                                        _showCommentDialog(context, post);
                                      },
                                    ),
                                    Text('${post.commentCount} comments',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                                if (post.commentCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: StreamBuilder<
                                        List<Map<String, dynamic>>>(
                                      stream: ref
                                          .read(firestoreProvider)
                                          .forumComments(post.id),
                                      builder: (context, commentSnapshot) {
                                        final comments =
                                            commentSnapshot.data ?? [];
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
                                            const Text(
                                              'Recent comments:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                            ),
                                            const SizedBox(height: 8),
                                            ...comments.take(3).map((comment) =>
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          comment['userName'] ??
                                                              'Anonymous',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                        ),
                                                        Text(
                                                          comment['content'] ??
                                                              '',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                                  'MMM d, h:mm a')
                                                              .format(
                                                            DateTime
                                                                .fromMillisecondsSinceEpoch(
                                                              (comment['createdAt']
                                                                          as num?)
                                                                      ?.toInt() ??
                                                                  0,
                                                            ),
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )),
                                            if (comments.length > 3)
                                              TextButton(
                                                onPressed: () =>
                                                    _showAllComments(
                                                        context, post),
                                                child: Text(
                                                    'View all ${post.commentCount} comments'),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return PrimaryScaffold(
      title: 'Community forum',
      body: body,
    );
  }

  void _showAllComments(BuildContext context, ForumPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All Comments (${post.commentCount})'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ref.read(firestoreProvider).forumComments(post.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return const Center(child: Text('No comments yet'));
              }
              return ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                comment['userName'] ?? 'Anonymous',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                DateFormat('MMM d, h:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    (comment['createdAt'] as num?)?.toInt() ??
                                        0,
                                  ),
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(comment['content'] ?? ''),
                        ],
                      ),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
