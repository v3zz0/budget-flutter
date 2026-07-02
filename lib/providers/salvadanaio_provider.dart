import 'package:flutter/material.dart';
import '../models/salvadanaio.dart';
import '../services/salvadanaio_service.dart';
import '../services/api_client.dart';

class SalvadanaiProvider extends ChangeNotifier {
  final SalvadanaiService _service = SalvadanaiService();

  List<Salvadanaio> _voci = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errore;

  List<Salvadanaio> get voci => _voci;

  double get totaleStorico => _voci.fold(0, (sum, s) => sum + s.risparmiato);

  // Ultimo mese disponibile (mese precedente popolato dal cron Strapi)
  Salvadanaio? get mesePrecedente => _voci.isNotEmpty ? _voci.last : null;

  // Ultimi 6 mesi per il grafico
  List<Salvadanaio> get ultimi6Mesi => _voci.length > 6 ? _voci.sublist(_voci.length - 6) : _voci;

  // Record del mese corrente per il wallet (se esiste già)
  Salvadanaio? get meseCorrente {
    final now = DateTime.now();
    for (final v in _voci) {
      if (v.mese.year == now.year && v.mese.month == now.month) return v;
    }
    return null;
  }

  // Valore corrente del risparmio del mese (0 se non c'è ancora un record)
  double get risparmioMeseCorrente => meseCorrente?.risparmiato ?? 0;

  Future<void> loadSalvadanai(String token, String walletDocumentId) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      _voci = await _service.loadSalvadanai(token, walletDocumentId);
    } catch (e) {
      errore = erroreLeggibile(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Salva il risparmio del mese corrente per il wallet.
  // Se esiste già un record per (wallet, mese corrente) → update, altrimenti create.
  // Mantiene la lista locale aggiornata senza richiamare loadSalvadanai().
  Future<bool> salvaRisparmio(
    String token,
    String walletDocumentId,
    double importo,
  ) async {
    isSaving = true;
    errore = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      // ISO date "YYYY-MM-01" — chiave coerente con il cron Strapi
      final meseISO =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      final esistente = meseCorrente;
      if (esistente != null) {
        final aggiornato = await _service.updateRisparmiato(
          token,
          esistente.documentId,
          importo,
        );
        // Sostituzione in-place per evitare un round-trip in più
        final idx = _voci.indexWhere((v) => v.documentId == esistente.documentId);
        if (idx >= 0) _voci[idx] = aggiornato;
      } else {
        final creato = await _service.createSalvadanaio(
          token,
          walletDocumentId: walletDocumentId,
          mese: meseISO,
          risparmiato: importo,
        );
        _voci = [..._voci, creato]
          ..sort((a, b) => a.mese.compareTo(b.mese));
      }
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void reset() {
    _voci = [];
    errore = null;
    notifyListeners();
  }
}
