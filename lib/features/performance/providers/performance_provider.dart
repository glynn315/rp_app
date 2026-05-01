import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/performance_model.dart';

class PerformanceState {
  final List<PerformancePeriod> periods;
  final bool isLoading;

  const PerformanceState({required this.periods, this.isLoading = false});
}

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  PerformanceNotifier() : super(const PerformanceState(periods: [])) {
    _loadMockData();
  }

  void _loadMockData() {
    state = PerformanceState(periods: [
      PerformancePeriod(
        id: 'PR001',
        period: 'Q1 2026 (Jan – Mar)',
        evaluatorName: 'Ricardo Santos',
        evaluationDate: DateTime(2026, 4, 5),
        overallRating: 4.2,
        maxRating: 5.0,
        comments:
            'Consistently delivers quality work. Demonstrated strong leadership during the Q1 project rollout. Continue to work on documentation standards.',
        kpiRatings: const [
          KpiRating(name: 'Task Completion Rate', weight: 25, target: 100, actual: 95, rating: 4.5),
          KpiRating(name: 'Attendance & Punctuality', weight: 20, target: 100, actual: 98, rating: 4.8),
          KpiRating(name: 'Quality of Work', weight: 25, target: 100, actual: 85, rating: 4.0),
          KpiRating(name: 'Teamwork & Collaboration', weight: 15, target: 100, actual: 90, rating: 4.0),
          KpiRating(name: 'Initiative & Innovation', weight: 15, target: 100, actual: 75, rating: 3.5),
        ],
      ),
      PerformancePeriod(
        id: 'PR002',
        period: 'Q4 2025 (Oct – Dec)',
        evaluatorName: 'Ricardo Santos',
        evaluationDate: DateTime(2026, 1, 8),
        overallRating: 3.9,
        maxRating: 5.0,
        comments:
            'Good performance overall. Some delays observed in the October reporting cycle. Improved significantly by December.',
        kpiRatings: const [
          KpiRating(name: 'Task Completion Rate', weight: 25, target: 100, actual: 88, rating: 4.0),
          KpiRating(name: 'Attendance & Punctuality', weight: 20, target: 100, actual: 92, rating: 4.2),
          KpiRating(name: 'Quality of Work', weight: 25, target: 100, actual: 80, rating: 3.8),
          KpiRating(name: 'Teamwork & Collaboration', weight: 15, target: 100, actual: 85, rating: 3.8),
          KpiRating(name: 'Initiative & Innovation', weight: 15, target: 100, actual: 70, rating: 3.5),
        ],
      ),
      PerformancePeriod(
        id: 'PR003',
        period: 'Q3 2025 (Jul – Sep)',
        evaluatorName: 'Ricardo Santos',
        evaluationDate: DateTime(2025, 10, 6),
        overallRating: 4.0,
        maxRating: 5.0,
        kpiRatings: const [
          KpiRating(name: 'Task Completion Rate', weight: 25, target: 100, actual: 90, rating: 4.0),
          KpiRating(name: 'Attendance & Punctuality', weight: 20, target: 100, actual: 95, rating: 4.5),
          KpiRating(name: 'Quality of Work', weight: 25, target: 100, actual: 82, rating: 3.8),
          KpiRating(name: 'Teamwork & Collaboration', weight: 15, target: 100, actual: 88, rating: 4.0),
          KpiRating(name: 'Initiative & Innovation', weight: 15, target: 100, actual: 78, rating: 3.8),
        ],
      ),
    ]);
  }
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>(
  (ref) => PerformanceNotifier(),
);
