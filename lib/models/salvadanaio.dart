class Salvadanaio {
  final String documentId;
  final DateTime mese;
  final double budgetAllocato;
  final double speso;
  final double risparmiato;
  final String walletDocumentId; // riferimento al wallet padre

  Salvadanaio({
    required this.documentId,
    required this.mese,
    required this.budgetAllocato,
    required this.speso,
    required this.risparmiato,
    required this.walletDocumentId,
  });

  // fromJson() — costruisce un Salvadanaio dal JSON di Strapi
  factory Salvadanaio.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'];
    final walletId = wallet != null ? (wallet['documentId'] ?? '') : '';

    return Salvadanaio(
      documentId: json['documentId'] ?? '',
      mese: DateTime.parse(json['mese'] ?? DateTime.now().toIso8601String()),
      budgetAllocato: (json['budgetAllocato'] ?? 0).toDouble(),
      speso: (json['speso'] ?? 0).toDouble(),
      risparmiato: (json['risparmiato'] ?? 0).toDouble(),
      walletDocumentId: walletId,
    );
  }
}
