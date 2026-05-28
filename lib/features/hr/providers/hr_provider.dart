import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hr_api.dart';

/// Singleton API client for `/v1/hr/*` endpoints (Taps sync + Hangs).
final hrApiProvider = Provider<HrApi>((ref) => HrApi());
