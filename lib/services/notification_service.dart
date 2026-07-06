import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';
import '../models/category.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Il plugin flutter_local_notifications non supporta il web (genera
  // LateInitializationError sul campo _instance del platform interface).
  // Quando giriamo su web tutti i metodi diventano no-op.
  static bool get _disabilitato => kIsWeb;

  static Future<void> init() async {
    if (_disabilitato || _initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linux = LinuxInitializationSettings(defaultActionName: 'Apri');
    const settings = InitializationSettings(android: android, linux: linux);
    await _plugin.initialize(settings);

    // Richiesta permesso notifiche su Android 13+
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  // Pianifica una notifica per quando avviene un addebito ricorrente
  static Future<void> scheduleRicorrente(Transaction transazione, Category? categoria, {TimeOfDay? orario}) async {
    if (_disabilitato) return;

    // RicorrenzaTemporale spesso non è valorizzata (l'app non la invia in create):
    // usiamo la data della transazione come giorno-del-mese di riferimento.
    final base = transazione.ricorrenzaTemporale ?? transazione.data;
    final giorno = base.day;
    final ora = orario ?? const TimeOfDay(hour: 9, minute: 0);

    // Prossima occorrenza NEL FUTURO: stesso giorno del mese, all'orario scelto.
    final now = tz.TZDateTime.now(tz.local);
    var prossima = tz.TZDateTime(tz.local, now.year, now.month, giorno, ora.hour, ora.minute);
    if (!prossima.isAfter(now)) {
      // già passata questo mese → mese successivo (il costruttore normalizza mese 13→gennaio).
      prossima = tz.TZDateTime(tz.local, now.year, now.month + 1, giorno, ora.hour, ora.minute);
    }

    final categoriaNome = categoria?.nome ?? 'transazione';

    await _plugin.zonedSchedule(
      transazione.documentId.hashCode, // ID univoco
      'Addebito ricorrente',
      'Oggi ${transazione.importo.toStringAsFixed(2)}€ per $categoriaNome',
      prossima,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_recurring',
          'Transazioni ricorrenti',
          channelDescription: 'Notifiche per addebiti ricorrenti',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // Ripete automaticamente ogni mese, stesso giorno.
      // ponytail: per mesi senza quel giorno (es. 31 a febbraio) il plugin salta/clampa; ok per ora.
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  // Pianifica tutte le ricorrenti — chiamato dopo loadCategorie
  static Future<void> scheduleAll(List<Category> categorie, {TimeOfDay? orario}) async {
    if (_disabilitato) return;
    await _plugin.cancelAll();
    for (final cat in categorie) {
      for (final t in cat.transazionis) {
        // Basta il flag ricorrente: la data di riferimento la ricava
        // scheduleRicorrente (ricorrenzaTemporale ?? data).
        if (t.transazioneRicorrente) {
          await scheduleRicorrente(t, cat, orario: orario);
        }
      }
    }
  }
}
