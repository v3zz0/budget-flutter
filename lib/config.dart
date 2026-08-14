import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const String _chiavePrefs = 'api_base_url';

  // Nessun indirizzo di default: lo scrive l'utente al primo login e resta
  // salvato sul telefono. Così l'APK gira sul server di chiunque, senza
  // ricompilare niente e senza avere un dominio privato scritto nel sorgente.
  // Si può comunque fissare alla build, per comodità in sviluppo:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:1337
  static const String _iniziale = String.fromEnvironment('API_BASE_URL');

  static String apiBaseUrl = _iniziale;

  /// Finché è vuoto non ha senso chiamare nessuna API.
  static bool get configurato => apiBaseUrl.isNotEmpty;

  /// Da chiamare in main() prima di runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final salvato = prefs.getString(_chiavePrefs);
    if (salvato != null && salvato.isNotEmpty) apiBaseUrl = salvato;
  }

  static Future<void> salvaUrl(String url) async {
    apiBaseUrl = normalizza(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiavePrefs, apiBaseUrl);
  }

  /// "budget.esempio.com/" -> "https://budget.esempio.com"
  /// Senza schema si assume https; un http:// scritto a mano viene rispettato.
  static String normalizza(String url) {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u;
  }
}
