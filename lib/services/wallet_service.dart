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

  Future<void> updateWallet(String token, String documentId, String nome, double budget) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/wallets/$documentId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({'data': {'Nome': nome, 'Budget': budget}}),
    );
    if (response.statusCode != 200) throw Exception('Errore aggiornamento wallet');
  }
}
