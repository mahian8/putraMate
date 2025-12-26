import 'package:flutter/material.dart';
import '../common/common_widgets.dart';

class StudentInsightsPage extends StatelessWidget {
  const StudentInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Student insights',
      body: ListView(
        children: const [
          SectionCard(title: 'Mood trend', child: Text('Mood average: 6.4')), 
          SectionCard(title: 'Journal summary', child: Text('Key themes will appear here.')),
        ],
      ),
    );
  }
}
