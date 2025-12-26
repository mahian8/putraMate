import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/admin/admin_dashboard_page.dart';
import '../features/admin/community_moderation_page.dart';
import '../features/admin/logs_page.dart';
import '../features/admin/manage_counsellors_page.dart';
import '../features/admin/manage_users_page.dart';
import '../features/admin/resolve_conflicts_page.dart';
import '../features/admin/verify_availability_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/counsellor/assigned_students_page.dart';
import '../features/counsellor/availability_editor_page.dart';
import '../features/counsellor/counsellor_appointments_page.dart';
import '../features/counsellor/counsellor_dashboard_page.dart';
import '../features/counsellor/session_notes_page.dart';
import '../features/counsellor/student_insights_page.dart';
import '../features/shared/profile_page.dart';
import '../features/shared/splash_page.dart';
import '../features/student/appointment_detail_page.dart';
import '../features/student/booking_calendar_page.dart';
import '../features/student/chatbot_page.dart';
import '../features/student/community_forum_page.dart';
import '../features/student/counsellor_catalog_page.dart';
import '../features/student/journal_page.dart';
import '../features/student/mood_chart_page.dart';
import '../features/student/my_appointments_page.dart';
import '../features/student/student_dashboard_page.dart';
import '../features/student/notifications_page.dart';
import '../models/user_profile.dart';
import '../providers/auth_providers.dart';

enum AppRoute {
  splash,
  login,
  register,
  forgotPassword,
  dashboard,
  studentDashboard,
  profile,
  studentJournal,
  studentMood,
  chatbot,
  counsellorCatalog,
  booking,
  appointments,
  appointmentDetail,
  forum,
  notifications,
  counsellorDashboard,
  assignedStudents,
  studentInsights,
  availability,
  counsellorAppointments,
  sessionNotes,
  adminDashboard,
  manageCounsellors,
  verifyAvailability,
  resolveConflicts,
  manageUsers,
  communityModeration,
  logs,
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final role = ref.watch(currentRoleProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges()),
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot';
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return isLoggingIn ? null : '/login';
      }
      if (isLoggingIn) return _dashboardPath(role);
      if (state.matchedLocation == '/' || state.matchedLocation == '/dashboard') {
        return _dashboardPath(role);
      }

      final path = state.matchedLocation;
      if (role == UserRole.student && (path.startsWith('/counsellor') || path.startsWith('/admin'))) {
        return _dashboardPath(role);
      }
      if (role == UserRole.counsellor && path.startsWith('/admin')) {
        return _dashboardPath(role);
      }
      return null;
    },
    routes: [
      GoRoute(
        name: AppRoute.splash.name,
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        name: AppRoute.login.name,
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        name: AppRoute.register.name,
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        name: AppRoute.forgotPassword.name,
        path: '/forgot',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        name: AppRoute.profile.name,
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        name: AppRoute.dashboard.name,
        path: '/dashboard',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        name: AppRoute.studentDashboard.name,
        path: '/student/dashboard',
        builder: (context, state) => const StudentDashboardPage(),
      ),
      GoRoute(
        name: AppRoute.studentJournal.name,
        path: '/student/journal',
        builder: (context, state) => const JournalPage(),
      ),
      GoRoute(
        name: AppRoute.studentMood.name,
        path: '/student/mood',
        builder: (context, state) => const MoodChartPage(),
      ),
      GoRoute(
        name: AppRoute.chatbot.name,
        path: '/student/chatbot',
        builder: (context, state) => const ChatbotPage(),
      ),
      GoRoute(
        name: AppRoute.counsellorCatalog.name,
        path: '/student/counsellors',
        builder: (context, state) => const CounsellorCatalogPage(),
      ),
      GoRoute(
        name: AppRoute.booking.name,
        path: '/student/booking',
        builder: (context, state) => BookingCalendarPage(
          counsellorId: state.uri.queryParameters['cid'],
          counsellorName: state.uri.queryParameters['cname'],
        ),
      ),
      GoRoute(
        name: AppRoute.appointments.name,
        path: '/student/appointments',
        builder: (context, state) => const MyAppointmentsPage(),
      ),
      GoRoute(
        name: AppRoute.appointmentDetail.name,
        path: '/student/appointment/:id',
        builder: (context, state) => const AppointmentDetailPage(),
      ),
      GoRoute(
        name: AppRoute.forum.name,
        path: '/student/forum',
        builder: (context, state) => const CommunityForumPage(),
      ),
      GoRoute(
        name: AppRoute.notifications.name,
        path: '/student/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        name: AppRoute.counsellorDashboard.name,
        path: '/counsellor/dashboard',
        builder: (context, state) => const CounsellorDashboardPage(),
      ),
      GoRoute(
        name: AppRoute.assignedStudents.name,
        path: '/counsellor/assigned',
        builder: (context, state) => const AssignedStudentsPage(),
      ),
      GoRoute(
        name: AppRoute.studentInsights.name,
        path: '/counsellor/insights',
        builder: (context, state) => const StudentInsightsPage(),
      ),
      GoRoute(
        name: AppRoute.availability.name,
        path: '/counsellor/availability',
        builder: (context, state) => const AvailabilityEditorPage(),
      ),
      GoRoute(
        name: AppRoute.counsellorAppointments.name,
        path: '/counsellor/appointments',
        builder: (context, state) => const CounsellorAppointmentsPage(),
      ),
      GoRoute(
        name: AppRoute.sessionNotes.name,
        path: '/counsellor/notes',
        builder: (context, state) => const SessionNotesPage(),
      ),
      GoRoute(
        name: AppRoute.adminDashboard.name,
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        name: AppRoute.manageCounsellors.name,
        path: '/admin/counsellors',
        builder: (context, state) => const ManageCounsellorsPage(),
      ),
      GoRoute(
        name: AppRoute.verifyAvailability.name,
        path: '/admin/verify',
        builder: (context, state) => const VerifyAvailabilityPage(),
      ),
      GoRoute(
        name: AppRoute.resolveConflicts.name,
        path: '/admin/conflicts',
        builder: (context, state) => const ResolveConflictsPage(),
      ),
      GoRoute(
        name: AppRoute.manageUsers.name,
        path: '/admin/users',
        builder: (context, state) => const ManageUsersPage(),
      ),
      GoRoute(
        name: AppRoute.communityModeration.name,
        path: '/admin/moderation',
        builder: (context, state) => const CommunityModerationPage(),
      ),
      GoRoute(
        name: AppRoute.logs.name,
        path: '/admin/logs',
        builder: (context, state) => const LogsPage(),
      ),
    ],
  );
});

String _dashboardPath(UserRole? role) {
  switch (role) {
    case UserRole.counsellor:
      return '/counsellor/dashboard';
    case UserRole.admin:
      return '/admin/dashboard';
    case UserRole.student:
    default:
      return '/student/dashboard';
  }
}

// Minimal wrapper to let GoRouter refresh when auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
