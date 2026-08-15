import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/models/transaction.dart';
import 'package:budget_flutter/services/ricorrenza.dart';

Transaction _ricorrente({required DateTime data, DateTime? ricorrenza}) {
  return Transaction(
    documentId: 'x',
    importo: 10,
    descrizione: 'Affitto',
    data: data,
    transazioneRicorrente: true,
    ricorrenzaTemporale: ricorrenza,
    categoriaDocumentId: 'c',
  );
}

void main() {
  group('giorno di riferimento', () {
    test('usa ricorrenzaTemporale quando c\'è', () {
      final t = _ricorrente(
        data: DateTime(2026, 3, 5),
        ricorrenza: DateTime(2026, 1, 20),
      );
      expect(Ricorrenza.giornoRiferimento(t), 20);
    });

    test('ripiega sulla data quando ricorrenzaTemporale manca', () {
      final t = _ricorrente(data: DateTime(2026, 3, 5));
      expect(Ricorrenza.giornoRiferimento(t), 5);
    });
  });

  group('prossima scadenza', () {
    test('più avanti nello stesso mese', () {
      final t = _ricorrente(data: DateTime(2026, 1, 20));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2026, 8, 10));
      expect(p, DateTime(2026, 8, 20));
    });

    test('già passata questo mese: va al mese dopo', () {
      final t = _ricorrente(data: DateTime(2026, 1, 5));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2026, 8, 10));
      expect(p, DateTime(2026, 9, 5));
    });

    test('in scadenza oggi resta oggi, non slitta', () {
      final t = _ricorrente(data: DateTime(2026, 1, 10));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2026, 8, 10));
      expect(p, DateTime(2026, 8, 10));
    });

    test('a dicembre scavalca l\'anno', () {
      final t = _ricorrente(data: DateTime(2026, 1, 3));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2026, 12, 20));
      expect(p, DateTime(2027, 1, 3));
    });
  });

  group('mesi corti', () {
    // Il caso che la vecchia logica sbagliava: costruire DateTime(2027, 2, 31)
    // normalizza al 3 marzo invece di limitare al 28.
    test('il 31 a febbraio scatta l\'ultimo giorno del mese', () {
      final t = _ricorrente(data: DateTime(2026, 1, 31));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2027, 2, 1));
      expect(p, DateTime(2027, 2, 28));
    });

    test('febbraio bisestile arriva al 29', () {
      final t = _ricorrente(data: DateTime(2026, 1, 31));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2028, 2, 1));
      expect(p, DateTime(2028, 2, 29));
    });

    test('il 31 in un mese da 30 scatta il 30', () {
      final t = _ricorrente(data: DateTime(2026, 1, 31));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2026, 4, 5));
      expect(p, DateTime(2026, 4, 30));
    });

    test('dopo un mese corto torna al giorno pieno', () {
      final t = _ricorrente(data: DateTime(2026, 1, 31));
      final p = Ricorrenza.prossimaScadenza(t, da: DateTime(2027, 3, 1));
      expect(p, DateTime(2027, 3, 31));
    });
  });

  group('ultimo giorno del mese', () {
    test('mesi comuni', () {
      expect(Ricorrenza.ultimoGiornoDelMese(2026, 1), 31);
      expect(Ricorrenza.ultimoGiornoDelMese(2026, 4), 30);
      expect(Ricorrenza.ultimoGiornoDelMese(2026, 12), 31);
    });

    test('febbraio, bisestile e non', () {
      expect(Ricorrenza.ultimoGiornoDelMese(2027, 2), 28);
      expect(Ricorrenza.ultimoGiornoDelMese(2028, 2), 29);
      // 2100 non è bisestile: divisibile per 100 ma non per 400.
      expect(Ricorrenza.ultimoGiornoDelMese(2100, 2), 28);
    });
  });
}
