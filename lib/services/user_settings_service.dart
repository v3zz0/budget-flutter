import 'dart:convert';
import '../config.dart';
import 'api_client.dart';

class UserSettingsService {
  // GET /api/users/me — dati dell'utente loggato
  Future<Map<String, dynamic>> loadMe(String token) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/users/me');
    final response = await ApiClient.get(url, token: token);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Errore caricamento profilo utente');
  }

  // PUT /api/users/:id — aggiorna l'orario notifiche
  Future<void> updateOrarioNotifiche(String token, int userId, String orario) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/users/$userId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({'orarioNotifiche': orario}),
    );
    if (response.statusCode != 200) throw Exception('Errore aggiornamento orario notifiche');
  }
}
