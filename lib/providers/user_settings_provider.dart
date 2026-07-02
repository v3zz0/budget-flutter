import 'package:flutter/material.dart';
import '../services/user_settings_service.dart';
import '../services/api_client.dart';

class UserSettingsProvider extends ChangeNotifier {
  final UserSettingsService _service = UserSettingsService();

  int? userId;
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
