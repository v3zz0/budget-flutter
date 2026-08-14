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

  // PUT /api/users/:id — aggiorna nome utente ed email
  Future<void> updateProfilo(String token, int userId, {required String username, required String email}) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/users/$userId');
    final response = await ApiClient.put(
      url,
      token: token,
      body: jsonEncode({'username': username, 'email': email}),
    );
    if (response.statusCode != 200) {
      // Strapi risponde 400 con il motivo (email già usata, formato non valido…)
      throw Exception(_messaggioErrore(response.body) ?? 'Errore aggiornamento profilo');
    }
  }

  // POST /api/auth/change-password — endpoint standard users-permissions
  Future<void> cambiaPassword(String token, String attuale, String nuova) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/auth/change-password');
    final response = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode({
        'currentPassword': attuale,
        'password': nuova,
        'passwordConfirmation': nuova,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_messaggioErrore(response.body) ?? 'Errore cambio password');
    }
  }

  // Estrae il messaggio dall'errore Strapi { error: { message } }
  String? _messaggioErrore(String body) {
    try {
      return jsonDecode(body)['error']?['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}
