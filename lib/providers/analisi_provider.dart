import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/report_analisi.dart';
import '../services/analisi_service.dart';
import '../services/api_client.dart';

// Provider per la schermata di analisi estratto conto
// Compatibile sia mobile (File) sia web (bytes), perché file_picker su Web
// non espone `path` ma solo `bytes`.
class AnalisiProvider extends ChangeNotifier {
  final AnalisiService _service = AnalisiService();

  // Su mobile/desktop usiamo File. Su web usiamo bytes.
  File? _pdfFile;
  Uint8List? _pdfBytes;
  String? _pdfNome;

  String? _meseSelezionato; // YYYY-MM
  bool _isLoading = false;
  String? _errore;
  ReportAnalisi? _report;

  File? get pdfFile => _pdfFile;
  Uint8List? get pdfBytes => _pdfBytes;
  String? get pdfNome => _pdfNome;
  String? get meseSelezionato => _meseSelezionato;
  bool get isLoading => _isLoading;
  String? get errore => _errore;
  ReportAnalisi? get report => _report;

  bool get hasPdf => _pdfFile != null || _pdfBytes != null;
  bool get pronto => hasPdf && _meseSelezionato != null;

  void setPdfFile(File file, String nome) {
    _pdfFile = file;
    _pdfBytes = null;
    _pdfNome = nome;
    _report = null;
    notifyListeners();
  }

  void setPdfBytes(Uint8List bytes, String nome) {
    _pdfBytes = bytes;
    _pdfFile = null;
    _pdfNome = nome;
    _report = null;
    notifyListeners();
  }

  void setMese(String mese) {
    _meseSelezionato = mese;
    _report = null;
    notifyListeners();
  }

  void reset() {
    _pdfFile = null;
    _pdfBytes = null;
    _pdfNome = null;
    _meseSelezionato = null;
    _report = null;
    _errore = null;
    notifyListeners();
  }

  Future<void> analizza({required String token, required String walletId}) async {
    if (!hasPdf || _meseSelezionato == null) {
      _errore = 'Seleziona PDF e mese prima di analizzare';
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
        pdfFile: _pdfFile,
        pdfBytes: _pdfBytes,
        pdfNome: _pdfNome ?? 'estratto.pdf',
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
