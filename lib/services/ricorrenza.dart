import '../models/transaction.dart';

/// Calcolo della prossima scadenza di una transazione ricorrente.
///
/// Sta qui e non dentro NotificationService perché serve in due posti: la
/// pianificazione delle notifiche e la schermata delle ricorrenti. Tenerlo in
/// un solo punto evita che le due divergano — e lo rende testabile, visto che
/// sono funzioni pure senza plugin di mezzo.
///
/// La regola replica quella del cron lato server (`materializzaRicorrenti` in
/// budget-api `src/index.js`): il giorno di riferimento è
/// `ricorrenzaTemporale ?? data`, e se quel giorno nel mese non esiste
/// (il 31 a febbraio) la scadenza scatta l'ultimo giorno del mese.
class Ricorrenza {
  /// Giorno del mese a cui è agganciata la ricorrenza.
  /// `ricorrenzaTemporale` spesso non è valorizzata — l'app non la manda in
  /// creazione — quindi si ripiega sulla data della transazione.
  static int giornoRiferimento(Transaction t) =>
      (t.ricorrenzaTemporale ?? t.data).day;

  /// Ultimo giorno di un mese. Il giorno 0 del mese successivo è l'ultimo
  /// giorno di quello richiesto, e DateTime fa i conti bisestili da sé.
  static int ultimoGiornoDelMese(int anno, int mese) =>
      DateTime(anno, mese + 1, 0).day;

  /// Prossima scadenza a partire da [da] (default: oggi).
  /// Se cade proprio oggi ritorna oggi: una ricorrente in scadenza va mostrata
  /// come "oggi", non rimandata al mese dopo.
  static DateTime prossimaScadenza(Transaction t, {DateTime? da}) {
    final riferimento = da ?? DateTime.now();
    final oggi = DateTime(riferimento.year, riferimento.month, riferimento.day);
    final giorno = giornoRiferimento(t);

    final questoMese = _conClamp(riferimento.year, riferimento.month, giorno);
    if (!questoMese.isBefore(oggi)) return questoMese;

    // DateTime normalizza il mese 13 in gennaio dell'anno dopo.
    return _conClamp(riferimento.year, riferimento.month + 1, giorno);
  }

  static DateTime _conClamp(int anno, int mese, int giorno) {
    final normalizzato = DateTime(anno, mese);
    final ultimo = ultimoGiornoDelMese(normalizzato.year, normalizzato.month);
    return DateTime(
      normalizzato.year,
      normalizzato.month,
      giorno > ultimo ? ultimo : giorno,
    );
  }
}
