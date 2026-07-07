class Bond {
  final String isin;
  final String bondName;
  final String? rating;
  final double? bondYield;
  final int? minInvestment;
  final String? payoutFrequency;
  final String? logoUrl;
  final String? detailUrl;
  final double tenure;
  final String? maturityDate;
  final String? color;
  final bool isPinned;
  final int position;

  Bond({
    required this.isin,
    required this.bondName,
    this.rating,
    this.bondYield,
    this.minInvestment,
    this.payoutFrequency,
    this.logoUrl,
    this.detailUrl,
    required this.tenure,
    this.maturityDate,
    this.color,
    this.isPinned = false,
    this.position = 0,
  });

  factory Bond.fromJson(Map<String, dynamic> j) => Bond(
        isin: j['isin'] as String? ?? '',
        bondName: j['bondName'] as String? ?? 'Unknown Bond',
        rating: j['rating'] as String?,
        bondYield: j['bondYield'] != null
            ? double.tryParse(j['bondYield'].toString())
            : null,
        minInvestment: j['minInvestment'] != null
            ? int.tryParse(j['minInvestment'].toString())
            : null,
        payoutFrequency: j['payoutFrequency'] as String?,
        logoUrl: j['logoUrl'] as String?,
        detailUrl: j['detailUrl'] as String?,
        tenure: double.tryParse(j['tenure'].toString()) ?? 0,
        maturityDate: j['maturityDate'] as String?,
        color: j['color'] as String?,
        isPinned: j['isPinned'] as bool? ?? false,
        position: j['position'] as int? ?? 0,
      );

  Bond copyWith({String? color, bool? isPinned, int? position}) => Bond(
        isin: isin,
        bondName: bondName,
        rating: rating,
        bondYield: bondYield,
        minInvestment: minInvestment,
        payoutFrequency: payoutFrequency,
        logoUrl: logoUrl,
        detailUrl: detailUrl,
        tenure: tenure,
        maturityDate: maturityDate,
        color: color ?? this.color,
        isPinned: isPinned ?? this.isPinned,
        position: position ?? this.position,
      );

  String get tenureLabel {
    final totalMonths = (tenure * 12).round();
    final y = totalMonths ~/ 12;
    final m = totalMonths % 12;
    if (y == 0) return '${m}M';
    if (m == 0) return '${y}Y';
    return '${y}Y ${m}M';
  }
}