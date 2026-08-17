import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/report_analisi.dart';

// Un documento selezionato per l'analisi: su mobile/desktop è un File,
// su web sono i bytes in memoria (file_picker Web non espone il path).
class AnalisiDoc {
  final File? file;
  final Uint8List? bytes;
  final String nome;
  const AnalisiDoc({this.file, this.bytes, required this.nome});
}

// Service per l'upload di uno o più estratti conto (PDF o CSV) al backend.
// Il backend unisce il testo di tutti i documenti e produce un unico report.
// L'analisi prende ~30-60s (o più con più file) perché gira su Ollama.
class AnalisiService {
  // Deve stare SOPRA il tetto del server (AI_BUDGET_MS, 2 minuti) e sotto
  // quello del reverse proxy: chi molla per primo decide cosa vede l'utente, e
  // deve essere sempre il server, che sa consegnare un report parziale.
  // Aspettare più a lungo del server significa solo restare a fissare uno
  // spinner per una risposta già arrivata o già persa.
  static const Duration _timeoutLungo = Duration(minutes: 3);

  Future<ReportAnalisi> analizza({
    required String token,
    required List<AnalisiDoc> docs,
    required String walletId,
    required String mese, // formato YYYY-MM
  }) async {
    if (docs.isEmpty) {
      throw Exception('Nessun documento selezionato');
    }

    final uri = Uri.parse('${Config.apiBaseUrl}/api/analisi-estratto-conto');

    // MultipartRequest = equivalente di FormData in JavaScript.
    // Tutti i file vengono inviati sotto lo stesso campo "pdf": lato backend
    // diventano un array e vengono analizzati insieme.
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['walletId'] = walletId;
    request.fields['mese'] = mese;

    for (final d in docs) {
      if (d.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('pdf', d.bytes!, filename: d.nome),
        );
      } else if (d.file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('pdf', d.file!.path, filename: d.nome),
        );
      }
    }

    final streamed = await request.send().timeout(_timeoutLungo);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_messaggioErrore(response));
    }

    final body = jsonDecode(response.body);
    // Strapi a volte wrappa in { data, meta }: gestiamo entrambi i casi.
    final json = body is Map && body['data'] != null ? body['data'] : body;
    return ReportAnalisi.fromJson(json);
  }

  /// Messaggio leggibile, senza incollare in pagina il corpo della risposta.
  /// I 5xx del reverse proxy arrivano come pagina HTML: mostrarla all'utente
  /// non lo aiuta a capire cosa fare.
  String _messaggioErrore(http.Response r) {
    switch (r.statusCode) {
      case 502:
      case 503:
      case 504:
        return 'L\'analisi ha superato il tempo massimo e il server ha chiuso '
            'la connessione. Riprova, oppure carica un documento alla volta.';
      case 413:
        return 'I documenti sono troppo grandi per il server.';
      case 401:
        return 'Sessione scaduta. Effettua nuovamente il login.';
      case 403:
        return 'Il tuo utente non è autorizzato ad analizzare gli estratti conto.';
      case 404:
        return 'Portafoglio non trovato.';
    }

    // Strapi risponde { error: { message } }: quello vale la pena mostrarlo.
    try {
      final m = jsonDecode(r.body)['error']?['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {
      // Corpo non JSON (di solito una pagina di errore del proxy): si ignora.
    }
    return 'Errore del server durante l\'analisi (${r.statusCode}).';
  }
}
