import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transazione_service.dart';
import '../services/api_client.dart';

class TransazioneProvider extends ChangeNotifier {
  final TransazioneService _service = TransazioneService();

  bool isLoading = false;
  String? errore;

  // Set degli ID in fase di eliminazione: protegge da tap multipli sul cestino.
  // Usiamo un Set perché l'utente potrebbe avviare cancellazioni su categorie
  // diverse contemporaneamente — ognuna disabilita solo la propria riga.
  final Set<String> _inEliminazione = {};
  bool isEliminando(String documentId) => _inEliminazione.contains(documentId);

  Future<bool> salva(String token, Transaction transazione) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      await _service.salvaTransazione(token, transazione);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> elimina(String token, String documentId) async {
    // Tap multiplo sullo stesso cestino: ignora le richieste successive
    if (_inEliminazione.contains(documentId)) return false;
    _inEliminazione.add(documentId);
    notifyListeners();

    try {
      await _service.eliminaTransazione(token, documentId);
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      return false;
    } finally {
      _inEliminazione.remove(documentId);
      notifyListeners();
    }
  }
}
