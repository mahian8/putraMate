import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class CounsellorAppointmentsPage extends StatelessWidget {
  const CounsellorAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Appointments',
      body: ListView(
        children: const [
          SectionCard(title: 'No sessions scheduled', child: Text('Add availability so students can book you.')),
        ],
      ),
    );
  }
}
