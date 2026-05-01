import '../../../core/api/api_client.dart';

class EmployeeLookupResult {
  final String employeeId;
  final String contactNo;

  const EmployeeLookupResult({
    required this.employeeId,
    required this.contactNo,
  });
}

class EmployeeRegistrationApi {
  final ApiClient _api;

  EmployeeRegistrationApi({ApiClient? client})
      : _api = client ?? ApiClient();

  /// Returns null when no employee matches the given name.
  Future<EmployeeLookupResult?> lookup({
    required String firstname,
    required String lastname,
  }) async {
    try {
      final data = await _api.post('/employee/lookup', {
        'firstname': firstname,
        'lastname': lastname,
      });

      return EmployeeLookupResult(
        employeeId: data['employee_id']?.toString() ?? '',
        contactNo: data['contact_no']?.toString() ?? '',
      );
    } on ApiException catch (e) {
      // The lookup endpoint returns success=false (HTTP 200) when nothing
      // matches — we treat that as "no result" rather than an error.
      if (e.statusCode == null || e.statusCode == 200) {
        if (e.message.toLowerCase().contains('not found')) return null;
      }
      rethrow;
    }
  }

  /// Backend returns the OTP in the response — useful for dev/testing,
  /// the production SMS gateway sends the same code via SMS.
  Future<String> sendOtp(String employeeId) async {
    final data = await _api.post('/employee/send-otp', {
      'employee_id': employeeId,
    });
    return data['otp']?.toString() ?? '';
  }

  Future<bool> verifyOtp(String employeeId, String otp) async {
    final data = await _api.post('/employee/verify-otp', {
      'employee_id': employeeId,
      'otp': otp,
    });
    return data['success'] == true;
  }

  Future<bool> createPassword(String employeeId, String password) async {
    final data = await _api.post('/employee/create-password', {
      'employee_id': employeeId,
      'password': password,
    });
    return data['success'] == true;
  }
}
