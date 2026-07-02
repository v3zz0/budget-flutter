import 'transaction.dart';

class Category {
  final String documentId;
  final String nome;
  final double budgetCategoria;
  final String walletDocumentId;
  final String icona;
  final List<Transaction> transazionis;

  Category({
    required this.documentId,
    required this.nome,
    required this.budgetCategoria,
    required this.walletDocumentId,
    this.icona = '',
    this.transazionis = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'];
    final walletId = wallet != null ? (wallet['documentId'] ?? '') : '';

    // Strapi con populate:* restituisce transazionis come lista
    final categoryId = json['documentId'] ?? '';
    final List<Transaction> transazioni = [];
    final raw = json['transazionis'];
    if (raw != null && raw is List) {
      for (final t in raw) {
        transazioni.add(Transaction.fromJson({...t, 'categorie': {'documentId': categoryId}}));
      }
    }

    return Category(
      documentId: json['documentId'] ?? '',
      nome: json['Nome'] ?? '',
      budgetCategoria: (json['Budget_categoria'] ?? 0).toDouble(),
      walletDocumentId: walletId,
      icona: json['Icona'] ?? json['icona'] ?? '',
      transazionis: transazioni,
    );
  }
}
