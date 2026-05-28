import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_models.dart';

/// Open-Meteo forecast (https://open-meteo.com) — free, no API key. Returns
/// up to 7 days of hourly data; the screen shows the first 3. Hits the public
/// API directly (not our backend ApiClient).
class WeatherApi {
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  final http.Client _client;
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherData> fetch(double latitude, double longitude) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'current': 'temperature_2m,weather_code',
      'forecast_days': '7',
      'timezone': 'auto',
    });

    final res = await _client.get(uri);
    if (res.statusCode >= 400) {
      throw Exception('Weather request failed (${res.statusCode}).');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;

    final hourly = (j['hourly'] as Map?) ?? const {};
    final times = ((hourly['time'] as List?) ?? const []).cast<String>();
    final temps = (hourly['temperature_2m'] as List?) ?? const [];
    final codes = (hourly['weather_code'] as List?) ?? const [];
    final precip = (hourly['precipitation_probability'] as List?) ?? const [];

    double toD(dynamic v) => v is num ? v.toDouble() : 0;
    int toI(dynamic v) => v is num ? v.toInt() : 0;

    // Group hourly points by calendar day (local "YYYY-MM-DDTHH:mm").
    final byDate = <String, List<HourPoint>>{};
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final date = t.length >= 10 ? t.substring(0, 10) : t;
      (byDate[date] ??= []).add(HourPoint(
        time: t,
        temp: i < temps.length ? toD(temps[i]) : 0,
        code: i < codes.length ? toI(codes[i]) : 0,
        precipProb: i < precip.length && precip[i] is num
            ? (precip[i] as num).toInt()
            : null,
      ));
    }

    final days = byDate.entries.map((e) {
      final dayTemps = e.value.map((h) => h.temp).toList();
      final mn = dayTemps.isEmpty
          ? 0
          : dayTemps.reduce((a, b) => a < b ? a : b).round();
      final mx = dayTemps.isEmpty
          ? 0
          : dayTemps.reduce((a, b) => a > b ? a : b).round();
      return DayForecast(date: e.key, min: mn, max: mx, hours: e.value);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final current = (j['current'] as Map?) ?? const {};
    return WeatherData(
      latitude: toD(j['latitude'] ?? latitude),
      longitude: toD(j['longitude'] ?? longitude),
      timezone: (j['timezone'] ?? 'auto').toString(),
      current: WeatherCurrent(
        temp: toD(current['temperature_2m'] ??
            (days.isNotEmpty && days.first.hours.isNotEmpty
                ? days.first.hours.first.temp
                : 0)),
        code: toI(current['weather_code'] ??
            (days.isNotEmpty && days.first.hours.isNotEmpty
                ? days.first.hours.first.code
                : 0)),
        time: (current['time'] ?? '').toString(),
      ),
      days: days.take(7).toList(),
    );
  }
}
