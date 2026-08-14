// Consiglio sul budget di una categoria, generato a fine mese dal backend.
// I numeri arrivano già calcolati dal server: qui si mostrano e basta.

class SpesaMese {
  final String mese; // "2026-07"
  final double speso;

  SpesaMese({required this.mese, required this.speso});

  factory SpesaMese.fromJson(Map<String, dynamic> j) => SpesaMese(
        mese: j['mese'] ?? '',
        speso: (j['speso'] ?? 0).toDouble(),
      );
}

class Consiglio {
  final String documentId;
  final String tipo; // "alza" | "abbassa"
  final double budgetAttuale;
  final double budgetProposto;
  final List<SpesaMese> mesiAnalizzati;
  final String testo;
  final String stato; // "nuovo" | "letto" | "applicato" | "ignorato"
  final String categoriaNome;
  final String categoriaDocumentId;
  final String? categoriaIcona;

  Consiglio({
    required this.documentId,
    required this.tipo,
    required this.budgetAttuale,
    required this.budgetProposto,
    required this.mesiAnalizzati,
    required this.testo,
    required this.stato,
    required this.categoriaNome,
    required this.categoriaDocumentId,
    this.categoriaIcona,
  });

  bool get isNuovo => stato == 'nuovo';
  bool get isAlza => tipo == 'alza';

  /// Quanto cambia il budget: positivo se aumenta.
  double get differenza => budgetProposto - budgetAttuale;

  factory Consiglio.fromJson(Map<String, dynamic> j) {
    final cat = j['categorie'] ?? {};
    return Consiglio(
      documentId: j['documentId'] ?? '',
      tipo: j['tipo'] ?? 'alza',
      budgetAttuale: (j['budgetAttuale'] ?? 0).toDouble(),
      budgetProposto: (j['budgetProposto'] ?? 0).toDouble(),
      mesiAnalizzati: (j['mesiAnalizzati'] as List? ?? [])
          .map((e) => SpesaMese.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      testo: j['testo'] ?? '',
      stato: j['stato'] ?? 'nuovo',
      categoriaNome: cat['Nome'] ?? '',
      categoriaDocumentId: cat['documentId'] ?? '',
      categoriaIcona: cat['icona'],
    );
  }
}
