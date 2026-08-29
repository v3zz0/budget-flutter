import 'transazioni_query.dart';

/// Esito di un export: le righe più quello che l'utente deve sapere per
/// fidarsi del file.
class RisultatoExport {
  final List<RigaTransazione> righe;

  /// Quante transazioni dichiara il server per questa query.
  final int totaleDichiarato;

  /// Righe saltate perché appartengono a portafogli esclusi dalle statistiche.
  final int escluse;

  const RisultatoExport({
    required this.righe,
    required this.totaleDichiarato,
    required this.escluse,
  });

  /// true se abbiamo davvero raccolto tutto quello che il server dichiarava.
  /// Il chiamante deve dirlo quando è false: un export parziale che si spaccia
  /// per completo è peggio di un export fallito.
  bool get completo => righe.length + escluse >= totaleDichiarato;

  int get mancanti => totaleDichiarato - righe.length - escluse;
}

class ExportService {
  /// Scarica le transazioni dell'utente, opzionalmente in un intervallo, e
  /// toglie quelle dei portafogli esclusi dalle statistiche.
  ///
  /// La sweep paginata sta in [TransazioniQuery], condivisa con la vista
  /// annuale: è la parte che garantisce di non perdere righe, e averne due
  /// copie significherebbe farle divergere.
  Future<RisultatoExport> carica(
    String token, {
    DateTime? dal,
    DateTime? al,
    Set<String> portafogliEsclusi = const {},
  }) async {
    final esito = await TransazioniQuery.carica(token, dal: dal, al: al);

    final righe = <RigaTransazione>[];
    var escluse = 0;
    for (final r in esito.righe) {
      if (portafogliEsclusi.contains(r.portafoglio)) {
        escluse++;
      } else {
        righe.add(r);
      }
    }

    return RisultatoExport(
      righe: righe,
      totaleDichiarato: esito.totaleDichiarato,
      escluse: escluse,
    );
  }
}

/// Genera il CSV. Funzione pura e separata dal caricamento, così è testabile
/// senza toccare la rete.
///
/// Una riga per transazione, niente righe di riepilogo mescolate: il file
/// serve a essere letto da un foglio di calcolo o da un agente, e un file con
/// due tipi di riga costringe chi legge a indovinare quale sta guardando.
String generaCsv(List<RigaTransazione> righe) {
  final buffer = StringBuffer();
  buffer.writeln(
    'data,importo,descrizione,categoria,budget_categoria,portafoglio,ricorrente,contanti',
  );

  for (final r in righe) {
    buffer.writeln([
      // ISO: ordinabile e senza l'ambiguità di gg/mm contro mm/gg.
      '${r.data.year}-${_pad(r.data.month)}-${_pad(r.data.day)}',
      r.importo.toStringAsFixed(2),
      _campo(r.descrizione),
      _campo(r.categoria),
      r.budgetCategoria.toStringAsFixed(2),
      _campo(r.portafoglio),
      r.ricorrente ? 'si' : 'no',
      r.contanti ? 'si' : 'no',
    ].join(','));
  }

  return buffer.toString();
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// Escaping CSV su ogni campo di testo, non solo sulla descrizione: anche il
/// nome di una categoria o di un portafoglio può contenere una virgola.
String _campo(String valore) {
  final pulito = valore.replaceAll('\r', ' ').replaceAll('\n', ' ');
  return '"${pulito.replaceAll('"', '""')}"';
}
