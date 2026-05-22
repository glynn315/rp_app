import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/performance_model.dart';

class PerformanceState {
  final List<PerformancePeriod> periods;
  final bool isLoading;

  const PerformanceState({required this.periods, this.isLoading = false});
}

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  // Starts with no periods. The PerformanceScreen already shows
  // "No performance data available." when the list is empty.
  PerformanceNotifier() : super(const PerformanceState(periods: []));
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>(
  (ref) => PerformanceNotifier(),
);
