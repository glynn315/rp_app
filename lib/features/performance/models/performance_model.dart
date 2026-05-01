class KpiRating {
  final String name;
  final double weight;
  final double target;
  final double actual;
  final double rating;

  const KpiRating({
    required this.name,
    required this.weight,
    required this.target,
    required this.actual,
    required this.rating,
  });

  double get percentage => (actual / target).clamp(0.0, 1.0);
}

class PerformancePeriod {
  final String id;
  final String period;
  final String evaluatorName;
  final DateTime evaluationDate;
  final double overallRating;
  final double maxRating;
  final List<KpiRating> kpiRatings;
  final String? comments;

  const PerformancePeriod({
    required this.id,
    required this.period,
    required this.evaluatorName,
    required this.evaluationDate,
    required this.overallRating,
    required this.maxRating,
    required this.kpiRatings,
    this.comments,
  });

  double get overallPercentage => (overallRating / maxRating).clamp(0.0, 1.0);

  String get ratingLabel {
    final pct = overallPercentage;
    if (pct >= 0.9) return 'Outstanding';
    if (pct >= 0.8) return 'Exceeds Expectations';
    if (pct >= 0.7) return 'Meets Expectations';
    if (pct >= 0.6) return 'Needs Improvement';
    return 'Below Standard';
  }
}
