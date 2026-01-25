import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../models/appointment.dart';
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
  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);

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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.12),
                            child: Text(
                              widget.counsellor.displayName.isNotEmpty
                                  ? widget.counsellor.displayName[0]
                                      .toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.counsellor.displayName,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                if (widget.counsellor.designation != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      widget.counsellor.designation!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Colors.grey.shade700),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.email_outlined,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          widget.counsellor.email,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.counsellor.counsellorId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'ID: ${widget.counsellor.counsellorId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Colors.grey.shade600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.counsellor.expertise != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.counsellor.expertise!
                              .split(',')
                              .map((tag) => tag.trim())
                              .where((tag) => tag.isNotEmpty)
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08),
                                  labelStyle: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Average Rating Display
                      StreamBuilder<List<Appointment>>(
                        stream: fs.counsellorReviews(widget.counsellor.uid),
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
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${avgRating.toStringAsFixed(1)} / 5.0',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                        'Based on ${ratingsOnly.length} review${ratingsOnly.length == 1 ? '' : 's'}'),
                                  ],
                                ),
                              );
                            }
                          }
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('No ratings yet'),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Book Appointment Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            context.go(
                              '/student/booking?cid=${widget.counsellor.uid}&cname=${widget.counsellor.displayName}',
                            );
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Book Appointment'),
                        ),
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
              StreamBuilder<List<Appointment>>(
                stream: fs.counsellorReviews(widget.counsellor.uid),
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
