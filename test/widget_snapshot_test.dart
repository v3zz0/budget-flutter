import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/widget/widget_snapshot.dart';

void main() {
  const snapshot = WidgetSnapshot(
    walletId: 'w1',
    walletNome: 'Casa',
    budgetTotale: 1000,
    speso: 400,
    rimanente: 600,
    mese: '2026-08',
    aggiornatoAt: 1755000000000,
    stato: StatoWidget.ok,
    slots: [
      SlotWidget(categoriaId: 'c1', nome: 'Spesa', icona: '🛒'),
      SlotWidget(categoriaId: 'c2', nome: 'Auto'),
    ],
  );

  test('andata e ritorno mantiene tutti i campi', () {
    final riletto = WidgetSnapshot.decode(snapshot.encode())!;

    expect(riletto.walletId, 'w1');
    expect(riletto.walletNome, 'Casa');
    expect(riletto.budgetTotale, 1000);
    expect(riletto.speso, 400);
    expect(riletto.rimanente, 600);
    expect(riletto.mese, '2026-08');
    expect(riletto.aggiornatoAt, 1755000000000);
    expect(riletto.stato, StatoWidget.ok);
    expect(riletto.slots, hasLength(2));
    expect(riletto.slots.first.nome, 'Spesa');
    expect(riletto.slots.first.icona, '🛒');
    expect(riletto.slots.last.icona, '');
  });

  test('il json contiene la versione del formato', () {
    final j = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(j['versione'], WidgetSnapshot.versione);
  });

  group('input che il widget non deve interpretare', () {
    test('null e stringa vuota', () {
      expect(WidgetSnapshot.decode(null), isNull);
      expect(WidgetSnapshot.decode(''), isNull);
    });

    test('json malformato non lancia, ritorna null', () {
      expect(WidgetSnapshot.decode('{non è json'), isNull);
    });

    test('versione diversa viene rifiutata invece di essere letta a metà', () {
      final j = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      j['versione'] = WidgetSnapshot.versione + 1;
      expect(WidgetSnapshot.decode(jsonEncode(j)), isNull);
    });

    test('stato sconosciuto ripiega su noConfig, non su ok', () {
      final j = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      j['stato'] = 'qualcosaDiNuovo';
      expect(WidgetSnapshot.decode(jsonEncode(j))!.stato, StatoWidget.noConfig);
    });
  });

  test('snapshot vuoto porta lo stato, non numeri finti', () {
    final vuoto = WidgetSnapshot.vuoto(StatoWidget.noAuth, adesso: 123);
    final riletto = WidgetSnapshot.decode(vuoto.encode())!;

    expect(riletto.stato, StatoWidget.noAuth);
    expect(riletto.slots, isEmpty);
    expect(riletto.aggiornatoAt, 123);
  });
}
