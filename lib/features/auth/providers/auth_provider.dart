import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../services/auth_api.dart';

class AppUser {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String position;
  final String department;
  final double leaveBalance;
  final String? username;
  final String? contactNo;
  final String? imageLocation;

  const AppUser({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.position,
    required this.department,
    required this.leaveBalance,
    this.username,
    this.contactNo,
    this.imageLocation,
  });

  factory AppUser.fromApi(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    final first = s(json['firstname']);
    final last = s(json['lastname']);
    final fullName =
        [first, last].where((p) => p.isNotEmpty).join(' ').trim();
    final id = s(json['s_bpartner_employee_id']).isNotEmpty
        ? s(json['s_bpartner_employee_id'])
        : s(json['id']);
    final employeeNo = s(json['employee_no']);

    double parseLeave(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return AppUser(
      id: id,
      employeeId: employeeNo.isNotEmpty ? employeeNo : id,
      name: fullName.isEmpty ? s(json['username']) : fullName,
      email: s(json['email']),
      position: s(json['position']),
      department: s(json['companyname']),
      leaveBalance: parseLeave(json['remaining_leave']),
      username: s(json['username']).isEmpty ? null : s(json['username']),
      contactNo: s(json['contact_no']).isEmpty ? null : s(json['contact_no']),
      imageLocation: s(json['image_location']).isEmpty
          ? null
          : s(json['image_location']),
    );
  }
}

class AuthState {
  final bool isAuthenticated;
  final AppUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    AppUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._storage) : super(const AuthState());

  final AuthApi _api;
  final TokenStorage _storage;

  /// Loads any persisted token/user — called on app start so the user stays
  /// signed in across restarts. Does not validate the token against the
  /// backend; expired tokens will surface the next time an API call is made.
  Future<void> restoreSession() async {
    final saved = await _storage.read();
    if (saved == null) return;
    state = state.copyWith(
      isAuthenticated: true,
      token: saved.token,
      user: AppUser.fromApi(saved.user),
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.login(
        username: username.trim(),
        password: password,
      );
      await _storage.save(token: result.token, user: result.user);
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        token: result.token,
        user: AppUser.fromApi(result.user),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    final token = state.token;
    state = const AuthState();
    await _storage.clear();
    if (token != null) {
      // Best-effort revocation; we don't block UI on this.
      unawaited(_api.logout(token));
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(authApiProvider),
    ref.read(tokenStorageProvider),
  ),
);
