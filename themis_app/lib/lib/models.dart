// themis_app/lib/models/models.dart

class CaseHistory {
  final String id;
  final String title;
  final String date;
  final String status;
  final int matchCount;

  CaseHistory({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
    required this.matchCount,
  });
}

class Precedent {
  final String id;
  final String title;
  final String tribunal;
  final double similarity;
  final String status;
  final String legalStatus;
  final String theme;
  final String thesis;
  final String summary;
  final String whyApplies;

  Precedent({
    required this.id,
    required this.title,
    required this.tribunal,
    required this.similarity,
    required this.status,
    required this.legalStatus,
    required this.theme,
    required this.thesis,
    required this.summary,
    required this.whyApplies,
  });
}
