import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/models/category.dart';
import 'package:budget_flutter/services/anno_service.dart';
import 'package:budget_flutter/services/transazioni_query.dart';

RigaTransazione _t(String catId, DateTime data, double importo) =>
    RigaTransazione(
      data: data,
      importo: importo,
      descrizione: '',
      categoriaId: catId,
      categoria: 'Cat $catId',
      budgetCategoria: 100,
      portafoglio: 'Casa',
      ricorrente: false,
      contanti: false,
    );

Category _c(String id, {String nome = 'Cat', double budget = 100}) => Category(
      documentId: id,
      nome: nome,
      budgetCategoria: budget,
      walletDocumentId: 'w',
    );

void main() {
  group('mesi da contare per la stima', () {
    final agosto2026 = DateTime(2026, 8, 15);

    test('un anno concluso vale 12: gennaio-dicembre', () {
      expect(AnnoService.mesiDaContare(2025, adesso: agosto2026), 12);
      expect(AnnoService.mesiDaContare(2020, adesso: agosto2026), 12);
    });

    test('l\'anno in corso vale i mesi trascorsi', () {
      expect(AnnoService.mesiDaContare(2026, adesso: agosto2026), 8);
      expect(
        AnnoService.mesiDaContare(2026, adesso: DateTime(2026, 1, 3)),
        1,
      );
      expect(
        AnnoService.mesiDaContare(2026, adesso: DateTime(2026, 12, 31)),
        12,
      );
    });

    test('un anno futuro non ha ancora niente da confrontare', () {
      expect(AnnoService.mesiDaContare(2027, adesso: agosto2026), 0);
    });
  });

  group('aggregazione', () {
    test('anno senza transazioni: totale a zero, categorie comunque presenti', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: const [],
        categorie: [_c('a'), _c('b')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.speso, 0);
      expect(r.vuoto, isTrue);
      expect(r.categorie, hasLength(2));
      expect(r.perMese, everyElement(0));
    });

    test('una categoria con budget e zero spese resta nella lista', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [_t('a', DateTime(2025, 3, 4), 50)],
        categorie: [_c('a'), _c('b', nome: 'Vuota')],
        adesso: DateTime(2026, 8, 15),
      );
      final vuota = r.categorie.firstWhere((c) => c.nome == 'Vuota');
      expect(vuota.speso, 0);
      expect(vuota.budgetStimato, 1200);
    });

    test('gli estremi dell\'anno sono inclusi', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [
          _t('a', DateTime(2025, 1, 1), 10),
          _t('a', DateTime(2025, 12, 31), 20),
        ],
        categorie: [_c('a')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.speso, 30);
      expect(r.perMese[0], 10);
      expect(r.perMese[11], 20);
    });

    test('la somma dei dodici mesi fa il totale annuo', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [
          _t('a', DateTime(2025, 2, 1), 10),
          _t('b', DateTime(2025, 2, 15), 5),
          _t('a', DateTime(2025, 7, 9), 30),
          _t('b', DateTime(2025, 11, 3), 7.5),
        ],
        categorie: [_c('a'), _c('b')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.perMese.fold<double>(0, (s, v) => s + v), r.speso);
      expect(r.speso, 52.5);
    });

    test('le transazioni di un altro anno non entrano nel totale', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [
          _t('a', DateTime(2025, 5, 1), 10),
          _t('a', DateTime(2024, 5, 1), 999),
          _t('a', DateTime(2026, 5, 1), 999),
        ],
        categorie: [_c('a')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.speso, 10);
    });

    test('le categorie sono ordinate dalla più costosa', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [
          _t('a', DateTime(2025, 1, 1), 10),
          _t('b', DateTime(2025, 1, 1), 90),
        ],
        categorie: [_c('a', nome: 'Poco'), _c('b', nome: 'Tanto')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.categorie.first.nome, 'Tanto');
    });

    test('le spese di una categoria eliminata restano nel totale', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [
          _t('a', DateTime(2025, 4, 1), 20),
          _t('sparita', DateTime(2025, 4, 2), 15),
        ],
        categorie: [_c('a')],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.speso, 35);
      expect(r.perMese.fold<double>(0, (s, v) => s + v), 35);
      expect(r.categorie.any((c) => c.documentId == 'sparita'), isTrue);
    });
  });

  group('budget stimato', () {
    test('anno passato: budget mensile per dodici', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: const [],
        categorie: [_c('a', budget: 100)],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.categorie.first.budgetStimato, 1200);
    });

    test('anno in corso: solo i mesi trascorsi', () {
      final r = AnnoService.calcola(
        anno: 2026,
        transazioni: const [],
        categorie: [_c('a', budget: 100)],
        adesso: DateTime(2026, 8, 15),
      );
      expect(r.categorie.first.budgetStimato, 800);
    });

    test('senza budget non si inventa una percentuale', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [_t('a', DateTime(2025, 1, 1), 50)],
        categorie: [_c('a', budget: 0)],
        adesso: DateTime(2026, 8, 15),
      );
      final c = r.categorie.first;
      expect(c.budgetStimato, 0);
      expect(c.percentuale, isNull);
      expect(c.oltreStima, isFalse);
    });

    test('oltre la stima quando si è speso più del budget annuo', () {
      final r = AnnoService.calcola(
        anno: 2025,
        transazioni: [_t('a', DateTime(2025, 1, 1), 1500)],
        categorie: [_c('a', budget: 100)],
        adesso: DateTime(2026, 8, 15),
      );
      final c = r.categorie.first;
      expect(c.oltreStima, isTrue);
      expect(c.percentuale, closeTo(1.25, 0.001));
    });
  });
}
