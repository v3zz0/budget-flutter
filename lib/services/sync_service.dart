import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'connectivity_service.dart';
import 'local_db.dart';
import 'transazione_service.dart';

/// Svuota il "quaderno" delle transazioni pendenti appena c'è la possibilità
/// di farlo. Non garantisce che tutte partano: se il server non risponde
/// (giù, in timeout) si ferma e ci riprova al prossimo giro — ogni
/// transazione rimasta nel quaderno viene ritentata più avanti, non persa.
class SyncService {
  static final TransazioneService _service = TransazioneService();

  // Evita due sincronizzazioni in corso insieme (es. l'app si riapre e la
  // rete torna nello stesso istante): la seconda chiamata esce subito.
  static bool _inCorso = false;

  static Future<void> sincronizza(String token) async {
    if (_inCorso) return;
    if (!await ConnectivityService.isOnline()) return;

    _inCorso = true;
    try {
      final pendenti = await LocalDb.elenca();
      for (final p in pendenti) {
        try {
          await _service.salvaTransazione(token, p.transazione);
          await LocalDb.rimuovi(p.clientUuid);
        } catch (e) {
          if (_erroreDiRete(e)) {
            // Il server non risponde: niente senso insistere sulle righe
            // successive in questo stesso giro, si riprova tutte insieme
            // al prossimo.
            return;
          }
          // Errore non di rete (es. categoria cancellata nel frattempo):
          // questa riga resta bloccata per sempre se non la togliamo, ma
          // provarla di nuovo non cambierebbe esito. Per ora si lascia nel
          // quaderno — un intervento manuale dall'app la toglierà quando
          // l'utente la rivede nella lista "in attesa".
        }
      }
    } finally {
      _inCorso = false;
    }
  }

  static bool _erroreDiRete(Object e) =>
      e is SocketException || e is TimeoutException || e is http.ClientException;
}
