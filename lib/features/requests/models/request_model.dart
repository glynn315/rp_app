import 'package:flutter/material.dart';

enum LeaveType { vacation, sick, emergency, unpaid, other }

enum RequestStatus { pending, approved, rejected }

extension LeaveTypeX on LeaveType {
  String get label => switch (this) {
        LeaveType.vacation => 'Vacation Leave',
        LeaveType.sick => 'Sick Leave',
        LeaveType.emergency => 'Emergency Leave',
        LeaveType.unpaid => 'Unpaid Leave',
        LeaveType.other => 'Other',
      };
}

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.approved => 'Approved',
        RequestStatus.rejected => 'Rejected',
      };
}

// Mixin so dashboard can mix-and-sort all request types by status/date
mixin Requestable {
  RequestStatus get status;
  DateTime get createdAt;
}

class LeaveRequest with Requestable {
  final String id;
  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String reason;
  @override
  final RequestStatus status;
  @override
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

class OtRequest with Requestable {
  final String id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double hours;
  final String reason;
  @override
  final RequestStatus status;
  @override
  final DateTime createdAt;

  const OtRequest({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

class TimeLog with Requestable {
  final String id;
  final DateTime date;
  final TimeOfDay timeIn;
  final TimeOfDay timeOut;
  final String? remarks;
  final String? imagePath;
  @override
  final RequestStatus status;
  @override
  final DateTime createdAt;

  const TimeLog({
    required this.id,
    required this.date,
    required this.timeIn,
    required this.timeOut,
    this.remarks,
    this.imagePath,
    required this.status,
    required this.createdAt,
  });
}
