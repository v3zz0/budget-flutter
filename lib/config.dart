import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const String _chiavePrefs = 'api_base_url';

  // Valore di partenza. Si può ancora fissare alla build:
  //   flutter build apk --release --dart-define=API_BASE_URL=https://...
  // ma non serve più: l'indirizzo si cambia dalla schermata di login e resta
  // salvato sul telefono. Così l'APK gira anche a casa di qualcun altro, sul
  // suo server, senza ricompilare niente.
  static const String _iniziale = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://apibudget.vezzo.vp360web.com',
  );

  static String apiBaseUrl = _iniziale;

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

  /// "apibudget.esempio.com/" -> "https://apibudget.esempio.com"
  /// Senza schema si assume https; un http:// scritto a mano viene rispettato.
  static String normalizza(String url) {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) return _iniziale;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u;
  }
}
