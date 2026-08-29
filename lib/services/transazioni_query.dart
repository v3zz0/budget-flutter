import 'dart:convert';

import '../config.dart';
import 'api_client.dart';

/// Una transazione appiattita, con i nomi di categoria e portafoglio già
/// risolti: la forma comoda sia per una riga di CSV sia per un totale annuo.
class RigaTransazione {
  final DateTime data;
  final double importo;
  final String descrizione;
  final String categoriaId;
  final String categoria;
  final double budgetCategoria;
  final String portafoglio;
  final bool ricorrente;
  final bool contanti;

  const RigaTransazione({
    required this.data,
    required this.importo,
    required this.descrizione,
    required this.categoriaId,
    required this.categoria,
    required this.budgetCategoria,
    required this.portafoglio,
    required this.ricorrente,
    required this.contanti,
  });
}

/// Righe raccolte più quello che serve per sapere se sono tutte.
class EsitoTransazioni {
  final List<RigaTransazione> righe;

  /// Quante ne dichiara il server per questa query (`meta.pagination.total`).
  final int totaleDichiarato;

  const EsitoTransazioni({
    required this.righe,
    required this.totaleDichiarato,
  });

  /// Le righe raccolte coprono quello che il server dichiarava.
  /// Chi mostra i numeri deve dirlo quando è false: un totale parziale che si
  /// presenta come completo porta a conclusioni sbagliate senza dare segnali.
  bool get completo => righe.length >= totaleDichiarato;

  int get mancanti => totaleDichiarato - righe.length;
}

/// Sweep paginata su `/api/transazionis`.
///
/// Sta in un file suo perché la usano in due — l'export e la vista annuale — e
/// duplicare il ciclo di paginazione significherebbe farli divergere proprio
/// sulla parte che garantisce di non perdere righe.
///
/// Da non confondere con `DashboardService._transazioni`, che chiede
/// `pagination[limit]=100` senza paginare: va bene per un mese, tronca in
/// silenzio su un anno.
///
/// Non serve ciclare i portafogli: il controller lato server filtra per utente,
/// quindi senza [walletId] una sola sweep li copre tutti.
class TransazioniQuery {
  /// Il massimo per pagina concesso dall'API (`maxLimit` in config/api.js).
  static const int perPagina = 100;

  /// Tetto di sicurezza: se il server rispondesse in modo inatteso, meglio
  /// fermarsi che restare in un ciclo infinito.
  static const int maxPagine = 200;

  static Future<EsitoTransazioni> carica(
    String token, {
    DateTime? dal,
    DateTime? al,
    String? walletId,
  }) async {
    final righe = <RigaTransazione>[];
    var totale = 0;
    var pagina = 1;

    while (pagina <= maxPagine) {
      final query = <String, String>{
        'populate[categorie][populate][wallet]': 'true',
        'sort': 'Data:asc',
        'pagination[page]': '$pagina',
        'pagination[pageSize]': '$perPagina',
      };
      if (dal != null) query['filters[Data][\$gte]'] = iso(dal);
      if (al != null) query['filters[Data][\$lte]'] = iso(al);
      if (walletId != null) {
        query['filters[categorie][wallet][documentId][\$eq]'] = walletId;
      }

      final uri = Uri.parse('${Config.apiBaseUrl}/api/transazionis')
          .replace(queryParameters: query);
      final res = await ApiClient.get(uri, token: token);
      if (res.statusCode != 200) {
        throw Exception('Errore nel caricamento delle transazioni');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['data'] as List?) ?? const [];
      final meta = (body['meta']?['pagination'] as Map<String, dynamic>?) ?? {};
      totale = meta['total'] ?? totale;

      for (final item in items) {
        righe.add(riga(item as Map<String, dynamic>));
      }

      final pageCount = meta['pageCount'] ?? 1;
      if (pagina >= pageCount || items.isEmpty) break;
      pagina++;
    }

    return EsitoTransazioni(righe: righe, totaleDichiarato: totale);
  }

  /// Una transazione senza categoria o senza wallet popolati resta nel
  /// risultato coi campi vuoti, non viene scartata: una riga orfana che si vede
  /// è meglio di una riga sparita di nascosto.
  static RigaTransazione riga(Map<String, dynamic> j) {
    final categoria = j['categorie'] as Map<String, dynamic>?;
    final wallet = categoria?['wallet'] as Map<String, dynamic>?;

    return RigaTransazione(
      data: DateTime.tryParse(j['Data'] ?? '') ?? DateTime(1970),
      importo: (j['Importo'] ?? 0).toDouble(),
      descrizione: j['Descrizione'] ?? '',
      categoriaId: categoria?['documentId'] ?? '',
      categoria: categoria?['Nome'] ?? '',
      budgetCategoria: (categoria?['Budget_categoria'] ?? 0).toDouble(),
      portafoglio: wallet?['Nome'] ?? '',
      ricorrente: j['TransazioneRicorrente'] ?? false,
      contanti: j['Contanti'] ?? false,
    );
  }

  static String iso(DateTime d) => '${d.year}-${_due(d.month)}-${_due(d.day)}';

  static String _due(int n) => n.toString().padLeft(2, '0');
}
