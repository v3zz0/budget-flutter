import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/dashboard_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/soglia_service.dart';
import '../widget/widget_bridge.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service = DashboardService();

  List<Category> _categorie = [];
  List<Transaction> _ricorrenti = [];
  bool isLoading = false;
  String? errore;

  // Navigazione mese — equivalente di meseCorrente/annoCorrente in Vue
  DateTime _meseScelto = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get meseScelto => _meseScelto;

  /// Categorie del portafoglio, ognuna con le sole transazioni di [meseScelto].
  /// Il filtro per mese lo fa il server: cambiare mese richiede un reload.
  List<Category> get categorie => _categorie;

  /// Alias storico di [categorie]. Il filtro client-side che faceva prima non
  /// serve più, ma i chiamanti sono tanti e il nome resta leggibile.
  List<Category> get categorieFiltrate => _categorie;

  /// Template ricorrenti del portafoglio, di qualunque mese.
  List<Transaction> get ricorrenti => _ricorrenti;

  // Totale spesi nel mese — equivalente di totaleSpesi computed in Vue
  double get totaleSpesi {
    return _categorie.fold(0, (sum, cat) {
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
      final dati = await _service.loadCategories(
        token,
        walletDocumentId,
        mese: _meseScelto,
      );
      _categorie = dati.categorie;
      _ricorrenti = dati.ricorrenti;
      // Pianifica notifiche per le ricorrenti con l'orario scelto.
      // In sequenza e non in parallelo: scheduleAll disdice gli ID pianificati
      // al giro precedente, e uno di quelli può essere un avviso di soglia
      // appena mostrato. Restano entrambi fuori dall'await di loadCategorie per
      // non rallentare la dashboard, ma in quest'ordine.
      NotificationService.scheduleAll(
        _ricorrenti,
        categorie: _categorie,
        walletId: walletDocumentId,
        orario: orarioNotifiche,
      ).then((_) => _avvisaSoglieSuperate());
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

  /// Cambia mese e ricarica.
  ///
  /// Il reload serve perché le transazioni ora le filtra il server: prima erano
  /// tutte in memoria e bastava cambiare la variabile. È il prezzo di non
  /// scaricare più lo storico intero a ogni apertura, e si paga una volta per
  /// tap sulle frecce invece che a ogni refresh.
  Future<void> cambiaMese(
    int passo,
    String token,
    String walletDocumentId, {
    TimeOfDay? orarioNotifiche,
  }) async {
    _meseScelto = DateTime(_meseScelto.year, _meseScelto.month + passo);
    notifyListeners();
    await loadCategorie(
      token,
      walletDocumentId,
      orarioNotifiche: orarioNotifiche,
    );
  }

  void reset() {
    _categorie = [];
    errore = null;
    _meseScelto = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }
}
