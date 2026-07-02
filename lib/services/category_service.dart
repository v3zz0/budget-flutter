import 'dart:convert';
import '../config.dart';
import '../models/category.dart';
import 'api_client.dart';

class CategoryService {
  Future<void> updateCategory(String token, String documentId, String nome, double budget, {String? icona}) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/categories/$documentId');
    final data = <String, dynamic>{'Nome': nome, 'Budget_categoria': budget};
    if (icona != null) data['icona'] = icona;
    final response = await ApiClient.put(url, token: token, body: jsonEncode({'data': data}));
    if (response.statusCode != 200) throw Exception('Errore aggiornamento categoria');
  }

  Future<void> deleteCategory(String token, String documentId) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/categories/$documentId');
    final response = await ApiClient.delete(url, token: token);
    if (response.statusCode != 200 && response.statusCode != 204) throw Exception('Errore eliminazione categoria');
  }

  Future<Category> createCategory(String token, String nome, double budget, String walletDocumentId, {String? icona}) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/categories');
    final data = <String, dynamic>{'Nome': nome, 'Budget_categoria': budget, 'wallet': walletDocumentId};
    if (icona != null && icona.isNotEmpty) data['icona'] = icona;
    final response = await ApiClient.post(url, token: token, body: jsonEncode({'data': data}));
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return Category.fromJson(body['data']);
    }
    throw Exception('Errore creazione categoria');
  }
}
