// Modello della risposta dell'endpoint /api/analisi-estratto-conto
// Speculare al JSON costruito nel controller Strapi src/api/analisi/controllers/analisi.js

class SforatoCategoria {
  final String documentId;
  final String nome;
  final String? icona;
  final double budget;
  final double speso;
  final double rimanente;
  final bool sforato;

  SforatoCategoria({
    required this.documentId,
    required this.nome,
    this.icona,
    required this.budget,
    required this.speso,
    required this.rimanente,
    required this.sforato,
  });

  factory SforatoCategoria.fromJson(Map<String, dynamic> j) => SforatoCategoria(
        documentId: j['documentId'] ?? '',
        nome: j['nome'] ?? '',
        icona: j['icona'],
        budget: (j['budget'] ?? 0).toDouble(),
        speso: (j['speso'] ?? 0).toDouble(),
        rimanente: (j['rimanente'] ?? 0).toDouble(),
        sforato: j['sforato'] ?? false,
      );
}

class TransazioneMancante {
  final String data;
  final double importo;
  final String descrizione;
  final String? categoriaSuggerita;

  TransazioneMancante({
    required this.data,
    required this.importo,
    required this.descrizione,
    this.categoriaSuggerita,
  });

  factory TransazioneMancante.fromJson(Map<String, dynamic> j) => TransazioneMancante(
        data: j['data'] ?? '',
        importo: (j['importo'] ?? 0).toDouble(),
        descrizione: j['descrizione'] ?? '',
        categoriaSuggerita: j['categoriaSuggerita'],
      );

  TransazioneMancante conCategoria(String? categoria) => TransazioneMancante(
        data: data,
        importo: importo,
        descrizione: descrizione,
        categoriaSuggerita: categoria ?? categoriaSuggerita,
      );
}

class TotaleReport {
  final double budget;
  final double speso;
  final double rimanente;

  TotaleReport({
    required this.budget,
    required this.speso,
    required this.rimanente,
  });

  factory TotaleReport.fromJson(Map<String, dynamic> j) => TotaleReport(
        budget: (j['budget'] ?? 0).toDouble(),
        speso: (j['speso'] ?? 0).toDouble(),
        rimanente: (j['rimanente'] ?? 0).toDouble(),
      );
}

class ValidazioneReport {
  final bool ok;
  final String? warning;

  ValidazioneReport({required this.ok, this.warning});

  factory ValidazioneReport.fromJson(Map<String, dynamic> j) => ValidazioneReport(
        ok: j['ok'] ?? true,
        warning: j['warning'],
      );
}

class ReportAnalisi {
  final String mese;
  final String walletId;
  final ValidazioneReport validazione;
  final Map<String, String>? periodoEstratto; // { dal, al }
  final List<SforatoCategoria> sforamenti;
  final List<TransazioneMancante> mancanti;
  final TotaleReport totale;
  final String giudizio;

  /// true = categorie e giudizio mancano di proposito: il motore AI scelto è
  /// il modello sul telefono, quindi li genera l'app dopo aver ricevuto i dati.
  final bool aiSulTelefono;

  ReportAnalisi({
    required this.mese,
    required this.walletId,
    required this.validazione,
    this.periodoEstratto,
    required this.sforamenti,
    required this.mancanti,
    required this.totale,
    required this.giudizio,
    this.aiSulTelefono = false,
  });

  ReportAnalisi copyWith({
    List<TransazioneMancante>? mancanti,
    String? giudizio,
  }) =>
      ReportAnalisi(
        mese: mese,
        walletId: walletId,
        validazione: validazione,
        periodoEstratto: periodoEstratto,
        sforamenti: sforamenti,
        mancanti: mancanti ?? this.mancanti,
        totale: totale,
        giudizio: giudizio ?? this.giudizio,
        aiSulTelefono: aiSulTelefono,
      );

  factory ReportAnalisi.fromJson(Map<String, dynamic> j) {
    Map<String, String>? periodo;
    if (j['periodoEstratto'] is Map) {
      periodo = {
        'dal': j['periodoEstratto']['dal'] ?? '',
        'al': j['periodoEstratto']['al'] ?? '',
      };
    }
    return ReportAnalisi(
      mese: j['mese'] ?? '',
      walletId: j['walletId'] ?? '',
      validazione: ValidazioneReport.fromJson(j['validazione'] ?? {}),
      periodoEstratto: periodo,
      sforamenti: (j['sforamenti'] as List? ?? [])
          .map((e) => SforatoCategoria.fromJson(e))
          .toList(),
      mancanti: (j['mancanti'] as List? ?? [])
          .map((e) => TransazioneMancante.fromJson(e))
          .toList(),
      totale: TotaleReport.fromJson(j['totale'] ?? {}),
      giudizio: j['giudizio'] ?? '',
      aiSulTelefono: j['aiSulTelefono'] ?? false,
    );
  }
}
