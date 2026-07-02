class Wallet {
  final String documentId;
  final String nome;
  final double budget;
  final double salvadanaio;

  Wallet({
    required this.documentId,
    required this.nome,
    required this.budget,
    required this.salvadanaio,
  });

  // fromJson() — costruisce un Wallet dal JSON di Strapi
  // Equivalente di mappare res.data in Vue
  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      documentId: json['documentId'] ?? '',
      nome: json['Nome'] ?? '',
      budget: (json['Budget'] ?? 0).toDouble(),
      salvadanaio: (json['Salvadanaio'] ?? 0).toDouble(),
    );
  }
}
