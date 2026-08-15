import 'dart:convert';
import '../config.dart';
import '../models/transaction.dart';
import 'api_client.dart';

class TransazioneService {
  Future<void> salvaTransazione(String token, Transaction transazione) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/transazionis');
    final response = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode(transazione.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Errore nel salvataggio della transazione');
    }
  }

  /// Aggiorna una transazione esistente. Il body è lo stesso della creazione:
  /// Strapi accetta un update parziale, ma mandare tutti i campi evita
  /// sorprese quando si toglie una spunta (ricorrente, contanti) — un campo
  /// omesso resterebbe al valore vecchio invece di essere azzerato.
  Future<void> aggiornaTransazione(
    String token,
    String documentId,
    Transaction transazione,
  ) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/transazionis/$documentId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode(transazione.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Errore nell\'aggiornamento della transazione');
    }
  }

  Future<void> eliminaTransazione(String token, String documentId) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/transazionis/$documentId');
    final response = await ApiClient.delete(url, token: token);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Errore nell\'eliminazione della transazione');
    }
  }
}
