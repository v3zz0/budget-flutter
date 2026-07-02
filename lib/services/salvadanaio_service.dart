import 'dart:convert';
import '../config.dart';
import '../models/salvadanaio.dart';
import 'api_client.dart';

class SalvadanaiService {
  Future<List<Salvadanaio>> loadSalvadanai(String token, String walletDocumentId) async {
    final uri = Uri.parse('${Config.apiBaseUrl}/api/salvadanaios').replace(
      queryParameters: {
        'filters[wallet][documentId][\$eq]': walletDocumentId,
        'populate': 'wallet',
        'sort': 'mese:asc',
        'pagination[limit]': '24',
      },
    );

    final response = await ApiClient.get(uri, token: token);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['data'] ?? [];
      return items.map((item) => Salvadanaio.fromJson(item)).toList();
    }
    throw Exception('Errore nel caricamento del salvadanaio: ${response.statusCode}');
  }

  // Crea un nuovo record salvadanaio per (wallet, mese) con un certo risparmio.
  // `mese` è l'ISO date del primo giorno del mese (es. "2026-05-01").
  Future<Salvadanaio> createSalvadanaio(
    String token, {
    required String walletDocumentId,
    required String mese,
    required double risparmiato,
  }) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/salvadanaios');
    final response = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode({
        'data': {
          'wallet': walletDocumentId,
          'mese': mese,
          'risparmiato': risparmiato,
        },
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return Salvadanaio.fromJson(body['data']);
    }
    throw Exception('Errore creazione salvadanaio: ${response.statusCode}');
  }

  // Aggiorna il risparmio di un record esistente.
  Future<Salvadanaio> updateRisparmiato(
    String token,
    String documentId,
    double risparmiato,
  ) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/salvadanaios/$documentId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({
        'data': {'risparmiato': risparmiato},
      }),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Salvadanaio.fromJson(body['data']);
    }
    throw Exception('Errore aggiornamento salvadanaio: ${response.statusCode}');
  }
}
