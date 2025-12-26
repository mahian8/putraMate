import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/appointment.dart';
import '../../services/firestore_service.dart';
import '../common/common_widgets.dart';

class CounsellorDetailPage extends StatefulWidget {
  const CounsellorDetailPage({super.key, required this.counsellor});

  final UserProfile counsellor;

  @override
  State<CounsellorDetailPage> createState() => _CounsellorDetailPageState();
}

class _CounsellorDetailPageState extends State<CounsellorDetailPage> {
  late Future<List<Appointment>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    final fs = FirestoreService();
    // Fetch completed appointments with reviews for this counsellor
    _reviewsFuture = fs
        .appointmentsForCounsellor(widget.counsellor.uid)
        .first
        .then((appointments) => appointments
            .where((a) =>
                a.status == AppointmentStatus.completed &&
                a.studentRating != null &&
                a.isReviewApproved == true) // Only approved reviews
            .toList());
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
                      if (widget.counsellor.expertise != null) ...[
                        Chip(label: Text('Expertise: ${widget.counsellor.expertise}')),
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
                        child: Text('No approved reviews yet'),
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
                              // Rating
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      size: 18,
                                      color: i < (review.studentRating?.toInt() ?? 0)
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${review.studentRating?.toStringAsFixed(1) ?? "N/A"}/5',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Comment
                              if (review.studentComment != null &&
                                  review.studentComment!.isNotEmpty)
                                Text(
                                  review.studentComment!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
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
