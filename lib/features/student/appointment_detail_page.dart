import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class AppointmentDetailPage extends StatelessWidget {
  const AppointmentDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Appointment details',
      body: const SectionCard(
        title: 'Session with counsellor',
        child: Text('Details, notes, and join link will appear here.'),
      ),
    );
  }
}
