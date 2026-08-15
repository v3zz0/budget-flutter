import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';
import '../models/category.dart';
import 'ricorrenza.dart';

class NotificationService {
  /// Aggancia un orario a una data già decisa, nel fuso locale.
  static tz.TZDateTime _alleOre(DateTime giorno, TimeOfDay ora) =>
      tz.TZDateTime(
        tz.local,
        giorno.year,
        giorno.month,
        giorno.day,
        ora.hour,
        ora.minute,
      );

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

    final ora = orario ?? const TimeOfDay(hour: 9, minute: 0);

    // Il giorno lo decide Ricorrenza, che applica il clamp sui mesi corti.
    // Prima si costruiva la data a mano e un "31" a febbraio finiva al 3 marzo,
    // perché il costruttore normalizza lo sforamento invece di limitarlo.
    final now = tz.TZDateTime.now(tz.local);
    var scadenza = Ricorrenza.prossimaScadenza(transazione);
    var prossima = _alleOre(scadenza, ora);

    // La scadenza può essere oggi ma con l'orario già passato: in quel caso si
    // riparte dal giorno dopo per farsi dare l'occorrenza successiva.
    if (!prossima.isAfter(now)) {
      scadenza = Ricorrenza.prossimaScadenza(
        transazione,
        da: scadenza.add(const Duration(days: 1)),
      );
      prossima = _alleOre(scadenza, ora);
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
      // exact: con inexact + Doze Android rimanda la sveglia anche di ore/giorni.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // Ripete automaticamente ogni mese, stesso giorno.
      // ponytail: la PRIMA occorrenza ora è clampata bene da Ricorrenza, ma le
      // ripetizioni successive le gestisce il plugin, che sui mesi senza quel
      // giorno (31 a febbraio) salta o clampa a modo suo. Per il controllo
      // totale servirebbe ripianificare a mano ogni mese; ok così per ora.
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// Notifica immediata di prova: se non arriva, il problema sono i permessi
  /// (Android 13+ / batteria), non la pianificazione.
  /// Ritorna false se il permesso notifiche è negato.
  static Future<bool> test() async {
    if (_disabilitato) return false;
    await init();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final concesso = await androidImpl?.areNotificationsEnabled() ?? true;
    if (!concesso) return false;

    await _plugin.show(
      999999,
      'Notifiche attive',
      'Riceverai un avviso per ogni addebito ricorrente.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_recurring',
          'Transazioni ricorrenti',
          channelDescription: 'Notifiche per addebiti ricorrenti',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    return true;
  }

  /// Quante notifiche risultano effettivamente pianificate dal sistema.
  static Future<int> pianificate() async {
    if (_disabilitato) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
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
