import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/dashboard_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/soglia_service.dart';
import '../widget/widget_bridge.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service = DashboardService();

  List<Category> _categorie = [];
  bool isLoading = false;
  String? errore;

  // Navigazione mese — equivalente di meseCorrente/annoCorrente in Vue
  DateTime _meseScelto = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get meseScelto => _meseScelto;

  // Tutte le categorie caricate (non filtrate per mese)
  List<Category> get categorie => _categorie;

  // Transazioni del mese selezionato per ogni categoria
  // Equivalente del computed categoriesFiltrate in Vue
  List<Category> get categorieFiltrate {
    return _categorie.map((cat) {
      final transazioniFiltrate = cat.transazionis.where((t) {
        return t.data.year == _meseScelto.year &&
               t.data.month == _meseScelto.month;
      }).toList();

      return Category(
        documentId: cat.documentId,
        nome: cat.nome,
        budgetCategoria: cat.budgetCategoria,
        walletDocumentId: cat.walletDocumentId,
        transazionis: transazioniFiltrate,
      );
    }).toList();
  }

  // Totale spesi nel mese — equivalente di totaleSpesi computed in Vue
  double get totaleSpesi {
    return categorieFiltrate.fold(0, (sum, cat) {
      final spesiCategoria = cat.transazionis.fold(0.0, (s, t) => s + t.importo);
      return sum + spesiCategoria;
    });
  }

  // Budget totale sommato da tutte le categorie
  double get totaleBudget {
    return _categorie.fold(0, (sum, cat) => sum + cat.budgetCategoria);
  }

  // Rimanente = budget - spesi (può essere negativo)
  double get totaleRimanente => totaleBudget - totaleSpesi;

  // Il nome del wallet serve solo al widget in home. Lo passa la dashboard, che
  // è l'unico punto che lo conosce; gli altri dieci chiamanti di loadCategorie
  // non devono preoccuparsene, perché il nome cambia solo quando cambia il
  // wallet e a quel punto la dashboard ricarica comunque.
  String _walletNome = '';

  Future<void> loadCategorie(
    String token,
    String walletDocumentId, {
    TimeOfDay? orarioNotifiche,
    String? walletNome,
  }) async {
    if (walletNome != null && walletNome.isNotEmpty) _walletNome = walletNome;
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      _categorie = await _service.loadCategories(token, walletDocumentId);
      // Pianifica notifiche per le ricorrenti con l'orario scelto.
      // L'avviso di soglia va DOPO, non in parallelo: scheduleAll comincia con
      // un cancelAll() che spazzerebbe via l'avviso appena mostrato. Restano
      // entrambi fuori dall'await di loadCategorie per non rallentare la
      // dashboard, ma in quest'ordine.
      NotificationService.scheduleAll(_categorie, orario: orarioNotifiche)
          .then((_) => _avvisaSoglieSuperate());
      _aggiornaWidget(walletDocumentId);
    } catch (e) {
      errore = erroreLeggibile(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Notifica le categorie appena finite oltre soglia. Il servizio si occupa
  /// da sé di non ripetere l'avviso per la stessa categoria nello stesso mese.
  Future<void> _avvisaSoglieSuperate() async {
    final nuove = await SogliaService.nuoveDaSegnalare(_categorie);
    for (final c in nuove) {
      await NotificationService.avvisoSoglia(
        c.categoria.nome,
        c.speso,
        c.budget,
      );
    }
  }

  /// Spinge i totali al widget in home.
  ///
  /// Solo se si sta guardando il mese corrente: i totali seguono il mese
  /// selezionato, e navigando indietro a luglio il widget mostrerebbe i numeri
  /// di luglio spacciandoli per quelli di adesso.
  void _aggiornaWidget(String walletId) {
    final ora = DateTime.now();
    if (_meseScelto.year != ora.year || _meseScelto.month != ora.month) return;

    WidgetBridge.pushDaDashboard(
      walletId: walletId,
      walletNome: _walletNome,
      categorie: _categorie,
      mese: _meseScelto,
      budgetTotale: totaleBudget,
      speso: totaleSpesi,
      rimanente: totaleRimanente,
    );
  }

  /// Quanto si chiuderebbe il mese tenendo questo ritmo di spesa.
  /// null quando non ha senso mostrarla: mese passato/futuro o nessuna spesa.
  double? get proiezioneFineMese => SogliaService.proiezioneFineMese(
        speso: totaleSpesi,
        mese: _meseScelto,
      );

  /// La proiezione vale la pena mostrarla solo se sfora il budget e i giorni
  /// trascorsi sono abbastanza da renderla credibile.
  bool get proiezionePreoccupante {
    final p = proiezioneFineMese;
    if (p == null || totaleBudget <= 0) return false;
    return DateTime.now().day >= 7 && p > totaleBudget;
  }

  // Navigazione al mese precedente — equivalente del click su "<" in Vue
  void mesePrecedente() {
    _meseScelto = DateTime(_meseScelto.year, _meseScelto.month - 1);
    notifyListeners();
  }

  // Navigazione al mese successivo — equivalente del click su ">" in Vue
  void meseSuccessivo() {
    _meseScelto = DateTime(_meseScelto.year, _meseScelto.month + 1);
    notifyListeners();
  }

  void reset() {
    _categorie = [];
    errore = null;
    _meseScelto = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }
}
