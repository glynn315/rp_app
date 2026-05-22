import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/request_model.dart';

class RequestsState {
  final List<LeaveRequest> leaveRequests;
  final List<OtRequest> otRequests;
  final List<TimeLog> timeLogs;

  const RequestsState({
    required this.leaveRequests,
    required this.otRequests,
    required this.timeLogs,
  });

  RequestsState copyWith({
    List<LeaveRequest>? leaveRequests,
    List<OtRequest>? otRequests,
    List<TimeLog>? timeLogs,
  }) {
    return RequestsState(
      leaveRequests: leaveRequests ?? this.leaveRequests,
      otRequests: otRequests ?? this.otRequests,
      timeLogs: timeLogs ?? this.timeLogs,
    );
  }
}

class RequestsNotifier extends StateNotifier<RequestsState> {
  // Starts with empty lists. New requests come in via the add* methods;
  // server-side history will populate once the requests API is wired up.
  RequestsNotifier()
      : super(const RequestsState(
          leaveRequests: [],
          otRequests: [],
          timeLogs: [],
        ));

  void addLeaveRequest(LeaveRequest request) {
    state = state.copyWith(
      leaveRequests: [request, ...state.leaveRequests],
    );
  }

  void addOtRequest(OtRequest request) {
    state = state.copyWith(otRequests: [request, ...state.otRequests]);
  }

  void addTimeLog(TimeLog log) {
    state = state.copyWith(timeLogs: [log, ...state.timeLogs]);
  }
}

final requestsProvider = StateNotifierProvider<RequestsNotifier, RequestsState>(
  (ref) => RequestsNotifier(),
);
