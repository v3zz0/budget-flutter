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
  // Timeout esteso: con più documenti l'LLM può metterci un po'.
  static const Duration _timeoutLungo = Duration(minutes: 5);

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
      throw Exception(
        'Errore analisi estratto conto (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    // Strapi a volte wrappa in { data, meta }: gestiamo entrambi i casi.
    final json = body is Map && body['data'] != null ? body['data'] : body;
    return ReportAnalisi.fromJson(json);
  }
}
