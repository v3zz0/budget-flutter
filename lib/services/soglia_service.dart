import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';

/// Una categoria che ha superato la soglia di allerta nel mese in corso.
class CategoriaOltreSoglia {
  final Category categoria;
  final double speso;
  final double budget;

  const CategoriaOltreSoglia({
    required this.categoria,
    required this.speso,
    required this.budget,
  });

  /// 0.85 = 85% del budget. Può superare 1 se il budget è già sforato.
  double get percentuale => budget <= 0 ? 0 : speso / budget;

  bool get sforata => speso > budget;
}

/// Avvisi di superamento budget durante il mese.
///
/// I `consigli` generati dal cron lato server arrivano a fine mese, quando
/// ormai il mese è andato. Questo serve al momento opposto: dirti che sei
/// all'80% di una categoria mentre puoi ancora farci qualcosa.
///
/// Il calcolo è volutamente una funzione pura, così è testabile senza mock;
/// la parte con lo stato (quali categorie ho già segnalato) è separata.
class SogliaService {
  /// Percentuale oltre la quale scatta l'avviso.
  static const double sogliaPredefinita = 0.8;

  static const String _chiaveSoglia = 'soglia_percentuale';
  static const String _chiaveSegnalate = 'soglia_segnalate';

  /// La soglia è una preferenza del dispositivo, non del profilo: sta nelle
  /// SharedPreferences e non sul server, così non serve toccare lo schema
  /// utente di Strapi per una cosa che riguarda solo le notifiche locali.
  static Future<double> soglia() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_chiaveSoglia) ?? sogliaPredefinita;
  }

  static Future<void> salvaSoglia(double valore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_chiaveSoglia, valore);
  }

  /// Quanto è stato speso in [categoria] nel mese di [mese].
  static double spesoNelMese(Category categoria, DateTime mese) {
    return categoria.transazionis
        .where((t) => t.data.year == mese.year && t.data.month == mese.month)
        .fold(0.0, (somma, t) => somma + t.importo);
  }

  /// Categorie che nel mese di [mese] hanno superato [soglia].
  ///
  /// Le categorie senza budget vengono ignorate: senza un tetto non esiste una
  /// percentuale da superare, e segnalarle sarebbe solo rumore.
  static List<CategoriaOltreSoglia> oltreSoglia(
    List<Category> categorie, {
    required DateTime mese,
    double soglia = sogliaPredefinita,
  }) {
    final risultato = <CategoriaOltreSoglia>[];
    for (final c in categorie) {
      if (c.budgetCategoria <= 0) continue;
      final speso = spesoNelMese(c, mese);
      if (speso >= c.budgetCategoria * soglia) {
        risultato.add(
          CategoriaOltreSoglia(
            categoria: c,
            speso: speso,
            budget: c.budgetCategoria,
          ),
        );
      }
    }
    // Prima le più critiche.
    risultato.sort((a, b) => b.percentuale.compareTo(a.percentuale));
    return risultato;
  }

  /// Come [oltreSoglia], ma toglie quelle già segnalate in questo mese e
  /// registra le nuove — così una categoria avvisa una volta sola al mese
  /// invece che a ogni ricarica della dashboard.
  ///
  /// La memoria si azzera da sé: le chiavi contengono il mese, e a ogni giro
  /// si tengono solo quelle del mese corrente.
  static Future<List<CategoriaOltreSoglia>> nuoveDaSegnalare(
    List<Category> categorie, {
    DateTime? adesso,
    double? sogliaPersonalizzata,
  }) async {
    final mese = adesso ?? DateTime.now();
    final valore = sogliaPersonalizzata ?? await soglia();
    final candidate = oltreSoglia(categorie, mese: mese, soglia: valore);
    if (candidate.isEmpty) return const [];

    final prefs = await SharedPreferences.getInstance();
    final gia = prefs.getStringList(_chiaveSegnalate) ?? const <String>[];
    final etichettaMese = _etichettaMese(mese);

    // Si ripartono dalle sole chiavi di questo mese: quelle vecchie non
    // servono più e lasciarle farebbe crescere la lista all'infinito.
    final aggiornate = gia.where((k) => k.endsWith('|$etichettaMese')).toList();

    final nuove = <CategoriaOltreSoglia>[];
    for (final c in candidate) {
      final chiave = '${c.categoria.documentId}|$etichettaMese';
      if (aggiornate.contains(chiave)) continue;
      aggiornate.add(chiave);
      nuove.add(c);
    }

    await prefs.setStringList(_chiaveSegnalate, aggiornate);
    return nuove;
  }

  static String _etichettaMese(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Proiezione di fine mese sul ritmo di spesa tenuto finora.
  ///
  /// Estrapolazione lineare, niente di più: al giorno 3 vale poco, dal 10 in
  /// poi diventa un'indicazione onesta. Ritorna null quando non ha senso
  /// calcolarla (mese diverso da quello in corso, o nessuna spesa).
  static double? proiezioneFineMese({
    required double speso,
    required DateTime mese,
    DateTime? adesso,
  }) {
    final ora = adesso ?? DateTime.now();
    if (ora.year != mese.year || ora.month != mese.month) return null;
    if (speso <= 0) return null;

    final giorniTrascorsi = ora.day;
    final giorniTotali = DateTime(mese.year, mese.month + 1, 0).day;
    if (giorniTrascorsi >= giorniTotali) return speso;

    return speso / giorniTrascorsi * giorniTotali;
  }
}
