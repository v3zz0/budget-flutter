import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/report_analisi.dart';

// Service per l'upload del PDF dell'estratto conto al backend Strapi.
// L'analisi prende ~30-60s perché Ollama gira sul modello qwen2.5:7b.
//
// Supporta sia File (mobile/desktop) sia bytes (web), perché file_picker
// su Flutter Web non espone path ma solo il contenuto in memoria.
class AnalisiService {
  // Timeout esteso: l'LLM può impiegare un po' a generare la risposta
  static const Duration _timeoutLungo = Duration(minutes: 3);

  Future<ReportAnalisi> analizza({
    required String token,
    File? pdfFile,
    Uint8List? pdfBytes,
    String pdfNome = 'estratto.pdf',
    required String walletId,
    required String mese, // formato YYYY-MM
  }) async {
    if (pdfFile == null && pdfBytes == null) {
      throw Exception('PDF mancante: passare pdfFile o pdfBytes');
    }

    final uri = Uri.parse('${Config.apiBaseUrl}/api/analisi-estratto-conto');

    // MultipartRequest = equivalente di FormData in JavaScript
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['walletId'] = walletId;
    request.fields['mese'] = mese;

    if (pdfBytes != null) {
      // Su web (e in generale quando abbiamo i bytes in memoria)
      request.files.add(
        http.MultipartFile.fromBytes('pdf', pdfBytes, filename: pdfNome),
      );
    } else {
      // Su mobile/desktop possiamo leggere direttamente dal path
      request.files.add(
        await http.MultipartFile.fromPath('pdf', pdfFile!.path, filename: pdfNome),
      );
    }

    final streamed = await request.send().timeout(_timeoutLungo);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Errore analisi estratto conto (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    // Strapi a volte wrappa la risposta in { data, meta } — qui il controller
    // ritorna direttamente il report, ma gestiamo entrambi i casi.
    final json = body is Map && body['data'] != null ? body['data'] : body;
    return ReportAnalisi.fromJson(json);
  }
}
