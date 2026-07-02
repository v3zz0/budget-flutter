import 'dart:convert'; // equivalente di JSON.parse/stringify in JavaScript
import 'package:http/http.dart' as http; // equivalente di axios
import '../config.dart';

class AuthService {
  // login() è equivalente alla chiamata axios.post('/api/auth/local') in Vue
  // Restituisce il JWT come String se il login va a buon fine
  // Lancia un'eccezione con il messaggio di errore se fallisce
  Future<String> login(String email, String password) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/auth/local');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    // jsonDecode è equivalente di JSON.parse in JavaScript
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Strapi restituisce { jwt: '...', user: {...} }
      return data['jwt'];
    } else {
      // Strapi restituisce { error: { message: '...' } } in caso di errore
      final messaggio = data['error']?['message'] ?? 'Errore di login';
      throw Exception(messaggio);
    }
  }
}
