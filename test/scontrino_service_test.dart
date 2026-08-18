import 'package:flutter_test/flutter_test.dart';
import 'package:budget_flutter/services/scontrino_service.dart';

// Le righe arrivano già ordinate per Y, come le prepara ScontrinoService.leggi.
void main() {
  test('scontrino normale: totale sulla stessa riga', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('CONAD CITY', 10, 20),
      RigaOcr('VIA ROMA 12', 40, 20),
      RigaOcr('PANE 1,20', 100, 20),
      RigaOcr('LATTE 2,30', 130, 20),
      RigaOcr('SUBTOTALE 3,50', 160, 20),
      RigaOcr('TOTALE EURO 3,50', 190, 20),
      RigaOcr('CONTANTE 10,00', 220, 20),
      RigaOcr('RESTO 6,50', 250, 20),
    ]);
    expect(d.totale, 3.50);
    expect(d.descrizione, 'CONAD CITY');
  });

  test('scontrino largo: importo in un blocco separato alla stessa altezza', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('ESSELUNGA SPA', 10, 25),
      RigaOcr('TOTALE COMPLESSIVO', 200, 25),
      RigaOcr('24,90', 203, 25),
    ]);
    expect(d.totale, 24.90);
  });

  test('ignora IVA, subtotale e conteggio articoli', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('MARKET', 10, 20),
      RigaOcr('TOTALE ARTICOLI 5', 100, 20),
      RigaOcr('SUBTOTALE 9,00', 130, 20),
      RigaOcr('TOTALE 8,00', 160, 20),
      RigaOcr('TOTALE IVA 22% 1,44', 190, 20),
    ]);
    expect(d.totale, 8.00);
  });

  test('separatore delle migliaia', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('TOTALE 1.234,56', 100, 20),
    ]);
    expect(d.totale, 1234.56);
  });

  test('nessun totale riconosciuto: null, non un numero a caso', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('SCONTRINO ILLEGGIBILE', 10, 20),
      RigaOcr('CONTANTE 50,00', 100, 20),
    ]);
    expect(d.totale, isNull);
  });

  test('scontrino vuoto', () {
    final d = ScontrinoService.estrai(const []);
    expect(d.totale, isNull);
    expect(d.descrizione, isNull);
  });

  // Lo scontrino Sigma di Milazzo, fotografato in mano: la colonna dei prezzi
  // e' disallineata rispetto alle diciture perche' la carta e' storta.
  // Prima di questo check il totale non veniva agganciato e il campo restava
  // vuoto, pur essendo "20,12" perfettamente leggibile nella foto.
  test('colonna dei prezzi leggermente disallineata', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('TOTALE COMPLESSIVO', 1000, 20),
      RigaOcr('20,12', 1014, 20), // sbandamento di 14px: piu' di h/2, meno di 1,5h
      RigaOcr('DI CUI IVA', 1040, 20),
      RigaOcr('2,83', 1054, 20),
    ]);
    expect(d.totale, 20.12);
  });

  test('fra due candidati vince quello alla stessa altezza', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('TOTALE COMPLESSIVO', 1000, 20),
      RigaOcr('20,12', 1005, 20), // sua
      RigaOcr('2,83', 1028, 20), // della riga sotto, ora dentro la finestra
    ]);
    expect(d.totale, 20.12);
  });

  // Se la dicitura buona non aggancia, resta "IMPORTO PAGATO".
  test('ripiega su IMPORTO PAGATO, non su PAGAMENTO CONTANTE', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('TOTALE COMPLESSIVO', 1000, 20),
      RigaOcr('PAGAMENTO CONTANTE 50,00', 1100, 20),
      RigaOcr('RESTO 29,88', 1140, 20),
      RigaOcr('IMPORTO PAGATO 20,12', 1180, 20),
    ]);
    expect(d.totale, 20.12); // non 50,00: quello e' quanto hai dato al cassiere
  });

  test('il testo letto torna sempre indietro, anche quando non trova nulla', () {
    final d = ScontrinoService.estrai(const [
      RigaOcr('SUPERMERCATI SIGMA', 100, 20),
      RigaOcr('roba illeggibile', 140, 20),
    ]);
    expect(d.totale, isNull);
    expect(d.righeLette, ['SUPERMERCATI SIGMA', 'roba illeggibile']);
  });
}
