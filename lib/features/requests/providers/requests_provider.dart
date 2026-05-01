import 'package:flutter/material.dart';
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
  RequestsNotifier()
      : super(const RequestsState(
          leaveRequests: [],
          otRequests: [],
          timeLogs: [],
        )) {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    state = state.copyWith(
      leaveRequests: [
        LeaveRequest(
          id: 'LR001',
          type: LeaveType.vacation,
          fromDate: now.add(const Duration(days: 7)),
          toDate: now.add(const Duration(days: 9)),
          days: 3,
          reason: 'Family vacation trip.',
          status: RequestStatus.pending,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        LeaveRequest(
          id: 'LR002',
          type: LeaveType.sick,
          fromDate: now.subtract(const Duration(days: 14)),
          toDate: now.subtract(const Duration(days: 13)),
          days: 2,
          reason: 'Fever and flu symptoms.',
          status: RequestStatus.approved,
          createdAt: now.subtract(const Duration(days: 14)),
        ),
      ],
      otRequests: [
        OtRequest(
          id: 'OT001',
          date: now.subtract(const Duration(days: 3)),
          startTime: const TimeOfDay(hour: 18, minute: 0),
          endTime: const TimeOfDay(hour: 21, minute: 0),
          hours: 3.0,
          reason: 'End-of-month report submission.',
          status: RequestStatus.pending,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ],
      timeLogs: [
        TimeLog(
          id: 'TL001',
          date: now.subtract(const Duration(days: 2)),
          timeIn: const TimeOfDay(hour: 8, minute: 5),
          timeOut: const TimeOfDay(hour: 17, minute: 10),
          remarks: 'Biometric malfunction — manual log required.',
          status: RequestStatus.approved,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    );
  }

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
