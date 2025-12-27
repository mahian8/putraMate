import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../models/appointment.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_providers.dart';
import '../common/common_widgets.dart';

class CounsellorDetailPage extends ConsumerStatefulWidget {
  const CounsellorDetailPage({super.key, required this.counsellor});

  final UserProfile counsellor;

  @override
  ConsumerState<CounsellorDetailPage> createState() =>
      _CounsellorDetailPageState();
}

class _CounsellorDetailPageState extends ConsumerState<CounsellorDetailPage> {
  late Future<List<Appointment>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    final fs = FirestoreService();
    // Fetch all reviews for this counsellor (visible to all students via Firestore rule)
    _reviewsFuture = fs.counsellorReviews(widget.counsellor.uid).first;
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Counsellor Details',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Counsellor Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.counsellor.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      // Average Rating Display
                      FutureBuilder<List<Appointment>>(
                        future: _reviewsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final reviews = snapshot.data ?? [];
                            final ratingsOnly = reviews
                                .where((r) => r.studentRating != null)
                                .map((r) => r.studentRating!)
                                .toList();

                            if (ratingsOnly.isNotEmpty) {
                              final avgRating =
                                  ratingsOnly.reduce((a, b) => a + b) /
                                      ratingsOnly.length;
                              return Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${avgRating.toStringAsFixed(1)} / 5.0',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${ratingsOnly.length} ${ratingsOnly.length == 1 ? 'review' : 'reviews'})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 8),
                      if (widget.counsellor.expertise != null) ...[
                        Chip(
                            label: Text(
                                'Expertise: ${widget.counsellor.expertise}')),
                        const SizedBox(height: 8),
                      ],
                      if (widget.counsellor.designation != null)
                        Text(
                          'Designation: ${widget.counsellor.designation}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Email: ${widget.counsellor.email}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reviews Section
              Text(
                'Student Reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Appointment>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading reviews: ${snapshot.error}'),
                    );
                  }

                  final reviews = snapshot.data ?? [];

                  if (reviews.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No reviews yet'),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      final fs = ref.watch(firestoreServiceProvider);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student name and date
                              StreamBuilder<UserProfile?>(
                                stream: fs.userProfile(review.studentId),
                                builder: (context, studentSnapshot) {
                                  final studentName =
                                      studentSnapshot.data?.displayName ??
                                          'Anonymous';
                                  final nameInitial = studentName.isNotEmpty
                                      ? studentName[0].toUpperCase()
                                      : '?';
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            child: Text(
                                              nameInitial,
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            studentName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat('MMM d, y').format(
                                            review.updatedAt ??
                                                review.createdAt ??
                                                DateTime.now()),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Rating
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      size: 18,
                                      color: i <
                                              (review.studentRating?.toInt() ??
                                                  0)
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${review.studentRating?.toStringAsFixed(1) ?? "N/A"} / 5',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // Comment
                              if (review.studentComment != null &&
                                  review.studentComment!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    review.studentComment!,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
