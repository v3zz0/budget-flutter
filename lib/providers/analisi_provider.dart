import 'package:flutter/foundation.dart';
import '../models/report_analisi.dart';
import '../services/analisi_service.dart';
import '../services/api_client.dart';

// Provider per la schermata di analisi estratto conto.
// Supporta più documenti (PDF/CSV) analizzati insieme in un unico report.
class AnalisiProvider extends ChangeNotifier {
  final AnalisiService _service = AnalisiService();

  final List<AnalisiDoc> _docs = [];
  String? _meseSelezionato; // YYYY-MM
  bool _isLoading = false;
  String? _errore;
  ReportAnalisi? _report;

  List<AnalisiDoc> get docs => List.unmodifiable(_docs);
  String? get meseSelezionato => _meseSelezionato;
  bool get isLoading => _isLoading;
  String? get errore => _errore;
  ReportAnalisi? get report => _report;

  bool get hasDoc => _docs.isNotEmpty;
  bool get pronto => hasDoc && _meseSelezionato != null;

  void aggiungiDocs(List<AnalisiDoc> nuovi) {
    _docs.addAll(nuovi);
    _report = null;
    notifyListeners();
  }

  void rimuoviDoc(int index) {
    if (index >= 0 && index < _docs.length) {
      _docs.removeAt(index);
      _report = null;
      notifyListeners();
    }
  }

  void setMese(String mese) {
    _meseSelezionato = mese;
    _report = null;
    notifyListeners();
  }

  void reset() {
    _docs.clear();
    _meseSelezionato = null;
    _report = null;
    _errore = null;
    notifyListeners();
  }

  Future<void> analizza({required String token, required String walletId}) async {
    if (!pronto) {
      _errore = 'Seleziona almeno un documento e il mese prima di analizzare';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errore = null;
    _report = null;
    notifyListeners();

    try {
      _report = await _service.analizza(
        token: token,
        docs: _docs,
        walletId: walletId,
        mese: _meseSelezionato!,
      );
    } catch (e) {
      _errore = erroreLeggibile(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
