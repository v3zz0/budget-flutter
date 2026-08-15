import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/models/category.dart';
import 'package:budget_flutter/models/transaction.dart';
import 'package:budget_flutter/services/soglia_service.dart';

Transaction _spesa(double importo, DateTime data) => Transaction(
      documentId: 't${data.microsecondsSinceEpoch}$importo',
      importo: importo,
      descrizione: '',
      data: data,
      transazioneRicorrente: false,
      categoriaDocumentId: 'c',
    );

Category _categoria({
  required String nome,
  required double budget,
  List<Transaction> transazioni = const [],
}) =>
    Category(
      documentId: 'cat-$nome',
      nome: nome,
      budgetCategoria: budget,
      walletDocumentId: 'w',
      transazionis: transazioni,
    );

void main() {
  final agosto = DateTime(2026, 8, 15);

  group('oltre soglia', () {
    test('sotto la soglia non segnala', () {
      final c = _categoria(
        nome: 'Spesa',
        budget: 100,
        transazioni: [_spesa(70, DateTime(2026, 8, 3))],
      );
      expect(SogliaService.oltreSoglia([c], mese: agosto), isEmpty);
    });

    test('esattamente sulla soglia segnala', () {
      final c = _categoria(
        nome: 'Spesa',
        budget: 100,
        transazioni: [_spesa(80, DateTime(2026, 8, 3))],
      );
      final r = SogliaService.oltreSoglia([c], mese: agosto);
      expect(r, hasLength(1));
      expect(r.first.percentuale, 0.8);
      expect(r.first.sforata, isFalse);
    });

    test('oltre il budget risulta sforata', () {
      final c = _categoria(
        nome: 'Spesa',
        budget: 100,
        transazioni: [_spesa(130, DateTime(2026, 8, 3))],
      );
      final r = SogliaService.oltreSoglia([c], mese: agosto);
      expect(r.first.sforata, isTrue);
      expect(r.first.percentuale, closeTo(1.3, 0.001));
    });

    test('conta solo le spese del mese richiesto', () {
      final c = _categoria(
        nome: 'Spesa',
        budget: 100,
        transazioni: [
          _spesa(90, DateTime(2026, 7, 20)), // mese precedente
          _spesa(30, DateTime(2026, 8, 3)),
        ],
      );
      expect(SogliaService.oltreSoglia([c], mese: agosto), isEmpty);
    });

    test('le categorie senza budget vengono ignorate', () {
      final c = _categoria(
        nome: 'Varie',
        budget: 0,
        transazioni: [_spesa(500, DateTime(2026, 8, 3))],
      );
      expect(SogliaService.oltreSoglia([c], mese: agosto), isEmpty);
    });

    test('soglia personalizzata', () {
      final c = _categoria(
        nome: 'Spesa',
        budget: 100,
        transazioni: [_spesa(60, DateTime(2026, 8, 3))],
      );
      expect(SogliaService.oltreSoglia([c], mese: agosto), isEmpty);
      expect(
        SogliaService.oltreSoglia([c], mese: agosto, soglia: 0.5),
        hasLength(1),
      );
    });

    test('ordina mettendo davanti la più critica', () {
      final vicina = _categoria(
        nome: 'Vicina',
        budget: 100,
        transazioni: [_spesa(85, DateTime(2026, 8, 3))],
      );
      final sforata = _categoria(
        nome: 'Sforata',
        budget: 100,
        transazioni: [_spesa(150, DateTime(2026, 8, 3))],
      );
      final r = SogliaService.oltreSoglia([vicina, sforata], mese: agosto);
      expect(r.map((e) => e.categoria.nome), ['Sforata', 'Vicina']);
    });
  });

  group('proiezione di fine mese', () {
    test('estrapola sul ritmo tenuto finora', () {
      // 150€ in 10 giorni su un agosto da 31 → 465€
      final p = SogliaService.proiezioneFineMese(
        speso: 150,
        mese: DateTime(2026, 8),
        adesso: DateTime(2026, 8, 10),
      );
      expect(p, closeTo(465, 0.01));
    });

    test('a mese finito vale la spesa reale, non un\'estrapolazione', () {
      final p = SogliaService.proiezioneFineMese(
        speso: 400,
        mese: DateTime(2026, 8),
        adesso: DateTime(2026, 8, 31),
      );
      expect(p, 400);
    });

    test('null su un mese diverso da quello in corso', () {
      final p = SogliaService.proiezioneFineMese(
        speso: 150,
        mese: DateTime(2026, 7),
        adesso: DateTime(2026, 8, 10),
      );
      expect(p, isNull);
    });

    test('null se non si è ancora speso niente', () {
      final p = SogliaService.proiezioneFineMese(
        speso: 0,
        mese: DateTime(2026, 8),
        adesso: DateTime(2026, 8, 10),
      );
      expect(p, isNull);
    });

    test('tiene conto della lunghezza del mese', () {
      // Stesso ritmo, febbraio da 28 giorni → proiezione più bassa
      final feb = SogliaService.proiezioneFineMese(
        speso: 100,
        mese: DateTime(2027, 2),
        adesso: DateTime(2027, 2, 10),
      );
      expect(feb, closeTo(280, 0.01));
    });
  });
}
