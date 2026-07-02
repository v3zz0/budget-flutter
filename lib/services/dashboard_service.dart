import 'dart:convert';
import '../config.dart';
import '../models/category.dart';
import 'api_client.dart';

class DashboardService {
  Future<List<Category>> loadCategories(String token, String walletDocumentId) async {
    final uri = Uri.parse('${Config.apiBaseUrl}/api/categories').replace(
      queryParameters: {
        'filters[wallet][documentId][\$eq]': walletDocumentId,
        'populate': '*',
        'pagination[limit]': '100',
      },
    );

    final response = await ApiClient.get(uri, token: token);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['data'] ?? [];
      return items.map((item) => Category.fromJson(item)).toList();
    }
    throw Exception('Errore nel caricamento delle categorie: ${response.statusCode}');
  }
}
