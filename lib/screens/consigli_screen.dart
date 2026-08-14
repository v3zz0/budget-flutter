import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/consiglio.dart';
import '../providers/consigli_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/user_settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_client.dart';
import '../theme.dart';

/// Consigli sul budget: proposte calcolate a fine mese dal server.
/// Ogni consiglio si applica con un tap — è quello che lo rende utile.
class ConsigliScreen extends StatefulWidget {
  const ConsigliScreen({super.key});

  @override
  State<ConsigliScreen> createState() => _ConsigliScreenState();
}

class _ConsigliScreenState extends State<ConsigliScreen> {
  @override
  void initState() {
    super.initState();
    // Aprire la lista spegne il pallino: i consigli restano, non sono più nuovi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final token = requireToken(context);
      if (token != null) context.read<ConsigliProvider>().segnaTuttiLetti(token);
    });
  }

  Future<void> _applica(Consiglio c) async {
    final token = requireToken(context);
    if (token == null) return;
    final ok = await context.read<ConsigliProvider>().applica(token, c);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Budget di ${c.categoriaNome} aggiornato a ${c.budgetProposto.toStringAsFixed(0)}€'
              : 'Non sono riuscito ad aggiornare il budget',
        ),
        backgroundColor: ok ? AppColors.accent : AppColors.error,
      ),
    );

    // La dashboard mostra i budget: va ricaricata o resterebbe col valore vecchio.
    final walletId = context.read<WalletProvider>().selectedWallet?.documentId;
    if (ok && walletId != null) {
      context.read<DashboardProvider>().loadCategorie(
            token,
            walletId,
            orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
          );
    }
  }

  Future<void> _ignora(Consiglio c) async {
    final token = requireToken(context);
    if (token == null) return;
    await context.read<ConsigliProvider>().ignora(token, c);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConsigliProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Consigli sul budget',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : provider.consigli.isEmpty
              ? const _NessunConsiglio()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.consigli.length,
                  itemBuilder: (_, i) => _CardConsiglio(
                    consiglio: provider.consigli[i],
                    onApplica: () => _applica(provider.consigli[i]),
                    onIgnora: () => _ignora(provider.consigli[i]),
                  ),
                ),
    );
  }
}

class _NessunConsiglio extends StatelessWidget {
  const _NessunConsiglio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Nessun consiglio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'I budget rispecchiano le tue spese. I consigli vengono ricalcolati '
              'a fine mese, e servono almeno tre mesi di storico per categoria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardConsiglio extends StatelessWidget {
  final Consiglio consiglio;
  final VoidCallback onApplica;
  final VoidCallback onIgnora;

  const _CardConsiglio({
    required this.consiglio,
    required this.onApplica,
    required this.onIgnora,
  });

  @override
  Widget build(BuildContext context) {
    final colore = consiglio.isAlza ? AppColors.error : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: consiglio.isNuovo ? colore.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                consiglio.isAlza ? Icons.trending_up : Icons.trending_down,
                color: colore,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  consiglio.categoriaNome,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${consiglio.budgetAttuale.toStringAsFixed(0)}€ → '
                '${consiglio.budgetProposto.toStringAsFixed(0)}€',
                style: TextStyle(color: colore, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            consiglio.testo,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // I numeri su cui si basa il consiglio: senza questi bisognerebbe
          // fidarsi, con questi si controlla in due secondi.
          _Storico(mesi: consiglio.mesiAnalizzati, budget: consiglio.budgetAttuale),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onApplica,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Applica',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onIgnora,
                child: const Text(
                  'Ignora',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barrette dei mesi analizzati, con la linea del budget attuale.
class _Storico extends StatelessWidget {
  final List<SpesaMese> mesi;
  final double budget;

  const _Storico({required this.mesi, required this.budget});

  @override
  Widget build(BuildContext context) {
    if (mesi.isEmpty) return const SizedBox.shrink();
    final massimo = [
      budget,
      ...mesi.map((m) => m.speso),
    ].reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: mesi.map((m) {
        final sopra = m.speso > budget;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.speso.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10,
                    color: sopra ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  height: massimo > 0 ? (m.speso / massimo * 40).clamp(2, 40) : 2,
                  decoration: BoxDecoration(
                    color: sopra ? AppColors.error : AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // "2026-07" -> "07"
                  m.mese.length >= 7 ? m.mese.substring(5) : m.mese,
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
