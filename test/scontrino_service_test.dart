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
}
