import '../models/category.dart';
import 'transazioni_query.dart';

/// Riepilogo annuale di una categoria.
class CategoriaAnno {
  final String documentId;
  final String nome;
  final String icona;

  /// Speso nell'anno. Numero **rilevato**: somma delle transazioni.
  final double speso;

  /// Budget mensile attuale della categoria.
  final double budgetMensile;

  /// Quanti mesi entrano nella stima del budget annuo.
  final int mesiConsiderati;

  /// Speso mese per mese, indice 0 = gennaio. Sempre 12 elementi.
  final List<double> perMese;

  const CategoriaAnno({
    required this.documentId,
    required this.nome,
    required this.icona,
    required this.speso,
    required this.budgetMensile,
    required this.mesiConsiderati,
    required this.perMese,
  });

  /// Budget annuo **stimato**, non rilevato: il budget di categoria non ha
  /// storico, esiste solo il valore di oggi. Se durante l'anno l'hai cambiato
  /// — e applicare un consiglio lo cambia — questo numero non è quello che
  /// avevi davvero impostato allora. Va sempre mostrato come stima.
  double get budgetStimato => budgetMensile * mesiConsiderati;

  /// null quando non c'è un budget da cui partire: senza tetto non esiste una
  /// percentuale, e mostrare 0% o infinito sarebbe peggio di non mostrare nulla.
  double? get percentuale =>
      budgetStimato <= 0 ? null : speso / budgetStimato;

  bool get oltreStima => budgetStimato > 0 && speso > budgetStimato;
}

/// Riepilogo annuale completo.
class RiepilogoAnno {
  final int anno;
  final List<CategoriaAnno> categorie;

  /// Totale speso nell'anno, per tutte le categorie.
  final double speso;

  /// Somma dei budget stimati. Stima anche questo, per lo stesso motivo.
  final double budgetStimato;

  /// Speso mese per mese sull'intero portafoglio, indice 0 = gennaio.
  final List<double> perMese;

  /// Quanti mesi entrano nella stima: 12 per un anno concluso, i mesi
  /// trascorsi per l'anno in corso.
  final int mesiConsiderati;

  const RiepilogoAnno({
    required this.anno,
    required this.categorie,
    required this.speso,
    required this.budgetStimato,
    required this.perMese,
    required this.mesiConsiderati,
  });

  bool get vuoto => speso == 0;
}

class AnnoService {
  /// Quanti mesi contare per la stima del budget annuo.
  ///
  /// Un anno passato vale 12: gennaio-dicembre, così due anni si confrontano
  /// sullo stesso metro. L'anno in corso vale i mesi trascorsi: ad agosto,
  /// confrontare otto mesi di spesa con dodici di budget farebbe sembrare
  /// virtuoso chiunque.
  ///
  /// Un anno futuro vale 0: non c'è ancora niente da confrontare.
  static int mesiDaContare(int anno, {DateTime? adesso}) {
    final ora = adesso ?? DateTime.now();
    if (anno < ora.year) return 12;
    if (anno > ora.year) return 0;
    return ora.month;
  }

  /// Aggrega le transazioni di un anno per categoria e per mese.
  ///
  /// Funzione pura: prende quello che ha già in mano il chiamante e non tocca
  /// né rete né BuildContext, così i test non hanno bisogno di mock.
  ///
  /// [categorie] serve per i budget e per far comparire anche le categorie
  /// senza spese: una categoria con budget e zero spese è un'informazione, non
  /// una riga da nascondere.
  static RiepilogoAnno calcola({
    required int anno,
    required List<RigaTransazione> transazioni,
    required List<Category> categorie,
    DateTime? adesso,
  }) {
    final mesi = mesiDaContare(anno, adesso: adesso);

    // Le transazioni fuori dall'anno non dovrebbero arrivare qui, ma se un
    // filtro cambiasse le conterremmo nel totale annuo senza accorgercene.
    final dellAnno = transazioni.where((t) => t.data.year == anno);

    final perCategoria = <String, List<double>>{};
    final nomi = <String, String>{};
    final totaliMese = List<double>.filled(12, 0);

    for (final t in dellAnno) {
      final serie = perCategoria.putIfAbsent(
        t.categoriaId,
        () => List<double>.filled(12, 0),
      );
      serie[t.data.month - 1] += t.importo;
      totaliMese[t.data.month - 1] += t.importo;
      if (t.categoria.isNotEmpty) nomi[t.categoriaId] = t.categoria;
    }

    final righe = <CategoriaAnno>[];
    final visti = <String>{};

    for (final c in categorie) {
      visti.add(c.documentId);
      final serie = perCategoria[c.documentId] ?? List<double>.filled(12, 0);
      righe.add(
        CategoriaAnno(
          documentId: c.documentId,
          nome: c.nome,
          icona: c.icona,
          speso: serie.fold(0.0, (s, v) => s + v),
          budgetMensile: c.budgetCategoria,
          mesiConsiderati: mesi,
          perMese: serie,
        ),
      );
    }

    // Categorie eliminate nel frattempo: le spese restano nello storico e
    // devono restare nel totale, altrimenti la somma dei mesi non torna col
    // totale annuo e non si capisce perché.
    for (final entry in perCategoria.entries) {
      if (visti.contains(entry.key)) continue;
      righe.add(
        CategoriaAnno(
          documentId: entry.key,
          nome: nomi[entry.key] ?? 'Categoria eliminata',
          icona: '',
          speso: entry.value.fold(0.0, (s, v) => s + v),
          budgetMensile: 0,
          mesiConsiderati: mesi,
          perMese: entry.value,
        ),
      );
    }

    righe.sort((a, b) => b.speso.compareTo(a.speso));

    return RiepilogoAnno(
      anno: anno,
      categorie: righe,
      speso: totaliMese.fold(0.0, (s, v) => s + v),
      budgetStimato: righe.fold(0.0, (s, c) => s + c.budgetStimato),
      perMese: totaliMese,
      mesiConsiderati: mesi,
    );
  }
}
