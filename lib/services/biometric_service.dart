import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// Wrapper attorno a local_auth: mostra il BiometricPrompt di sistema.
// Su Samsung usa lo stesso sensore d'impronta tramite le API standard Android
// (non serve nessuna "API Samsung" proprietaria).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Il dispositivo supporta la biometria ED ha almeno un'impronta/volto
  // registrati? Se no, non ha senso proporre il login biometrico.
  static Future<bool> disponibile() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final puo = await _auth.canCheckBiometrics;
      final registrate = await _auth.getAvailableBiometrics();
      return puo && registrate.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  // Mostra il prompt impronta. Ritorna true solo se l'autenticazione riesce.
  // biometricOnly: true → nel prompt NON compare il PIN di sistema; se l'utente
  // annulla o fallisce, torniamo al form utente+password (fallback app-level).
  static Future<bool> autentica({
    String motivo = 'Accedi a BudgetApp con l\'impronta',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
