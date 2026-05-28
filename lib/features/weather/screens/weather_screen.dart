import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_back_button.dart';
import '../models/weather_models.dart';
import '../providers/weather_provider.dart';

/// Current conditions + a 3-day forecast accordion (collapsed by default).
/// Tap a day to reveal its hourly detail. Mirrors the web mobile Weather
/// screen.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  static const int maxDays = 3;
  String? _open; // expanded day's date; null = all collapsed

  String _dayWeekday(String date) {
    final d = DateTime.tryParse('${date}T00:00:00');
    if (d == null) return date;
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];
    return names[d.weekday - 1];
  }

  String _dayRest(String date) {
    final d = DateTime.tryParse('${date}T00:00:00');
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  bool _isToday(String date) =>
      date == DateTime.now().toIso8601String().substring(0, 10);

  String _hourLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.length >= 16 ? iso.substring(11, 16) : iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weatherProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Weather'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load weather.'),
          ),
        ),
        data: (data) {
          final info = weatherInfo(data.current.code);
          final days = data.days.take(maxDays).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current conditions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(info.emoji,
                          style: const TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${data.current.temp.round()}°C',
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w600)),
                          Text(info.label,
                              style: theme.textTheme.bodyMedium),
                          if (data.locationName != null)
                            Text(data.locationName!,
                                style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 3-day accordion
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final day in days) _dayRow(day, theme),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Forecast by Open-Meteo · times in ${data.timezone}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dayRow(DayForecast day, ThemeData theme) {
    final expanded = _open == day.date;
    final midday = day.hours.firstWhere(
      (h) => h.time.length >= 13 && h.time.substring(11, 13) == '12',
      orElse: () => day.hours.isNotEmpty
          ? day.hours.first
          : const HourPoint(time: '', temp: 0, code: 0),
    );
    final info = weatherInfo(midday.code);

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _open = expanded ? null : day.date),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_dayWeekday(day.date),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (_isToday(day.date)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Today',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary)),
                            ),
                          ],
                        ],
                      ),
                      Text('${_dayRest(day.date)} · ${info.label}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${day.max}°',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${day.min}°', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            child: Column(
              children: [
                for (final h in day.hours) _hourRow(h, theme),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hourRow(HourPoint h, ThemeData theme) {
    final hi = weatherInfo(h.code);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 64,
              child: Text(_hourLabel(h.time),
                  style: theme.textTheme.bodySmall)),
          Text(hi.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(hi.label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          if (h.precipProb != null && h.precipProb! > 0)
            Text('💧${h.precipProb}%', style: theme.textTheme.bodySmall),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text('${h.temp.round()}°',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
