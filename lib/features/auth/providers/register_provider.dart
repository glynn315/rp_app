import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../services/employee_registration_api.dart';

class EmployeeRecord {
  final String employeeId;
  final String firstName;
  final String lastName;
  final String contactNumber;

  const EmployeeRecord({
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.contactNumber,
  });

  String get fullName => '$firstName $lastName';

  String get suggestedUsername {
    final f = firstName.trim().isEmpty
        ? ''
        : firstName.trim()[0].toLowerCase();
    final l = lastName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '$f$l';
  }

  String get maskedContactNumber {
    final digits = contactNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return contactNumber;
    final last4 = digits.substring(digits.length - 4);
    final hidden = '•' * (digits.length - 4);
    return '$hidden$last4';
  }
}

enum RegisterStep { search, verifyInfo, otp, password, done }

class RegisterState {
  final RegisterStep step;
  final EmployeeRecord? matchedEmployee;
  final EmployeeRecord? selectedEmployee;
  final String? lastSearchedFirst;
  final String? lastSearchedLast;
  final String? lastNotFoundQuery;
  final String? generatedOtp;
  final DateTime? otpSentAt;
  final bool isLoading;
  final String? error;

  const RegisterState({
    this.step = RegisterStep.search,
    this.matchedEmployee,
    this.selectedEmployee,
    this.lastSearchedFirst,
    this.lastSearchedLast,
    this.lastNotFoundQuery,
    this.generatedOtp,
    this.otpSentAt,
    this.isLoading = false,
    this.error,
  });

  RegisterState copyWith({
    RegisterStep? step,
    EmployeeRecord? matchedEmployee,
    EmployeeRecord? selectedEmployee,
    String? lastSearchedFirst,
    String? lastSearchedLast,
    String? lastNotFoundQuery,
    String? generatedOtp,
    DateTime? otpSentAt,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearMatched = false,
    bool clearNotFound = false,
  }) {
    return RegisterState(
      step: step ?? this.step,
      matchedEmployee:
          clearMatched ? null : (matchedEmployee ?? this.matchedEmployee),
      selectedEmployee: selectedEmployee ?? this.selectedEmployee,
      lastSearchedFirst: lastSearchedFirst ?? this.lastSearchedFirst,
      lastSearchedLast: lastSearchedLast ?? this.lastSearchedLast,
      lastNotFoundQuery:
          clearNotFound ? null : (lastNotFoundQuery ?? this.lastNotFoundQuery),
      generatedOtp: generatedOtp ?? this.generatedOtp,
      otpSentAt: otpSentAt ?? this.otpSentAt,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RegisterNotifier extends StateNotifier<RegisterState> {
  RegisterNotifier(this._api) : super(const RegisterState());

  final EmployeeRegistrationApi _api;

  static const Duration otpResendCooldown = Duration(minutes: 5);

  Future<void> searchEmployee({
    required String firstname,
    required String lastname,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearMatched: true,
      clearNotFound: true,
      lastSearchedFirst: firstname,
      lastSearchedLast: lastname,
    );

    try {
      final result = await _api.lookup(
        firstname: firstname,
        lastname: lastname,
      );
      if (result == null) {
        state = state.copyWith(
          isLoading: false,
          lastNotFoundQuery: '$firstname $lastname',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        matchedEmployee: EmployeeRecord(
          employeeId: result.employeeId,
          firstName: firstname,
          lastName: lastname,
          contactNumber: result.contactNo,
        ),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectEmployee(EmployeeRecord employee) {
    state = state.copyWith(
      selectedEmployee: employee,
      step: RegisterStep.verifyInfo,
      clearError: true,
    );
  }

  void goToStep(RegisterStep step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void reset() {
    state = const RegisterState();
  }

  Duration remainingResendCooldown() {
    final sentAt = state.otpSentAt;
    if (sentAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(sentAt);
    final remaining = otpResendCooldown - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canResendOtp => remainingResendCooldown() == Duration.zero;

  Future<String?> sendOtp({bool advanceStep = false}) async {
    final emp = state.selectedEmployee;
    if (emp == null) return null;
    if (state.isLoading) return null;
    if (!canResendOtp) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final code = await _api.sendOtp(emp.employeeId);
      state = state.copyWith(
        isLoading: false,
        generatedOtp: code,
        otpSentAt: DateTime.now(),
        step: advanceStep ? RegisterStep.otp : state.step,
      );
      return code;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> verifyOtp(String code) async {
    final emp = state.selectedEmployee;
    if (emp == null) return false;
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await _api.verifyOtp(emp.employeeId, code.trim());
      if (!ok) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid OTP. Please try again.',
        );
        return false;
      }
      state = state.copyWith(isLoading: false, step: RegisterStep.password);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> completeRegistration({
    required String password,
    required String confirmPassword,
  }) async {
    final emp = state.selectedEmployee;
    if (emp == null) return false;

    if (password.length < 6) {
      state = state.copyWith(error: 'Password must be at least 6 characters.');
      return false;
    }
    if (password != confirmPassword) {
      state = state.copyWith(error: 'Passwords do not match.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ok = await _api.createPassword(emp.employeeId, password);
      if (!ok) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not create password. Please try again.',
        );
        return false;
      }
      state = state.copyWith(isLoading: false, step: RegisterStep.done);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final employeeRegistrationApiProvider = Provider<EmployeeRegistrationApi>(
  (ref) => EmployeeRegistrationApi(),
);

final registerProvider =
    StateNotifierProvider.autoDispose<RegisterNotifier, RegisterState>(
  (ref) => RegisterNotifier(ref.read(employeeRegistrationApiProvider)),
);
