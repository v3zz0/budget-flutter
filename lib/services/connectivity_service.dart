import 'package:connectivity_plus/connectivity_plus.dart';

/// Dice solo se il telefono ha una rete (Wi-Fi o dati mobili) attiva — non se
/// il server risponde davvero. È un controllo locale, istantaneo, che non
/// manda nessun dato in rete: serve solo a decidere QUANDO conviene provare
/// a inviare, il risultato vero lo dà sempre il tentativo di invio.
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    final risultati = await _connectivity.checkConnectivity();
    return !risultati.contains(ConnectivityResult.none);
  }

  static Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map((risultati) => !risultati.contains(ConnectivityResult.none));
}
