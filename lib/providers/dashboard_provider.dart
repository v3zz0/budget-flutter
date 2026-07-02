import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/dashboard_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

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

  Future<void> loadCategorie(String token, String walletDocumentId, {TimeOfDay? orarioNotifiche}) async {
    isLoading = true;
    errore = null;
    notifyListeners();

    try {
      _categorie = await _service.loadCategories(token, walletDocumentId);
      // Pianifica notifiche per le ricorrenti con l'orario scelto
      NotificationService.scheduleAll(_categorie, orario: orarioNotifiche);
    } catch (e) {
      errore = erroreLeggibile(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
