import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Una riga di testo riconosciuta, con la sua posizione verticale.
///
/// ML Kit non restituisce un testo lineare come un .txt, ma blocchi con
/// coordinate: su uno scontrino largo "TOTALE" sta in un blocco a sinistra e
/// "12,50" in un blocco a destra. Servono le Y per riappaiarli.
class RigaOcr {
  final String testo;
  final double y; // centro verticale della riga
  final double h; // altezza della riga, usata come tolleranza

  const RigaOcr(this.testo, this.y, this.h);
}

class DatiScontrino {
  final double? totale;
  final String? descrizione;

  /// Cosa ha letto l'OCR, riga per riga. Serve quando il totale non salta
  /// fuori: senza vederlo si ragiona al buio su una foto che non c'è più.
  final List<String> righeLette;

  const DatiScontrino({
    this.totale,
    this.descrizione,
    this.righeLette = const [],
  });
}

/// OCR degli scontrini, interamente on-device: nessuna chiave API, nessuna
/// rete, la foto non lascia il telefono.
class ScontrinoService {
  // Un importo ha SEMPRE due decimali. Pretenderli scarta da solo i falsi
  // positivi tipo "TOTALE ARTICOLI 5" o il numero di scontrino.
  static final _importo = RegExp(r'\d{1,6}(?:[.,]\d{3})*[.,]\d{2}');

  // Righe che contengono "total" ma non sono il totale da pagare.
  static final _esclusi = RegExp(r'SUBTOT|PARZIAL|\bIVA\b|SCONTO|ARTICOL');

  // La dicitura buona: quasi tutti gli scontrini italiani ne hanno una.
  static final _totale = RegExp(r'TOTAL|TOT\.');

  // Diciture di riserva, provate solo se la prima passata non trova niente.
  // "IMPORTO PAGAT" e non "PAGA", altrimenti prenderebbe "PAGAMENTO CONTANTE",
  // che sullo scontrino e' quanto hai dato al cassiere: 50 euro per una spesa
  // da 20, e finirebbero nel budget cosi' come sono.
  static final _riserva = RegExp(r'IMPORTO PAGAT|DA PAGARE|TOT COMPL');

  /// Legge lo scontrino fotografato in [imagePath].
  static Future<DatiScontrino> leggi(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final risultato = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );

      final righe = <RigaOcr>[];
      for (final blocco in risultato.blocks) {
        for (final riga in blocco.lines) {
          final box = riga.boundingBox;
          righe.add(RigaOcr(riga.text, box.center.dy, box.height));
        }
      }
      righe.sort((a, b) => a.y.compareTo(b.y));

      return estrai(righe);
    } finally {
      await recognizer.close();
    }
  }

  /// Parte pura: niente fotocamera, niente ML Kit, quindi testabile.
  static DatiScontrino estrai(List<RigaOcr> righe) {
    return DatiScontrino(
      // Prima la dicitura buona su tutto lo scontrino, poi quelle di riserva:
      // un "TOTALE" letto male non deve far ripiegare su una riga peggiore
      // finche' c'e' ancora un "TOTALE" piu' sotto da provare.
      totale: _trovaTotale(righe, _totale) ?? _trovaTotale(righe, _riserva),
      descrizione: _trovaDescrizione(righe),
      righeLette: righe.map((r) => r.testo).toList(),
    );
  }

  static double? _trovaTotale(List<RigaOcr> righe, RegExp dicitura) {
    for (var i = 0; i < righe.length; i++) {
      final testo = righe[i].testo.toUpperCase();
      if (!dicitura.hasMatch(testo)) continue;
      if (_esclusi.hasMatch(testo)) continue;

      // Caso normale: l'importo è sulla stessa riga.
      final sullaRiga = _importo.allMatches(testo).toList();
      if (sullaRiga.isNotEmpty) return _num(sullaRiga.last[0]!);

      // Caso scontrino largo: l'importo è in un altro blocco, alla stessa
      // altezza. Tolleranza proporzionale all'altezza della riga, così non
      // dipende dai DPI della foto.
      //
      // Una volta e mezza e non una: la foto di uno scontrino tenuto in mano è
      // sempre un po' storta, e su una colonna distante mezza pagina bastano
      // pochi gradi perché il numero giusto esca dalla finestra. Con 1,5 resta
      // dentro, e il rischio di pescare la riga sotto è coperto dal fatto che
      // vince comunque la più vicina.
      // ponytail: se un giorno prendesse il numero della riga sbagliata, la
      // strada è confrontare le X (l'importo sta a destra della dicitura), non
      // stringere di nuovo la finestra.
      RigaOcr? vicina;
      for (var j = 0; j < righe.length; j++) {
        if (j == i) continue;
        final dist = (righe[j].y - righe[i].y).abs();
        if (dist > righe[i].h * 1.5) continue;
        if (!_importo.hasMatch(righe[j].testo)) continue;
        if (vicina == null || dist < (vicina.y - righe[i].y).abs()) {
          vicina = righe[j];
        }
      }
      if (vicina != null) {
        return _num(_importo.allMatches(vicina.testo).last[0]!);
      }
    }
    // ponytail: nessun fallback tipo "prendi il numero più grande" — sugli
    // scontrini in contanti il massimo è il CONTANTE, non il totale. Meglio
    // campo vuoto (l'utente lo scrive a mano) che un importo sbagliato che
    // finisce nel budget senza che nessuno se ne accorga.
    return null;
  }

  // Prima riga leggibile senza cifre: sugli scontrini è l'insegna del negozio.
  static String? _trovaDescrizione(List<RigaOcr> righe) {
    for (final riga in righe) {
      final t = riga.testo.trim();
      if (t.length < 3 || t.contains(RegExp(r'\d'))) continue;
      return t.length > 30 ? t.substring(0, 30) : t;
    }
    return null;
  }

  // "12,50", "1.234,56" (IT) o "1,234.56" (EN): l'ultimo separatore è sempre
  // quello decimale, gli altri sono migliaia.
  static double? _num(String s) {
    final i = s.lastIndexOf(RegExp(r'[.,]'));
    if (i < 0) return null;
    final interi = s.substring(0, i).replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse('$interi.${s.substring(i + 1)}');
  }
}
