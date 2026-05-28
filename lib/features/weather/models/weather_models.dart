// Weather types backed by the Open-Meteo forecast API (no API key required).
// Ported from rpv-frontend-web/domains/mobile/weather.

class HourPoint {
  final String time; // ISO local time, e.g. "2026-05-28T14:00"
  final double temp; // °C
  final int code; // WMO weather code
  final int? precipProb; // % chance of precipitation

  const HourPoint({
    required this.time,
    required this.temp,
    required this.code,
    this.precipProb,
  });
}

class DayForecast {
  final String date; // YYYY-MM-DD
  final int min;
  final int max;
  final List<HourPoint> hours;

  const DayForecast({
    required this.date,
    required this.min,
    required this.max,
    required this.hours,
  });
}

class WeatherCurrent {
  final double temp;
  final int code;
  final String time;
  const WeatherCurrent({required this.temp, required this.code, required this.time});
}

class WeatherData {
  final double latitude;
  final double longitude;
  final String timezone;
  final WeatherCurrent current;
  final List<DayForecast> days;
  final String? locationName;

  const WeatherData({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.current,
    required this.days,
    this.locationName,
  });
}

/// A short label + emoji for a WMO weather code.
class WeatherInfo {
  final String label;
  final String emoji;
  const WeatherInfo(this.label, this.emoji);
}

WeatherInfo weatherInfo(int code) {
  if (code == 0) return const WeatherInfo('Clear sky', '☀️');
  if (code == 1) return const WeatherInfo('Mainly clear', '🌤️');
  if (code == 2) return const WeatherInfo('Partly cloudy', '⛅');
  if (code == 3) return const WeatherInfo('Overcast', '☁️');
  if (code == 45 || code == 48) return const WeatherInfo('Fog', '🌫️');
  if (code >= 51 && code <= 57) return const WeatherInfo('Drizzle', '🌦️');
  if (code >= 61 && code <= 67) return const WeatherInfo('Rain', '🌧️');
  if (code >= 71 && code <= 77) return const WeatherInfo('Snow', '🌨️');
  if (code >= 80 && code <= 82) return const WeatherInfo('Rain showers', '🌦️');
  if (code == 85 || code == 86) return const WeatherInfo('Snow showers', '🌨️');
  if (code == 95) return const WeatherInfo('Thunderstorm', '⛈️');
  if (code == 96 || code == 99) return const WeatherInfo('Thunderstorm + hail', '⛈️');
  return const WeatherInfo('Unknown', '🌡️');
}
