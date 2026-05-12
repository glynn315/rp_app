import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../home/home_screen.dart';
import '../models/performance_model.dart';
import '../providers/performance_provider.dart';

class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);

    if (state.periods.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        appBar: _AppBar(),
        body: Center(child: Text('No performance data available.')),
      );
    }

    final latest = state.periods.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const _AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          // Current period hero card
          _CurrentPeriodCard(period: latest),
          const SizedBox(height: AppDimensions.md),

          // KPI breakdown
          _KpiBreakdown(period: latest),
          const SizedBox(height: AppDimensions.md),

          // Evaluator comments
          if (latest.comments != null) ...[
            _CommentsCard(comments: latest.comments!),
            const SizedBox(height: AppDimensions.md),
          ],

          // History
          if (state.periods.length > 1) ...[
            const _SectionLabel(text: 'HISTORY'),
            const SizedBox(height: AppDimensions.sm),
            ...state.periods
                .skip(1)
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                      child: _HistoryCard(period: p),
                    )),
          ],
          const SizedBox(height: AppDimensions.xl),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Open menu',
        onPressed: HomeScreen.openDrawer,
      ),
      title: const Text('Performance'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CurrentPeriodCard extends StatelessWidget {
  final PerformancePeriod period;

  const _CurrentPeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT PERIOD',
                      style: TextStyle(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.period,
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Evaluated by ${period.evaluatorName}',
                      style: TextStyle(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _RatingGauge(
                rating: period.overallRating,
                maxRating: period.maxRating,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  period.ratingLabel,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingGauge extends StatelessWidget {
  final double rating;
  final double maxRating;

  const _RatingGauge({required this.rating, required this.maxRating});

  @override
  Widget build(BuildContext context) {
    final percentage = rating / maxRating;

    return SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _GaugePainter(percentage: percentage),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '/ $maxRating',
                style: TextStyle(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;

  const _GaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * percentage,
      false,
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.percentage != percentage;
}

class _KpiBreakdown extends StatelessWidget {
  final PerformancePeriod period;

  const _KpiBreakdown({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(text: 'KPI BREAKDOWN'),
          const SizedBox(height: AppDimensions.md),
          ...period.kpiRatings.map((kpi) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: _KpiRow(kpi: kpi),
              )),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final KpiRating kpi;

  const _KpiRow({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final ratingColor = kpi.rating >= 4.0
        ? AppColors.success
        : kpi.rating >= 3.0
            ? AppColors.secondary
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                kpi.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                kpi.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ratingColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: kpi.percentage,
            backgroundColor: AppColors.neutral100,
            valueColor: AlwaysStoppedAnimation(ratingColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weight: ${kpi.weight.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            Text(
              '${kpi.actual.toStringAsFixed(0)} / ${kpi.target.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentsCard extends StatelessWidget {
  final String comments;

  const _CommentsCard({required this.comments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.format_quote, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'EVALUATOR COMMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            comments,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PerformancePeriod period;

  const _HistoryCard({required this.period});

  @override
  Widget build(BuildContext context) {
    final pct = period.overallPercentage;
    final color = pct >= 0.8
        ? AppColors.success
        : pct >= 0.7
            ? AppColors.secondary
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.period,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Evaluated ${DateFormat('MMM d, yyyy').format(period.evaluationDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.neutral100,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                period.overallRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '/ ${period.maxRating.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}
