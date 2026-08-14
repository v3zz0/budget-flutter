import 'package:flutter/foundation.dart';
import '../models/consiglio.dart';
import '../services/api_client.dart';
import '../services/consiglio_service.dart';

class ConsigliProvider extends ChangeNotifier {
  final ConsiglioService _service = ConsiglioService();

  List<Consiglio> _consigli = [];
  bool _isLoading = false;
  String? _errore;

  List<Consiglio> get consigli => List.unmodifiable(_consigli);
  bool get isLoading => _isLoading;
  String? get errore => _errore;

  /// Quanti pallini rossi mostrare sulla campanella.
  int get nonLetti => _consigli.where((c) => c.isNuovo).length;

  Future<void> carica(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      _consigli = await _service.carica(token);
      _errore = null;
    } catch (e) {
      // Un errore sui consigli non deve rovinare la home: si mostra la lista
      // vuota e nessuna campanella.
      _errore = erroreLeggibile(e);
      _consigli = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applica il consiglio e lo toglie dalla lista.
  Future<bool> applica(String token, Consiglio c) async {
    try {
      await _service.applica(token, c.documentId);
      _consigli.removeWhere((x) => x.documentId == c.documentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> ignora(String token, Consiglio c) async {
    try {
      await _service.segna(token, c.documentId, 'ignorato');
      _consigli.removeWhere((x) => x.documentId == c.documentId);
      notifyListeners();
    } catch (e) {
      _errore = erroreLeggibile(e);
      notifyListeners();
    }
  }

  /// Spegne il pallino: i consigli restano, ma non sono più "nuovi".
  Future<void> segnaTuttiLetti(String token) async {
    final nuovi = _consigli.where((c) => c.isNuovo).toList();
    if (nuovi.isEmpty) return;
    for (final c in nuovi) {
      try {
        await _service.segna(token, c.documentId, 'letto');
      } catch (_) {
        // Se una chiamata fallisce pazienza: il pallino resta acceso.
      }
    }
    await carica(token);
  }
}
