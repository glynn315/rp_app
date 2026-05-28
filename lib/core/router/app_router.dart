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
import '../../features/tasks/screens/daily_update_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
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
import '../../features/project_management/screens/mandays_auto_run_screen.dart';
import '../../features/project_management/screens/mandays_matching_screen.dart';
import '../../features/project_management/screens/mandays_pending_screen.dart';
import '../../features/project_management/screens/mandays_reports_screen.dart';
import '../../features/project_management/screens/mandays_runs_screen.dart';
import '../../features/project_management/screens/mandays_unacctd_ack_screen.dart';
import '../../features/project_management/screens/work_in_progress_screen.dart';
import '../../features/consumption/screens/consumption_erp_verify_screen.dart';
import '../../features/consumption/screens/consumption_projects_screen.dart';
import '../../features/consumption/screens/consumption_session_screen.dart';
import '../../features/consumption/screens/consumption_sessions_screen.dart';
import '../../features/weather/screens/weather_screen.dart';
import '../../features/work/screens/work_hub_screen.dart';
import '../../features/hr/screens/hangs_screen.dart';
import '../../features/hr/screens/taps_sync_screen.dart';
import '../../features/ipr/screens/ipr_list_screen.dart';
import '../../features/ipr/screens/ipr_detail_screen.dart';
import '../../features/ipr/screens/ipr_generate_screen.dart';
import '../../features/ipr/screens/ipr_monitoring_screen.dart';

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
      // Daily update form — `?task=<id>` preselects a task. Declared before
      // `/tasks/:id` so go_router prefers the literal "daily" segment.
      GoRoute(
        path: '/tasks/daily',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final taskId = state.uri.queryParameters['task'];
          return DailyUpdateScreen(initialTaskId: taskId);
        },
      ),
      GoRoute(
        path: '/tasks/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TaskDetailScreen(taskId: id);
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
        path: '/projects/mandays-matching/pending',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MandaysPendingScreen(),
      ),
      GoRoute(
        path: '/projects/mandays-matching/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MandaysReportsScreen(),
      ),
      GoRoute(
        path: '/projects/mandays-matching/auto',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MandaysAutoRunScreen(),
      ),
      GoRoute(
        path: '/projects/mandays-matching/runs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MandaysRunsScreen(),
      ),
      GoRoute(
        // Signature-capture for an unaccounted-salary acknowledgement.
        // The line/employee/amount/name come through `state.extra` as a
        // Map<String, dynamic> so the caller doesn't have to URL-encode them.
        path: '/projects/mandays-matching/unaccounted-ack',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = (state.extra as Map?)?.cast<String, dynamic>() ?? const {};
          return MandaysUnacctdAckScreen(
            unaccountedLineId: (extra['unaccounted_line_id'] as num?)?.toInt() ?? 0,
            bparPersonId: (extra['bpar_i_person_id'] as num?)?.toInt(),
            sBpartnerEmployeeId:
                (extra['s_bpartner_employee_id'] as num?)?.toInt(),
            amtUnaccountedSalary:
                (extra['amt_unaccounted_salary'] as num?)?.toDouble() ?? 0.0,
            employeeName: (extra['employee_name'] as String?) ?? '',
          );
        },
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
        // Static `/consumption/sessions` must be declared BEFORE
        // `/consumption/sessions/:id` so go_router prefers the literal match.
        path: '/consumption/sessions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConsumptionSessionsScreen(),
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
        path: '/consumption/sessions/:id/erp-verify',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid session id')),
            );
          }
          return ConsumptionErpVerifyScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/log-progress',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LogProgressWizardScreen(),
      ),
      GoRoute(
        path: '/weather',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WeatherScreen(),
      ),
      // HR — Time & attendance group.
      GoRoute(
        path: '/hr/taps-sync',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TapsSyncScreen(),
      ),
      GoRoute(
        path: '/hr/hangs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HangsScreen(),
      ),
      GoRoute(
        path: '/work',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WorkHubScreen(),
      ),
      // IPR — static paths declared before the :id param route so go_router
      // matches /ipr/generate and /ipr/monitoring before /ipr/:id.
      GoRoute(
        path: '/ipr',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IprListScreen(),
      ),
      GoRoute(
        path: '/ipr/generate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IprGenerateScreen(),
      ),
      GoRoute(
        path: '/ipr/monitoring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IprMonitoringScreen(),
      ),
      GoRoute(
        path: '/ipr/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid IPR id')),
            );
          }
          return IprDetailScreen(iprId: id);
        },
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
