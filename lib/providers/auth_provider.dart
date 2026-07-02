import 'package:flutter/foundation.dart'; // contiene ChangeNotifier
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

// ChangeNotifier è la base di Provider — equivalente di defineStore() in Pinia
// Quando chiami notifyListeners(), tutti i widget che ascoltano si ricostruiscono
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Stato privato — equivalente di state: {} in Pinia
  String? _token; // null = non loggato
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errore;

  // Getter pubblici — equivalente dei getter in Pinia
  // I widget leggono questi valori ma non possono modificarli direttamente
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errore => _errore;

  // init() — chiamato all'avvio dell'app
  // Controlla se c'è già un JWT salvato in secure storage
  // Equivalente del controllo localStorage al mount dell'app in Vue
  Future<void> init() async {
    final tokenSalvato = await _secureStorage.read(key: 'jwt');
    if (tokenSalvato != null) {
      _token = tokenSalvato;
      _isLoggedIn = true;
      notifyListeners(); // avvisa i widget che lo stato è cambiato
    }
  }

  // login() — equivalente dell'action login() in Pinia
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errore = null;
    notifyListeners();

    try {
      // Chiama AuthService — separazione responsabilità come in Vue
      final jwt = await _authService.login(email, password);

      // Salva il JWT in modo sicuro — equivalente di localStorage.setItem()
      await _secureStorage.write(key: 'jwt', value: jwt);

      _token = jwt;
      _isLoggedIn = true;
    } catch (e) {
      _errore = erroreLeggibile(e);
    } finally {
      // finally funziona identico a JavaScript
      _isLoading = false;
      notifyListeners();
    }
  }

  // logout() — equivalente dell'action logout() in Pinia
  Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt');
    _token = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
