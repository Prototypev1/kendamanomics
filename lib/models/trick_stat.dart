class TrickStat {
  final String trickId;
  final String? firstLacedPlayerFirstname;
  final String? firstLacedPlayerLastname;
  final int? totalLacedCount;
  final int? trickPoints;

  const TrickStat({
    required this.trickId,
    this.firstLacedPlayerFirstname,
    this.firstLacedPlayerLastname,
    this.totalLacedCount,
    this.trickPoints,
  });
}
