import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/transazione_pendente.dart';
import '../services/connectivity_service.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';
import '../services/transazione_service.dart';
import '../services/api_client.dart';

/// Come è andato l'ultimo salva(): serve alla schermata per scegliere il
/// messaggio giusto (inviata subito, o salvata in locale in attesa di rete).
/// Un errore vero resta segnalato da [TransazioneProvider.errore] e da un
/// `salva()` che torna false, come prima.
enum EsitoSalvataggio { inviata, inAttesa }

class TransazioneProvider extends ChangeNotifier {
  final TransazioneService _service = TransazioneService();

  bool isLoading = false;
  String? errore;
  EsitoSalvataggio? ultimoEsito;

  // Set degli ID in fase di eliminazione: protegge da tap multipli sul cestino.
  // Usiamo un Set perché l'utente potrebbe avviare cancellazioni su categorie
  // diverse contemporaneamente — ognuna disabilita solo la propria riga.
  final Set<String> _inEliminazione = {};
  bool isEliminando(String documentId) => _inEliminazione.contains(documentId);

  // Transazioni create offline (o col server irraggiungibile), non ancora
  // arrivate a Strapi. Si vedono in home con l'etichetta "in attesa".
  List<TransazionePendente> pendenti = [];

  Future<void> caricaPendenti() async {
    pendenti = await LocalDb.elenca();
    notifyListeners();
  }

  bool _erroreDiRete(Object e) =>
      e is SocketException || e is TimeoutException || e is http.ClientException;

  Future<bool> salva(String token, Transaction transazione) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    final clientUuid = transazione.clientUuid ?? const Uuid().v4();
    final daInviare = transazione.conClientUuid(clientUuid);

    final online = await ConnectivityService.isOnline();
    if (online) {
      try {
        await _service.salvaTransazione(token, daInviare);
        ultimoEsito = EsitoSalvataggio.inviata;
        isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        if (!_erroreDiRete(e)) {
          errore = erroreLeggibile(e);
          isLoading = false;
          notifyListeners();
          return false;
        }
        // Rete che sembrava su ma la richiesta non è passata (timeout,
        // connessione persa a metà): stesso trattamento dell'offline, sotto.
      }
    }

    await LocalDb.salva(TransazionePendente(
      clientUuid: clientUuid,
      transazione: daInviare,
      creataIl: DateTime.now(),
    ));
    await caricaPendenti();
    ultimoEsito = EsitoSalvataggio.inAttesa;
    isLoading = false;
    notifyListeners();
    return true;
  }

  /// Riprova a mandare le transazioni pendenti. Da chiamare quando la rete
  /// torna, o manualmente dal banner "in attesa" in home.
  Future<void> sincronizzaPendenti(String token) async {
    await SyncService.sincronizza(token);
    await caricaPendenti();
  }

  Future<bool> aggiorna(
    String token,
    String documentId,
    Transaction transazione,
  ) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      await _service.aggiornaTransazione(token, documentId, transazione);
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
