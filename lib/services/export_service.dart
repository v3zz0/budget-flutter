import 'dart:convert';

import '../config.dart';
import 'api_client.dart';

/// Una transazione appiattita, pronta per una riga di CSV.
class RigaExport {
  final DateTime data;
  final double importo;
  final String descrizione;
  final String categoria;
  final double budgetCategoria;
  final String portafoglio;
  final bool ricorrente;
  final bool contanti;

  const RigaExport({
    required this.data,
    required this.importo,
    required this.descrizione,
    required this.categoria,
    required this.budgetCategoria,
    required this.portafoglio,
    required this.ricorrente,
    required this.contanti,
  });
}

/// Esito di un export: le righe più quello che l'utente deve sapere per
/// fidarsi del file.
class RisultatoExport {
  final List<RigaExport> righe;

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
  bool get completo => righe.length + escluse == totaleDichiarato;

  int get mancanti => totaleDichiarato - righe.length - escluse;
}

class ExportService {
  /// Il massimo che l'API concede per pagina (`maxLimit` in config/api.js).
  static const int _perPagina = 100;

  /// Quante pagine al massimo, per non restare in un ciclo se il server
  /// dovesse rispondere in modo inatteso.
  static const int _maxPagine = 200;

  /// Scarica tutte le transazioni dell'utente, opzionalmente in un intervallo.
  ///
  /// Interroga direttamente `/api/transazionis` invece di passare dalle
  /// categorie con `populate=*` come fa DashboardService: lì le transazioni
  /// arrivano annidate e un limite sul populate le troncherebbe **in
  /// silenzio**. Qui la paginazione è esplicita e il totale è verificabile.
  ///
  /// Non serve ciclare i portafogli: il controller lato server filtra per
  /// utente, non per wallet, quindi una sola sweep li copre tutti.
  Future<RisultatoExport> carica(
    String token, {
    DateTime? dal,
    DateTime? al,
    Set<String> portafogliEsclusi = const {},
  }) async {
    final righe = <RigaExport>[];
    var totale = 0;
    var escluse = 0;
    var pagina = 1;

    while (pagina <= _maxPagine) {
      final query = <String, String>{
        'populate[categorie][populate][wallet]': 'true',
        'sort': 'Data:asc',
        'pagination[page]': '$pagina',
        'pagination[pageSize]': '$_perPagina',
      };
      if (dal != null) query['filters[Data][\$gte]'] = _iso(dal);
      if (al != null) query['filters[Data][\$lte]'] = _iso(al);

      final uri =
          Uri.parse('${Config.apiBaseUrl}/api/transazionis').replace(
        queryParameters: query,
      );
      final res = await ApiClient.get(uri, token: token);
      if (res.statusCode != 200) {
        throw Exception('Errore nel caricamento delle transazioni');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['data'] as List?) ?? const [];
      final meta = (body['meta']?['pagination'] as Map<String, dynamic>?) ?? {};
      totale = meta['total'] ?? totale;

      for (final item in items) {
        final riga = _riga(item as Map<String, dynamic>);
        if (portafogliEsclusi.contains(riga.portafoglio)) {
          escluse++;
        } else {
          righe.add(riga);
        }
      }

      final pageCount = meta['pageCount'] ?? 1;
      if (pagina >= pageCount || items.isEmpty) break;
      pagina++;
    }

    return RisultatoExport(
      righe: righe,
      totaleDichiarato: totale,
      escluse: escluse,
    );
  }

  /// Una transazione senza categoria o senza wallet popolati resta nel file coi
  /// campi vuoti, non viene scartata: una riga orfana che si vede è meglio di
  /// una riga sparita di nascosto.
  RigaExport _riga(Map<String, dynamic> j) {
    final categoria = j['categorie'] as Map<String, dynamic>?;
    final wallet = categoria?['wallet'] as Map<String, dynamic>?;

    return RigaExport(
      data: DateTime.tryParse(j['Data'] ?? '') ?? DateTime(1970),
      importo: (j['Importo'] ?? 0).toDouble(),
      descrizione: j['Descrizione'] ?? '',
      categoria: categoria?['Nome'] ?? '',
      budgetCategoria: (categoria?['Budget_categoria'] ?? 0).toDouble(),
      portafoglio: wallet?['Nome'] ?? '',
      ricorrente: j['TransazioneRicorrente'] ?? false,
      contanti: j['Contanti'] ?? false,
    );
  }

  static String _iso(DateTime d) =>
      '${d.year}-${_due(d.month)}-${_due(d.day)}';

  static String _due(int n) => n.toString().padLeft(2, '0');
}

/// Genera il CSV. Funzione pura e separata dal caricamento, così è testabile
/// senza toccare la rete.
///
/// Una riga per transazione, niente righe di riepilogo mescolate: il file
/// serve a essere letto da un foglio di calcolo o da un agente, e un file con
/// due tipi di riga costringe chi legge a indovinare quale sta guardando.
String generaCsv(List<RigaExport> righe) {
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
