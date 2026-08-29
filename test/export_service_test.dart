import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/services/export_service.dart';
import 'package:budget_flutter/services/transazioni_query.dart';

RigaTransazione _riga({
  DateTime? data,
  double importo = 12.5,
  String descrizione = 'Spesa',
  String categoria = 'Cibo',
  double budget = 300,
  String portafoglio = 'Casa',
  bool ricorrente = false,
  bool contanti = false,
}) =>
    RigaTransazione(
      data: data ?? DateTime(2026, 7, 5),
      importo: importo,
      descrizione: descrizione,
      categoriaId: 'cat-1',
      categoria: categoria,
      budgetCategoria: budget,
      portafoglio: portafoglio,
      ricorrente: ricorrente,
      contanti: contanti,
    );

/// Divide una riga CSV rispettando le virgolette.
List<String> _campi(String riga) {
  final out = <String>[];
  final buf = StringBuffer();
  var dentro = false;
  for (var i = 0; i < riga.length; i++) {
    final c = riga[i];
    if (c == '"') {
      if (dentro && i + 1 < riga.length && riga[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        dentro = !dentro;
      }
    } else if (c == ',' && !dentro) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}

void main() {
  group('intestazione e struttura', () {
    test('una riga per transazione, più l\'intestazione', () {
      final csv = generaCsv([_riga(), _riga(), _riga()]);
      final righe = csv.trim().split('\n');
      expect(righe, hasLength(4));
      expect(
        righe.first,
        'data,importo,descrizione,categoria,budget_categoria,portafoglio,ricorrente,contanti',
      );
    });

    test('nessuna riga senza transazioni', () {
      expect(generaCsv([]).trim().split('\n'), hasLength(1));
    });
  });

  group('formato dei campi', () {
    test('data in ISO con mese e giorno a due cifre', () {
      final csv = generaCsv([_riga(data: DateTime(2026, 3, 7))]);
      expect(_campi(csv.trim().split('\n')[1])[0], '2026-03-07');
    });

    test('importo col punto decimale, non la virgola', () {
      final csv = generaCsv([_riga(importo: 1234.5)]);
      expect(_campi(csv.trim().split('\n')[1])[1], '1234.50');
    });

    test('booleani come si/no', () {
      final csv = generaCsv([_riga(ricorrente: true, contanti: false)]);
      final c = _campi(csv.trim().split('\n')[1]);
      expect(c[6], 'si');
      expect(c[7], 'no');
    });
  });

  group('escaping', () {
    test('una virgola nella descrizione non spacca le colonne', () {
      final csv = generaCsv([_riga(descrizione: 'Pane, latte e uova')]);
      final c = _campi(csv.trim().split('\n')[1]);
      expect(c, hasLength(8));
      expect(c[2], 'Pane, latte e uova');
    });

    test('vale anche per categoria e portafoglio, non solo descrizione', () {
      final csv = generaCsv([
        _riga(categoria: 'Casa, bollette', portafoglio: 'Affitto, Auriletto'),
      ]);
      final c = _campi(csv.trim().split('\n')[1]);
      expect(c, hasLength(8));
      expect(c[3], 'Casa, bollette');
      expect(c[5], 'Affitto, Auriletto');
    });

    test('le virgolette vengono raddoppiate', () {
      final csv = generaCsv([_riga(descrizione: 'Cena da "Mario"')]);
      expect(_campi(csv.trim().split('\n')[1])[2], 'Cena da "Mario"');
    });

    test('un a capo nella descrizione non crea una riga in più', () {
      final csv = generaCsv([_riga(descrizione: 'Prima\nSeconda')]);
      expect(csv.trim().split('\n'), hasLength(2));
    });

    test('una transazione orfana resta nel file, coi campi vuoti', () {
      final csv = generaCsv([_riga(categoria: '', portafoglio: '')]);
      final c = _campi(csv.trim().split('\n')[1]);
      expect(c, hasLength(8));
      expect(c[3], '');
      expect(c[5], '');
    });
  });

  group('completezza del risultato', () {
    test('completo quando righe più escluse fanno il totale', () {
      const r = RisultatoExport(righe: [], totaleDichiarato: 0, escluse: 0);
      expect(r.completo, isTrue);
    });

    test('le escluse contano verso il totale, non sono un ammanco', () {
      final r = RisultatoExport(
        righe: [_riga(), _riga()],
        totaleDichiarato: 5,
        escluse: 3,
      );
      expect(r.completo, isTrue);
      expect(r.mancanti, 0);
    });

    test('se ne mancano davvero, lo dice', () {
      final r = RisultatoExport(
        righe: [_riga()],
        totaleDichiarato: 10,
        escluse: 2,
      );
      expect(r.completo, isFalse);
      expect(r.mancanti, 7);
    });
  });
}
