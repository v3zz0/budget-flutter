import 'package:flutter/foundation.dart'; // contiene ChangeNotifier
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

// ChangeNotifier è la base di Provider — equivalente di defineStore() in Pinia
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _token; // null = non loggato
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errore;
  bool _biometriaAbilitata = false;

  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errore => _errore;
  bool get biometriaAbilitata => _biometriaAbilitata;

  // init() — all'avvio: legge il flag biometria e l'eventuale JWT salvato.
  Future<void> init() async {
    _biometriaAbilitata =
        (await _secureStorage.read(key: 'bio_enabled')) == 'true';
    final tokenSalvato = await _secureStorage.read(key: 'jwt');
    if (tokenSalvato != null) {
      _token = tokenSalvato;
      _isLoggedIn = true;
    }
    notifyListeners();
  }

  // login() con email+password — action classica.
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errore = null;
    notifyListeners();

    try {
      final jwt = await _authService.login(email, password);
      await _secureStorage.write(key: 'jwt', value: jwt);
      _token = jwt;
      _isLoggedIn = true;
    } catch (e) {
      _errore = erroreLeggibile(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Attiva il login biometrico salvando le credenziali (cifrate dal Keystore).
  // Va chiamato dopo un login con password andato a buon fine.
  Future<void> abilitaBiometria(String email, String password) async {
    await _secureStorage.write(key: 'bio_email', value: email);
    await _secureStorage.write(key: 'bio_password', value: password);
    await _secureStorage.write(key: 'bio_enabled', value: 'true');
    _biometriaAbilitata = true;
    notifyListeners();
  }

  // Disattiva il login biometrico e cancella le credenziali salvate.
  Future<void> disabilitaBiometria() async {
    await _secureStorage.delete(key: 'bio_email');
    await _secureStorage.delete(key: 'bio_password');
    await _secureStorage.delete(key: 'bio_enabled');
    _biometriaAbilitata = false;
    notifyListeners();
  }

  // Rifà il login usando le credenziali salvate (dopo che l'impronta è OK).
  // Ritorna true se il login è riuscito.
  Future<bool> loginConBiometria() async {
    final email = await _secureStorage.read(key: 'bio_email');
    final password = await _secureStorage.read(key: 'bio_password');
    if (email == null || password == null) return false;

    _isLoading = true;
    _errore = null;
    notifyListeners();

    try {
      final jwt = await _authService.login(email, password);
      await _secureStorage.write(key: 'jwt', value: jwt);
      _token = jwt;
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _errore = erroreLeggibile(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // logout() — cancella la sessione (JWT) ma MANTIENE le credenziali biometriche,
  // così al prossimo accesso puoi rientrare con l'impronta. Per rimuoverle del
  // tutto usa disabilitaBiometria() (toggle in Impostazioni).
  Future<void> logout() async {
    await _secureStorage.delete(key: 'jwt');
    _token = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
