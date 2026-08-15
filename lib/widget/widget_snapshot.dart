import 'dart:convert';

/// In che stato si trova l'app dal punto di vista del widget.
/// Serve perché il widget disegna anche quando l'app non gira: deve poter
/// dire "non so" invece di mostrare zeri che sembrerebbero dati veri.
enum StatoWidget {
  /// Numeri validi.
  ok,

  /// Nessuna sessione: l'utente ha fatto logout o il token è scaduto.
  noAuth,

  /// L'app non è mai stata configurata (nessun server, nessun wallet).
  noConfig,
}

/// Una scorciatoia del widget: una categoria su cui registrare al volo.
class SlotWidget {
  final String categoriaId;
  final String nome;
  final String icona;

  const SlotWidget({
    required this.categoriaId,
    required this.nome,
    this.icona = '',
  });

  Map<String, dynamic> toJson() => {
        'categoriaId': categoriaId,
        'nome': nome,
        'icona': icona,
      };

  factory SlotWidget.fromJson(Map<String, dynamic> j) => SlotWidget(
        categoriaId: j['categoriaId'] ?? '',
        nome: j['nome'] ?? '',
        icona: j['icona'] ?? '',
      );
}

/// Fotografia dei numeri che il widget mostra in home.
///
/// Viene scritta dall'app (sempre in foreground) e letta dal widget, che gira
/// in un BroadcastReceiver senza rete e con pochi millisecondi a disposizione:
/// per questo i numeri devono essere già calcolati, non calcolabili.
class WidgetSnapshot {
  /// Versione del formato: se un giorno cambia la forma, il widget vecchio
  /// deve poter capire che non sa leggerla invece di mostrare dati sbagliati.
  static const int versione = 1;

  final String walletId;
  final String walletNome;
  final double budgetTotale;
  final double speso;
  final double rimanente;

  /// "2026-08" — il mese a cui si riferiscono i numeri.
  final String mese;

  /// Epoch in millisecondi dell'ultimo aggiornamento, per mostrare "agg. 14:32"
  /// e per capire quando i dati sono vecchi.
  final int aggiornatoAt;

  final StatoWidget stato;
  final List<SlotWidget> slots;

  const WidgetSnapshot({
    required this.walletId,
    required this.walletNome,
    required this.budgetTotale,
    required this.speso,
    required this.rimanente,
    required this.mese,
    required this.aggiornatoAt,
    required this.stato,
    this.slots = const [],
  });

  /// Snapshot "non ho niente da dire": usato al logout e prima del primo
  /// caricamento. I numeri restano a zero ma è lo stato a comandare cosa
  /// il widget disegna.
  factory WidgetSnapshot.vuoto(StatoWidget stato, {required int adesso}) =>
      WidgetSnapshot(
        walletId: '',
        walletNome: '',
        budgetTotale: 0,
        speso: 0,
        rimanente: 0,
        mese: '',
        aggiornatoAt: adesso,
        stato: stato,
      );

  Map<String, dynamic> toJson() => {
        'versione': versione,
        'walletId': walletId,
        'walletNome': walletNome,
        'budgetTotale': budgetTotale,
        'speso': speso,
        'rimanente': rimanente,
        'mese': mese,
        'aggiornatoAt': aggiornatoAt,
        'stato': stato.name,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  static WidgetSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['versione'] != versione) return null;
      return WidgetSnapshot(
        walletId: j['walletId'] ?? '',
        walletNome: j['walletNome'] ?? '',
        budgetTotale: (j['budgetTotale'] ?? 0).toDouble(),
        speso: (j['speso'] ?? 0).toDouble(),
        rimanente: (j['rimanente'] ?? 0).toDouble(),
        mese: j['mese'] ?? '',
        aggiornatoAt: j['aggiornatoAt'] ?? 0,
        stato: StatoWidget.values.firstWhere(
          (s) => s.name == j['stato'],
          orElse: () => StatoWidget.noConfig,
        ),
        slots: ((j['slots'] ?? []) as List)
            .map((s) => SlotWidget.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      // Snapshot illeggibile: meglio "non so" che un crash nel widget.
      return null;
    }
  }
}
