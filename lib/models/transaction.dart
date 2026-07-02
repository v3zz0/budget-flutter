class Transaction {
  final String documentId;
  final double importo;
  final String descrizione;
  final DateTime data;
  final bool transazioneRicorrente;
  final DateTime? ricorrenzaTemporale; // nullable — non sempre presente
  final String categoriaDocumentId; // riferimento alla categoria padre

  Transaction({
    required this.documentId,
    required this.importo,
    required this.descrizione,
    required this.data,
    required this.transazioneRicorrente,
    this.ricorrenzaTemporale,
    required this.categoriaDocumentId,
  });

  // fromJson() — costruisce una Transaction dal JSON di Strapi
  factory Transaction.fromJson(Map<String, dynamic> json) {
    // La relazione categorie può essere popolata (oggetto) o null
    final categoria = json['categorie'];
    final categoriaId = categoria != null
        ? (categoria['documentId'] ?? '')
        : '';

    return Transaction(
      documentId: json['documentId'] ?? '',
      importo: (json['Importo'] ?? 0).toDouble(),
      descrizione: json['Descrizione'] ?? '',
      // DateTime.parse() converte la stringa data "2026-02-01" in oggetto DateTime
      // Equivalente di new Date('2026-02-01') in JavaScript
      data: DateTime.parse(json['Data'] ?? DateTime.now().toIso8601String()),
      transazioneRicorrente: json['TransazioneRicorrente'] ?? false,
      ricorrenzaTemporale: json['RicorrenzaTemporale'] != null
          ? DateTime.parse(json['RicorrenzaTemporale'])
          : null,
      categoriaDocumentId: categoriaId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {
        'Importo': importo,
        'Descrizione': descrizione,
        'Data': data.toIso8601String().substring(0, 10),
        'TransazioneRicorrente': transazioneRicorrente,
        'categorie': categoriaDocumentId,
      },
    };
  }
}
