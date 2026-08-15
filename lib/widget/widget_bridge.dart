import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:home_widget/home_widget.dart';

import '../models/category.dart';
import 'widget_snapshot.dart';

/// Ponte fra l'app e il widget in home.
///
/// Il widget non può chiamare le API: gira in un BroadcastReceiver, senza rete
/// e con pochi millisecondi di budget. Quindi è l'app a spingergli i numeri già
/// pronti ogni volta che ne ha di nuovi (modello push, app → widget).
///
/// Fuori da Android è tutto no-op, stessa convenzione del guard kIsWeb in
/// NotificationService.
class WidgetBridge {
  /// Nome completo della classe del receiver: deve combaciare con
  /// android:name del manifest, risolto rispetto al package.
  static const String _providerAndroid =
      'com.vezzo.budget_flutter.widget.BudgetWidgetProvider';

  /// Chiave sotto cui il Kotlin va a leggere lo snapshot.
  static const String chiaveSnapshot = 'snapshot';

  /// Quante scorciatoie mostra il widget. Il layout ne prevede quattro; oltre
  /// non ci starebbero senza diventare illeggibili.
  static const int maxSlot = 4;

  static bool get _disabilitato {
    if (kIsWeb) return true;
    return !Platform.isAndroid;
  }

  /// Scrive lo snapshot e chiede al sistema di ridisegnare il widget.
  /// Non lancia mai: un widget che non si aggiorna è un fastidio, un'eccezione
  /// che risale fino a chi salvava una transazione è un bug.
  static Future<void> push(WidgetSnapshot snapshot) async {
    if (_disabilitato) return;
    try {
      await HomeWidget.saveWidgetData<String>(
        chiaveSnapshot,
        snapshot.encode(),
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _providerAndroid);
    } catch (e) {
      debugPrint('WidgetBridge: aggiornamento widget fallito ($e)');
    }
  }

  /// Snapshot costruito dai dati della dashboard.
  ///
  /// Gli slot sono le categorie con il budget più alto: in mancanza di una
  /// configurazione esplicita (che arriverà con la schermata dedicata) sono
  /// la scelta meno arbitraria, perché sono quelle su cui si spende di più.
  static Future<void> pushDaDashboard({
    required String walletId,
    required String walletNome,
    required List<Category> categorie,
    required DateTime mese,
    required double budgetTotale,
    required double speso,
    required double rimanente,
  }) async {
    if (_disabilitato) return;

    final ordinate = [...categorie]
      ..sort((a, b) => b.budgetCategoria.compareTo(a.budgetCategoria));

    final slots = ordinate
        .take(maxSlot)
        .map(
          (c) => SlotWidget(
            categoriaId: c.documentId,
            nome: c.nome,
            icona: c.icona,
          ),
        )
        .toList();

    await push(
      WidgetSnapshot(
        walletId: walletId,
        walletNome: walletNome,
        budgetTotale: budgetTotale,
        speso: speso,
        rimanente: rimanente,
        mese:
            '${mese.year}-${mese.month.toString().padLeft(2, '0')}',
        aggiornatoAt: DateTime.now().millisecondsSinceEpoch,
        stato: StatoWidget.ok,
        slots: slots,
      ),
    );
  }

  /// Sessione finita: il widget deve smettere di mostrare numeri di cui non
  /// può più garantire la freschezza, e invitare ad accedere.
  static Future<void> pushSessioneChiusa() async {
    if (_disabilitato) return;
    await push(
      WidgetSnapshot.vuoto(
        StatoWidget.noAuth,
        adesso: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
