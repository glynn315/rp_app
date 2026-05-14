import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/add_task_screen.dart';
import '../../features/requests/screens/requests_screen.dart';
import '../../features/requests/screens/leave_request_screen.dart';
import '../../features/requests/screens/ot_request_screen.dart';
import '../../features/requests/screens/time_log_screen.dart';
import '../../features/performance/screens/performance_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/daily_work_report/screens/detect_screen.dart';
import '../../features/daily_work_report/screens/daily_work_report_screen.dart';
import '../../features/daily_work_report/screens/log_progress_wizard_screen.dart';
import '../../features/daily_work_report/screens/lookups_admin_screen.dart';
import '../../features/project_management/models/project_management_models.dart';
import '../../features/project_management/screens/bill_of_quantities_screen.dart';
import '../../features/project_management/screens/boq_entries_screen.dart';
import '../../features/project_management/screens/boq_log_time_screen.dart';
import '../../features/project_management/screens/boq_photos_screen.dart';
import '../../features/project_management/screens/boq_tasks_screen.dart';
import '../../features/project_management/screens/lmc_payout_screen.dart';
import '../../features/project_management/screens/mandays_matching_screen.dart';
import '../../features/project_management/screens/work_in_progress_screen.dart';
import '../../features/consumption/screens/consumption_projects_screen.dart';
import '../../features/consumption/screens/consumption_session_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthenticated = authState.isAuthenticated;

      if (loc == '/splash') return null;
      const publicRoutes = ['/login', '/register'];
      if (!isAuthenticated && !publicRoutes.contains(loc)) return '/login';
      if (isAuthenticated && publicRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const RequestsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/performance',
              builder: (context, state) => const PerformanceScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      // Full-screen routes (no bottom nav)
      GoRoute(
        path: '/tasks/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final taskId = state.extra as String?;
          return AddTaskScreen(editTaskId: taskId);
        },
      ),
      GoRoute(
        path: '/requests/leave',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LeaveRequestScreen(),
      ),
      GoRoute(
        path: '/requests/ot',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OtRequestScreen(),
      ),
      GoRoute(
        path: '/requests/timelog',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TimeLogScreen(),
      ),
      GoRoute(
        path: '/projects/boq',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BillOfQuantitiesScreen(),
      ),
      GoRoute(
        path: '/projects/boq/tasks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final item = state.extra is BoqItem ? state.extra as BoqItem : null;
          return BoqTasksScreen(item: item);
        },
      ),
      GoRoute(
        path: '/projects/boq/log-time',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final item = state.extra is BoqItem ? state.extra as BoqItem : null;
          return BoqLogTimeScreen(item: item);
        },
      ),
      GoRoute(
        path: '/projects/boq/photos',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final item = state.extra is BoqItem ? state.extra as BoqItem : null;
          return BoqPhotosScreen(item: item);
        },
      ),
      GoRoute(
        path: '/projects/boq/entries',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final item = state.extra is BoqItem ? state.extra as BoqItem : null;
          return BoqEntriesScreen(item: item);
        },
      ),
      GoRoute(
        path: '/projects/wip',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WorkInProgressScreen(),
      ),
      GoRoute(
        path: '/projects/lmc-payout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LmcPayoutScreen(),
      ),
      GoRoute(
        path: '/projects/mandays-matching',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MandaysMatchingScreen(),
      ),
      GoRoute(
        path: '/consumption',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConsumptionProjectsScreen(),
      ),
      GoRoute(
        path: '/consumption/load/:projectId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['projectId'] ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid project id')),
            );
          }
          return ConsumptionSessionScreen(projectId: id);
        },
      ),
      GoRoute(
        path: '/consumption/sessions/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid session id')),
            );
          }
          return ConsumptionSessionScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/log-progress',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LogProgressWizardScreen(),
      ),
      GoRoute(
        path: '/work-report',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DetectScreen(),
        routes: [
          GoRoute(
            path: 'today',
            builder: (context, state) =>
                const DailyWorkReportScreen(initialTab: 'today'),
          ),
          GoRoute(
            path: 'calendar',
            builder: (context, state) =>
                const DailyWorkReportScreen(initialTab: 'calendar'),
          ),
          GoRoute(
            path: 'unmatched',
            builder: (context, state) =>
                const DailyWorkReportScreen(initialTab: 'unmatched'),
          ),
          GoRoute(
            path: 'admin/lookups',
            builder: (context, state) => const LookupsAdminScreen(),
          ),
        ],
      ),
    ],
  );
});
