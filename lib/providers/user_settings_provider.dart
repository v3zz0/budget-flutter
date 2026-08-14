import 'package:flutter/material.dart';
import '../services/user_settings_service.dart';
import '../services/api_client.dart';

class UserSettingsProvider extends ChangeNotifier {
  final UserSettingsService _service = UserSettingsService();

  int? userId;
  String username = '';
  String email = '';
  TimeOfDay? orarioNotifiche;
  bool isLoading = false;
  String? errore;

  Future<void> load(String token) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      final data = await _service.loadMe(token);
      userId = data['id'];
      username = data['username'] ?? '';
      email = data['email'] ?? '';
      final orario = data['orarioNotifiche'] as String?;
      if (orario != null && orario.isNotEmpty) {
        // Strapi ritorna formato "HH:MM:SS.000"
        final parts = orario.split(':');
        orarioNotifiche = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } else {
        orarioNotifiche = const TimeOfDay(hour: 9, minute: 0);
      }
    } catch (e) {
      errore = erroreLeggibile(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Ritornano null se ok, altrimenti il messaggio d'errore da mostrare.
  Future<String?> updateProfilo(String token, String nuovoUsername, String nuovaEmail) async {
    if (userId == null) return 'Utente non caricato';
    try {
      await _service.updateProfilo(token, userId!, username: nuovoUsername, email: nuovaEmail);
      username = nuovoUsername;
      email = nuovaEmail;
      notifyListeners();
      return null;
    } catch (e) {
      return erroreLeggibile(e);
    }
  }

  Future<String?> cambiaPassword(String token, String attuale, String nuova) async {
    try {
      await _service.cambiaPassword(token, attuale, nuova);
      return null;
    } catch (e) {
      return erroreLeggibile(e);
    }
  }

  Future<bool> updateOrario(String token, TimeOfDay nuovo) async {
    if (userId == null) return false;
    final str = '${nuovo.hour.toString().padLeft(2, '0')}:${nuovo.minute.toString().padLeft(2, '0')}:00.000';
    try {
      await _service.updateOrarioNotifiche(token, userId!, str);
      orarioNotifiche = nuovo;
      notifyListeners();
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }
}
