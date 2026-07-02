import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/wallet_provider.dart';
import '../providers/salvadanaio_provider.dart';
import '../services/api_client.dart';
import '../models/salvadanaio.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';

class SalvadanaiScreen extends StatefulWidget {
  const SalvadanaiScreen({super.key});

  @override
  State<SalvadanaiScreen> createState() => _SalvadanaiScreenState();
}

class _SalvadanaiScreenState extends State<SalvadanaiScreen> {
  String? _ultimoWalletCaricato;
  final TextEditingController _risparmioCtrl = TextEditingController();
  // Tiene traccia di quale documentId / wallet ha popolato l'input;
  // serve per ri-sincronizzarlo quando arriva nuovo dato dal provider.
  String? _ultimoMeseCorrenteId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _caricaSeNecessario();
    });
  }

  @override
  void dispose() {
    _risparmioCtrl.dispose();
    super.dispose();
  }

  void _caricaSeNecessario() {
    final walletId = context.read<WalletProvider>().selectedWallet?.documentId;
    if (walletId != null && walletId != _ultimoWalletCaricato) {
      _ultimoWalletCaricato = walletId;
      _ultimoMeseCorrenteId = null;
      _risparmioCtrl.text = '';
      _caricaDati();
    }
  }

  Future<void> _caricaDati() async {
    final token = requireToken(context);
    if (token == null) return;
    final wallet = context.read<WalletProvider>();
    if (wallet.selectedWallet == null) return;
    await context.read<SalvadanaiProvider>().loadSalvadanai(
      token,
      wallet.selectedWallet!.documentId,
    );
  }

  // Sincronizza il TextField con il valore del mese corrente caricato dal
  // backend, ma solo se l'utente non sta editando attivamente (cioè se il
  // record è cambiato di identità).
  void _syncInputConProvider(SalvadanaiProvider provider) {
    final mc = provider.meseCorrente;
    final idCorrente = mc?.documentId ?? '__nessuno__';
    if (idCorrente != _ultimoMeseCorrenteId) {
      _ultimoMeseCorrenteId = idCorrente;
      _risparmioCtrl.text = mc != null ? mc.risparmiato.toStringAsFixed(0) : '';
    }
  }

  Future<void> _salvaRisparmio() async {
    final token = requireToken(context);
    if (token == null) return;
    final walletId = context.read<WalletProvider>().selectedWallet?.documentId;
    if (walletId == null) return;

    final importo = double.tryParse(_risparmioCtrl.text.replaceAll(',', '.'));
    if (importo == null || importo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un importo valido (≥ 0)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ok = await context
        .read<SalvadanaiProvider>()
        .salvaRisparmio(token, walletId, importo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Risparmio salvato' : 'Errore nel salvataggio'),
        backgroundColor: ok ? AppColors.accent : AppColors.error,
      ),
    );
  }

  String _nomeMeseBreve(int mese) {
    const nomi = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    return nomi[mese];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalvadanaiProvider>();
    final wallet = context.watch<WalletProvider>();
    _syncInputConProvider(provider);

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      onRefresh: _caricaDati,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('OBIETTIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 2)),
            const Text('Salvadanaio', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 24),

            if (provider.isLoading) const SalvadanaiSkeleton(),

            if (provider.errore != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.4))),
                child: Text(provider.errore!, style: const TextStyle(color: AppColors.error)),
              ),

            if (!provider.isLoading && provider.errore == null) ...[
              // Card editabile: risparmio di questo mese
              _CardRisparmioMese(
                controller: _risparmioCtrl,
                isSaving: provider.isSaving,
                onSalva: _salvaRisparmio,
              ),
              const SizedBox(height: 16),

              // Card totale storico
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        const Text('TOTALE STORICO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          provider.totaleStorico.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 6),
                          child: Text('€', style: TextStyle(fontSize: 24, color: AppColors.accent, fontWeight: FontWeight.w300)),
                        ),
                      ],
                    ),
                    if (wallet.selectedWallet != null)
                      Text(wallet.selectedWallet!.nome, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card trend mensile
              if (provider.ultimi6Mesi.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TREND MENSILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 2)),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: math.max(
                              provider.ultimi6Mesi
                                      .map((s) => s.risparmiato)
                                      .fold<double>(0, math.max) *
                                  1.4,
                              100,
                            ),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppColors.input,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${rod.toY.toStringAsFixed(0)}€',
                                    const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= provider.ultimi6Mesi.length) return const SizedBox();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _nomeMeseBreve(provider.ultimi6Mesi[i].mese.month),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: provider.ultimi6Mesi.asMap().entries.map((e) {
                              final isUltimo = e.key == provider.ultimi6Mesi.length - 1;
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.risparmiato,
                                    color: isUltimo ? AppColors.accent : AppColors.accent.withValues(alpha: 0.45),
                                    width: 28,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          duration: const Duration(milliseconds: 400),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Card dettaglio mese precedente
              if (provider.mesePrecedente != null)
                _CardDettaglio(mese: provider.mesePrecedente!),

              if (provider.voci.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nessun dato disponibile.\nI risparmi vengono calcolati a fine mese.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// Card editabile per il risparmio del mese corrente.
// L'utente inserisce un numero e preme "Salva".
class _CardRisparmioMese extends StatelessWidget {
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSalva;

  const _CardRisparmioMese({
    required this.controller,
    required this.isSaving,
    required this.onSalva,
  });

  static const _nomiMesi = [
    '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final titoloMese = '${_nomiMesi[now.month].toUpperCase()} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'RISPARMIO $titoloMese',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixText: ' €',
                    suffixStyle: TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isSaving ? null : onSalva,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Salva', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardDettaglio extends StatelessWidget {
  final Salvadanaio mese;
  const _CardDettaglio({required this.mese});

  @override
  Widget build(BuildContext context) {
    final percentuale = mese.budgetAllocato > 0
        ? (mese.speso / mese.budgetAllocato).clamp(0.0, 1.0)
        : 0.0;
    const nomiMesi = ['', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETTAGLIO ${nomiMesi[mese.mese.month].toUpperCase()} ${mese.mese.year}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget', style: TextStyle(color: AppColors.textSecondary)),
              Text('${mese.budgetAllocato.toStringAsFixed(0)} €', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Speso', style: TextStyle(color: AppColors.textSecondary)),
              Text('${mese.speso.toStringAsFixed(0)} €', style: const TextStyle(color: Color(0xFFEAB308), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentuale,
              minHeight: 6,
              backgroundColor: AppColors.input,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEAB308)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(percentuale * 100).toStringAsFixed(0)}% del budget', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('Risparmiato: ${mese.risparmiato.toStringAsFixed(0)} €', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
