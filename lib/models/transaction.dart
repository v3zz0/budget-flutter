class Transaction {
  final String documentId;
  final double importo;
  final String descrizione;
  final DateTime data;
  final bool transazioneRicorrente;
  final DateTime? ricorrenzaTemporale; // nullable — non sempre presente
  final bool contanti; // pagata in contanti → esclusa dal confronto in analisi
  final String categoriaDocumentId; // riferimento alla categoria padre

  // Generato sul telefono al momento del salvataggio, non dal server. Serve a
  // riconoscere un invio ripetuto (stessa transazione rimandata dopo che la
  // risposta del server si è persa per strada) senza creare un doppione.
  final String? clientUuid;

  Transaction({
    required this.documentId,
    required this.importo,
    required this.descrizione,
    required this.data,
    required this.transazioneRicorrente,
    this.ricorrenzaTemporale,
    this.contanti = false,
    required this.categoriaDocumentId,
    this.clientUuid,
  });

  Transaction conClientUuid(String uuid) => Transaction(
        documentId: documentId,
        importo: importo,
        descrizione: descrizione,
        data: data,
        transazioneRicorrente: transazioneRicorrente,
        ricorrenzaTemporale: ricorrenzaTemporale,
        contanti: contanti,
        categoriaDocumentId: categoriaDocumentId,
        clientUuid: uuid,
      );

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
      contanti: json['Contanti'] ?? false,
      categoriaDocumentId: categoriaId,
      clientUuid: json['ClientUuid'],
    );
  }

  Map<String, dynamic> toJson() {
    final giorno = data.toIso8601String().substring(0, 10);
    return {
      'data': {
        'Importo': importo,
        'Descrizione': descrizione,
        'Data': giorno,
        'TransazioneRicorrente': transazioneRicorrente,
        if (clientUuid != null) 'ClientUuid': clientUuid,
        // Il giorno di addebito, scritto invece che dedotto. Finora questo
        // campo non partiva mai: cron e app ripiegavano entrambi su `Data`, e
        // nel database restava sempre null — un campo dello schema che non
        // voleva dire niente. Vale `Data` come prima, ma adesso è nel dato.
        // Su una transazione non ricorrente resta null: non ha un giorno che
        // torna, e riempirlo darebbe l'idea sbagliata a chi legge il DB.
        'RicorrenzaTemporale': transazioneRicorrente
            ? (ricorrenzaTemporale ?? data).toIso8601String().substring(0, 10)
            : null,
        'Contanti': contanti,
        'categorie': categoriaDocumentId,
      },
    };
  }
}
