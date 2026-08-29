class Wallet {
  final String documentId;
  final String nome;
  final double budget;
  final double salvadanaio;

  /// Portafoglio tenuto fuori da export, analisi, consigli e avvisi di soglia.
  /// Resta comunque visibile in dashboard: serve come promemoria di scadenze
  /// (mutuo, IMU), non come spesa corrente.
  final bool esclusoDaStatistiche;

  Wallet({
    required this.documentId,
    required this.nome,
    required this.budget,
    required this.salvadanaio,
    this.esclusoDaStatistiche = false,
  });

  // fromJson() — costruisce un Wallet dal JSON di Strapi
  // Equivalente di mappare res.data in Vue
  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      documentId: json['documentId'] ?? '',
      nome: json['Nome'] ?? '',
      budget: (json['Budget'] ?? 0).toDouble(),
      salvadanaio: (json['Salvadanaio'] ?? 0).toDouble(),
      // Se il campo non c'è (server non ancora aggiornato) il portafoglio
      // conta come incluso: meglio un dato in più che uno sparito di nascosto.
      esclusoDaStatistiche: json['escludiDaStatistiche'] ?? false,
    );
  }

  Wallet copyWith({bool? esclusoDaStatistiche}) => Wallet(
        documentId: documentId,
        nome: nome,
        budget: budget,
        salvadanaio: salvadanaio,
        esclusoDaStatistiche: esclusoDaStatistiche ?? this.esclusoDaStatistiche,
      );
}
