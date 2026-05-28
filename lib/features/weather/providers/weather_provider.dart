import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weather_models.dart';
import '../services/weather_api.dart';

final weatherApiProvider = Provider<WeatherApi>((ref) => WeatherApi());

/// Manila fallback location (matches the web app). The Flutter build doesn't
/// pull device GPS to avoid a geolocation dependency + runtime permission.
const _fallback = (lat: 14.5995, lon: 120.9842, name: 'Manila (default)');

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  final api = ref.read(weatherApiProvider);
  final data = await api.fetch(_fallback.lat, _fallback.lon);
  return WeatherData(
    latitude: data.latitude,
    longitude: data.longitude,
    timezone: data.timezone,
    current: data.current,
    days: data.days,
    locationName: _fallback.name,
  );
});
