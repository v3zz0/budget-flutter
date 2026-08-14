import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/report_analisi.dart';
import '../services/analisi_service.dart';
import '../services/api_client.dart';
import '../services/gemma_locale_service.dart';

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

  // Vero mentre il modello sul telefono sta generando categorie e giudizio.
  bool _generandoInLocale = false;
  bool get generandoInLocale => _generandoInLocale;

  Future<void> analizza({
    required String token,
    required String walletId,
    List<String> nomiCategorie = const [],
  }) async {
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

      // Motore "sul telefono": il server ha mandato i numeri, categorie e
      // giudizio li scrive il modello locale.
      if (_report!.aiSulTelefono) {
        _isLoading = false;
        _generandoInLocale = true;
        notifyListeners();
        _report = await _completaInLocale(_report!, nomiCategorie);
      }
    } catch (e) {
      _errore = erroreLeggibile(e);
    } finally {
      _isLoading = false;
      _generandoInLocale = false;
      notifyListeners();
    }
  }

  /// Categorie e giudizio con Gemma sul dispositivo. Se il modello non è
  /// installato o fallisce, il report resta valido: mancano solo i commenti.
  Future<ReportAnalisi> _completaInLocale(
    ReportAnalisi report,
    List<String> nomiCategorie,
  ) async {
    var risultato = report;

    if (report.mancanti.isNotEmpty && nomiCategorie.isNotEmpty) {
      final elenco = report.mancanti
          .asMap()
          .entries
          .map((e) => '${e.key}: ${e.value.descrizione}')
          .join('\n');
      final categorie = await _jsonDaGemma(
        'Associa ogni movimento bancario alla categoria di spesa piu\' probabile.\n\n'
        'Categorie disponibili: ${nomiCategorie.join(', ')}\n\n'
        'Movimenti:\n$elenco\n\n'
        'Rispondi SOLO con JSON: { "categorie": [ { "i": 0, "categoria": "Spesa" } ] }\n'
        'Usa il nome ESATTO di una categoria, oppure "Altro".',
      );
      if (categorie != null) {
        final perIndice = {
          for (final c in (categorie['categorie'] as List? ?? []))
            (c['i'] as num?)?.toInt() ?? -1: c['categoria']?.toString(),
        };
        risultato = risultato.copyWith(
          mancanti: [
            for (var i = 0; i < report.mancanti.length; i++)
              report.mancanti[i].conCategoria(perIndice[i]),
          ],
        );
      }
    }

    final giudizio = await _jsonDaGemma(
      'Sei un assistente finanziario personale. Analizza il mese ${report.mese} '
      'e genera un giudizio SINTETICO (max 3 frasi) in italiano.\n\n'
      'Budget totale: ${report.totale.budget}€\n'
      'Speso totale: ${report.totale.speso}€\n'
      'Categorie sforate: ${report.sforamenti.where((s) => s.sforato).map((s) => s.nome).join(', ')}\n'
      'Transazioni in banca non registrate nell\'app: ${report.mancanti.length}\n\n'
      'Tono diretto e amichevole, niente preamboli.\n'
      'Rispondi con JSON: { "giudizio": "testo qui" }',
    );
    if (giudizio != null) {
      risultato = risultato.copyWith(giudizio: giudizio['giudizio']?.toString());
    }

    return risultato;
  }

  Future<Map<String, dynamic>?> _jsonDaGemma(String prompt) async {
    try {
      final raw = await GemmaLocaleService.chiedi(prompt);
      // I modelli piccoli a volte incorniciano il JSON con del testo:
      // si tiene solo dalla prima graffa all'ultima.
      final da = raw.indexOf('{');
      final a = raw.lastIndexOf('}');
      if (da < 0 || a <= da) return null;
      return jsonDecode(raw.substring(da, a + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemma locale non disponibile: $e');
      return null;
    }
  }
}
