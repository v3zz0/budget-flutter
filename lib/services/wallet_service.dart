import 'dart:convert';
import '../config.dart';
import '../models/wallet.dart';
import 'api_client.dart';

class WalletService {
  Future<List<Wallet>> loadWallets(String token, {int? userId}) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets').replace(
      queryParameters: userId != null
          ? {'filters[users_permissions_user][id][\$eq]': userId.toString()}
          : null,
    );
    final response = await ApiClient.get(url, token: token);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['data'];
      return items.map((item) => Wallet.fromJson(item)).toList();
    }
    throw Exception('Errore nel caricamento dei wallet');
  }

  /// Aggiorna il solo flag di esclusione dalle statistiche.
  /// Separato da updateWallet perché è un toggle: mandare anche nome e budget
  /// significherebbe riscriverli con quello che l'app ha in memoria, che può
  /// essere vecchio.
  Future<void> aggiornaEsclusione(
    String token,
    String documentId,
    bool escluso,
  ) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets/$documentId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({'data': {'escludiDaStatistiche': escluso}}),
    );
    if (response.statusCode != 200) {
      throw Exception('Errore aggiornamento esclusione wallet');
    }
  }

  Future<void> updateWallet(String token, String documentId, String nome, double budget) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets/$documentId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({'data': {'Nome': nome, 'Budget': budget}}),
    );
    if (response.statusCode != 200) throw Exception('Errore aggiornamento wallet');
  }

  /// Il proprietario lo mette il server (controller `wallet.create`): qui non
  /// si manda, e se lo si mandasse verrebbe ignorato.
  Future<Wallet> createWallet(String token, String nome, double budget) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets');
    final response = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode({'data': {'Nome': nome, 'Budget': budget}}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Wallet.fromJson(jsonDecode(response.body)['data']);
    }
    throw Exception('Errore creazione portafoglio');
  }

  Future<void> deleteWallet(String token, String documentId) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets/$documentId');
    final response = await ApiClient.delete(url, token: token);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Errore eliminazione portafoglio');
    }
  }
}
