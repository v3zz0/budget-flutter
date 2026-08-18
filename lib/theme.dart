import 'package:flutter/material.dart';

/// Palette dell'app. Dark mode only.
///
/// I contrasti riportati sono rapporti WCAG misurati su [card]; la soglia AA per
/// il testo sotto i 18px è 4.5:1. Prima di cambiare un colore, ricalcolare —
/// diversi valori qui sotto stanno appena sopra la soglia.
class AppColors {
  static const bg = Color(0xFF0F1923);
  static const card = Color(0xFF1A2535);
  static const input = Color(0xFF1E2D40);

  /// Brand e azioni: bottoni, link, elementi interattivi, stato selezionato.
  /// NON usarlo per i valori monetari — a 13px fa 4.20:1, sotto la soglia AA.
  static const accent = Color(0xFF3B82F6);

  /// Valori positivi: rimanente sopra lo zero, risparmi, progressi in regola.
  /// 6.09:1 su card. È il verde storico del progetto, tornato al suo posto:
  /// prima il positivo era `accent`, che ha esattamente la stessa luminanza di
  /// `error` (1.00:1 fra loro) — in scala di grigi, o per un daltonico, "€120
  /// rimanenti" e "€120 sforati" erano indistinguibili.
  static const positivo = Color(0xFF10B981);

  /// Sfondi, bordi, icone e SnackBar di errore. Come testo su [card] fa 4.21:1,
  /// sotto la soglia: per il testo usare [errorText].
  static const error = Color(0xFFF43F5E);

  /// Variante chiara di [error] per il TESTO: 5.74:1 su card.
  static const errorText = Color(0xFFFB7185);

  static const textPrimary = Color(0xFFE8EFF7);
  static const textSecondary = Color(0xFF7A90A8);

  /// Bordo delle card. 1.72:1 su [card].
  // ponytail: WCAG 1.4.11 chiederebbe 3:1, che su questo fondo significa un
  //   bordo grigio chiaro e un dark mode molto meno elegante. Alzato da 0x12
  //   (1.23:1, praticamente invisibile alla luce del sole) al massimo che non
  //   snatura il design. Per arrivare a 3:1 servirebbe rifare le superfici.
  static const border = Color(0x24FFFFFF);

  /// Giallo di avviso: proiezione di sfondamento, dati parziali. 9.25:1 su bg.
  static const avviso = Color(0xFFEAB308);

  // Colori per le categorie
  static const List<Color> categorie = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFEAB308),
  ];
}

/// Formattazione degli importi in euro.
///
/// Sta qui e non nelle schermate perché il segno è una questione di design, non
/// di presentazione locale: un valore negativo deve leggersi come negativo anche
/// senza vederne il colore (WCAG `color-not-only`). Prima "€120" e "€120" erano
/// la stessa stringa e cambiava solo la tinta.
class Euro {
  /// `€120` / `−€120`. [decimali] a 2 per gli importi delle singole transazioni.
  static String segnato(double valore, {int decimali = 0}) {
    final segno = valore < 0 ? '−' : '';
    return '$segno€${valore.abs().toStringAsFixed(decimali)}';
  }

  /// Colore da abbinare a un valore: verde sopra lo zero, rosso sotto.
  static Color colore(double valore) =>
      valore < 0 ? AppColors.errorText : AppColors.positivo;
}
