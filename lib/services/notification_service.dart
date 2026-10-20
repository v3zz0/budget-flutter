import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // alarmClock: stesso meccanismo della sveglia di sistema. Con
      // exactAllowWhileIdle, su telefoni con gestione batteria aggressiva
      // (Samsung compreso) la sveglia può non suonare proprio, non solo in
      // ritardo — Android protegge le sveglie vere molto più delle notifiche
      // pianificate dalle app, quindi vale la rinuncia a essere "discreti".
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // Ripete automaticamente ogni mese, stesso giorno.
      // ponytail: la PRIMA occorrenza ora è clampata bene da Ricorrenza, ma le
      // ripetizioni successive le gestisce il plugin, che sui mesi senza quel
      // giorno (31 a febbraio) salta o clampa a modo suo. Per il controllo
      // totale servirebbe ripianificare a mano ogni mese; ok così per ora.
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// Avviso immediato di superamento soglia su una categoria.
  ///
  /// È immediata e non pianificata: il momento in cui serve è quello in cui la
  /// spesa viene registrata, non un orario prestabilito.
  static Future<void> avvisoSoglia(
    String categoria,
    double speso,
    double budget,
  ) async {
    if (_disabilitato) return;
    await init();

    final percentuale = budget <= 0 ? 0 : (speso / budget * 100).round();
    final sforata = speso > budget;

    await _plugin.show(
      // ID derivato dal nome: un secondo avviso sulla stessa categoria
      // sostituisce il precedente invece di impilarsi.
      'soglia_$categoria'.hashCode,
      sforata ? 'Budget superato: $categoria' : 'Attenzione a $categoria',
      sforata
          ? 'Hai speso ${speso.toStringAsFixed(2)}€ sui ${budget.toStringAsFixed(2)}€ di budget.'
          : 'Sei al $percentuale% del budget di $categoria (${speso.toStringAsFixed(2)}€ su ${budget.toStringAsFixed(2)}€).',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_soglie',
          'Soglie di budget',
          channelDescription:
              'Avvisi quando una categoria si avvicina al suo budget',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
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

  // Deve combaciare con applicationId in android/app/build.gradle.kts.
  static const _nomePacchetto = 'com.vezzo.budget_flutter';

  /// Apre il dialogo di sistema per escludere l'app dall'ottimizzazione
  /// batteria. È la causa più diretta, su molti telefoni (Samsung compreso),
  /// per cui una sveglia pianificata non suona mai: Android mette l'app a
  /// dormire e con essa le sveglie che aveva impostato.
  static Future<void> richiediEsclusioneBatteria() async {
    if (_disabilitato) return;
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_nomePacchetto',
      ).launch();
    } catch (_) {
      // Alcuni produttori non supportano questo intent diretto: si ripiega
      // sulla pagina info dell'app, da cui si arriva comunque a mano alle
      // impostazioni batteria.
      await apriImpostazioniApp();
    }
  }

  /// Pagina "Info app" di sistema — punto di partenza manuale per le
  /// impostazioni batteria quando il dialogo diretto non è disponibile.
  static Future<void> apriImpostazioniApp() async {
    if (_disabilitato) return;
    await const AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$_nomePacchetto',
    ).launch();
  }

  /// Chiave sotto cui teniamo gli ID pianificati per ciascun portafoglio.
  static const String _chiavePianificate = 'notifiche_pianificate';

  /// Pianifica le ricorrenti di UN portafoglio — chiamato dopo loadCategorie.
  ///
  /// Cancella solo le notifiche di questo portafoglio, non tutte. Prima qui
  /// c'era `cancelAll()`: con due portafogli, aprirne uno spazzava via le
  /// ricorrenti dell'altro, e nessuno le ripianificava finché non lo si
  /// riapriva a mano. Con un portafoglio solo il bug era invisibile.
  ///
  /// Gli ID di ogni giro restano nelle preferenze, così al giro dopo si sa cosa
  /// disdire: serve anche a togliere le notifiche di una ricorrente cancellata
  /// o a cui è stata tolta la spunta.
  static Future<void> scheduleAll(
    List<Transaction> ricorrenti, {
    required List<Category> categorie,
    required String walletId,
    TimeOfDay? orario,
  }) async {
    if (_disabilitato) return;

    final prefs = await SharedPreferences.getInstance();
    final chiave = '$_chiavePianificate:$walletId';

    for (final id in prefs.getStringList(chiave) ?? const <String>[]) {
      final n = int.tryParse(id);
      if (n != null) await _plugin.cancel(n);
    }

    // I template arrivano già filtrati dal server; qui serve solo il nome della
    // categoria per il testo della notifica.
    final perId = {for (final c in categorie) c.documentId: c};

    final pianificati = <String>[];
    for (final t in ricorrenti) {
      await scheduleRicorrente(t, perId[t.categoriaDocumentId], orario: orario);
      pianificati.add(t.documentId.hashCode.toString());
    }
    await prefs.setStringList(chiave, pianificati);
  }
}
