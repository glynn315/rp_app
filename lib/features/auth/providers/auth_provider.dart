import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUser {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String position;
  final String department;
  final double leaveBalance;

  const AppUser({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.position,
    required this.department,
    required this.leaveBalance,
  });
}

class AuthState {
  final bool isAuthenticated;
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    AppUser? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // Mock credentials — replace with real API call
  static const _mockUsers = [
    {
      'employeeId': 'EMP001',
      'password': 'password123',
      'name': 'Juan dela Cruz',
      'email': 'juan@chiukim.com',
      'position': 'Operations Manager',
      'department': 'Operations',
      'leaveBalance': 12.0,
    },
    {
      'employeeId': 'EMP002',
      'password': 'password123',
      'name': 'Maria Santos',
      'email': 'maria@chiukim.com',
      'position': 'HR Specialist',
      'department': 'Human Resources',
      'leaveBalance': 10.0,
    },
  ];

  Future<void> login(String employeeId, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(milliseconds: 800));

    final match = _mockUsers.where(
      (u) =>
          u['employeeId'] == employeeId.trim().toUpperCase() &&
          u['password'] == password,
    );

    if (match.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Invalid Employee ID or password.',
      );
      return;
    }

    final userData = match.first;
    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      user: AppUser(
        id: userData['employeeId']! as String,
        employeeId: userData['employeeId']! as String,
        name: userData['name']! as String,
        email: userData['email']! as String,
        position: userData['position']! as String,
        department: userData['department']! as String,
        leaveBalance: userData['leaveBalance']! as double,
      ),
    );
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
