import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/dashboard_provider.dart';
import '../providers/transazione_provider.dart';
import '../providers/user_settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_client.dart';
import '../services/ricorrenza.dart';
import '../theme.dart';
import 'transazioni_screen.dart';

/// Elenco delle transazioni ricorrenti del portafoglio selezionato.
///
/// Serve a rendere visibile una cosa che finora succedeva in silenzio: il cron
/// lato server (`materializzaRicorrenti`) crea ogni mese l'istanza di ogni
/// ricorrente, ma nell'app non c'era nessun posto in cui vedere quali sono e
/// quando scattano.
///
/// I dati sono già in memoria: DashboardProvider carica le categorie con le
/// relative transazioni, quindi qui non si chiama nessuna API nuova.
class RicorrentiScreen extends StatelessWidget {
  const RicorrentiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletId = context.watch<WalletProvider>().selectedWallet?.documentId;
    final categorie = context
        .watch<DashboardProvider>()
        .categorie
        .where((c) => walletId == null || c.walletDocumentId == walletId)
        .toList();

    // Si usa `categorie` e non `categorieFiltrate`: un template ricorrente vive
    // nel mese in cui è stato creato, quindi filtrando per mese corrente
    // sparirebbe quasi sempre.
    final ricorrenti = <_VoceRicorrente>[];
    for (final cat in categorie) {
      for (final t in cat.transazionis) {
        if (t.transazioneRicorrente) {
          ricorrenti.add(
            _VoceRicorrente(
              transazione: t,
              categoria: cat,
              prossima: Ricorrenza.prossimaScadenza(t),
            ),
          );
        }
      }
    }
    ricorrenti.sort((a, b) => a.prossima.compareTo(b.prossima));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Transazioni ricorrenti'),
      ),
      body: ricorrenti.isEmpty
          ? const _Vuoto()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: ricorrenti.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return const _Spiegazione();
                return _RigaRicorrente(voce: ricorrenti[i - 1]);
              },
            ),
    );
  }
}

class _VoceRicorrente {
  final Transaction transazione;
  final Category categoria;
  final DateTime prossima;

  _VoceRicorrente({
    required this.transazione,
    required this.categoria,
    required this.prossima,
  });
}

class _Spiegazione extends StatelessWidget {
  const _Spiegazione();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16, left: 4, right: 4),
      child: Text(
        'Ogni mese queste spese vengono registrate automaticamente. '
        'Toccane una per modificarla.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

class _Vuoto extends StatelessWidget {
  const _Vuoto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Nessuna transazione ricorrente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Quando salvi una transazione, attiva "Ricorrente" per farla '
              'ripetere ogni mese.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RigaRicorrente extends StatelessWidget {
  final _VoceRicorrente voce;

  const _RigaRicorrente({required this.voce});

  /// "oggi" / "domani" / "il 12 set" — una data secca per qualcosa che scatta
  /// fra due giorni si legge peggio.
  String _quando(DateTime prossima) {
    final ora = DateTime.now();
    final oggi = DateTime(ora.year, ora.month, ora.day);
    final giorni = prossima.difference(oggi).inDays;
    if (giorni <= 0) return 'oggi';
    if (giorni == 1) return 'domani';
    if (giorni < 7) return 'fra $giorni giorni';
    return DateFormat("'il' d MMM", 'it_IT').format(prossima);
  }

  Future<void> _elimina(BuildContext context) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Eliminare la ricorrente?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Non verrà più registrata automaticamente ogni mese. '
          'Le spese già registrate restano.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true || !context.mounted) return;

    final token = requireToken(context);
    if (token == null) return;

    final ok = await context.read<TransazioneProvider>().elimina(
      token,
      voce.transazione.documentId,
    );
    if (!ok || !context.mounted) return;

    await context.read<DashboardProvider>().loadCategorie(
      token,
      voce.categoria.walletDocumentId,
      orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = voce.transazione;
    final inEliminazione = context.watch<TransazioneProvider>().isEliminando(
      t.documentId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransazioniScreen(daModificare: t),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (voce.categoria.icona.isNotEmpty) ...[
                Text(
                  voce.categoria.icona,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.descrizione.isNotEmpty
                          ? t.descrizione
                          : voce.categoria.nome,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${voce.categoria.nome} · ${_quando(voce.prossima)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '€${t.importo.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: inEliminazione ? null : () => _elimina(context),
                child: inEliminazione
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
