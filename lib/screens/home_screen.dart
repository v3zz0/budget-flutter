import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/skeleton.dart';
import '../providers/wallet_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/transazione_provider.dart';
import '../providers/user_settings_provider.dart';
import '../services/api_client.dart';
import '../models/category.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tiene traccia di quale categoria è espansa — equivalente di expandedRows in Vue
  final Set<String> _espanse = {};
  String? _ultimoWalletCaricato;

  Future<void> _caricaDati() async {
    final token = requireToken(context);
    if (token == null) return;
    final wallet = context.read<WalletProvider>();
    if (wallet.selectedWallet == null) return;

    await context.read<DashboardProvider>().loadCategorie(
      token,
      wallet.selectedWallet!.documentId,
      orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
    );
  }

  // Ricarica solo se il wallet selezionato è cambiato davvero
  void _caricaDatiSeNecessario() {
    final walletId = context.read<WalletProvider>().selectedWallet?.documentId;
    if (walletId != null && walletId != _ultimoWalletCaricato) {
      _ultimoWalletCaricato = walletId;
      _caricaDati();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _caricaDatiSeNecessario();
    });
  }

  Future<void> _esportaCsv() async {
    final dashboard = context.read<DashboardProvider>();
    final wallet = context.read<WalletProvider>();
    final categorie = dashboard.categorieFiltrate;
    if (categorie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun dato da esportare'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Costruzione CSV — equivalente del foreach + reduce in Vue
    final buffer = StringBuffer();
    buffer.writeln('Categoria,Budget,Spesi,Rimanente,Data,Descrizione,Importo,Ricorrente');

    for (final cat in categorie) {
      final spesi = cat.transazionis.fold(0.0, (s, t) => s + t.importo);
      final rimanente = cat.budgetCategoria - spesi;
      if (cat.transazionis.isEmpty) {
        buffer.writeln('"${cat.nome}",${cat.budgetCategoria.toStringAsFixed(2)},${spesi.toStringAsFixed(2)},${rimanente.toStringAsFixed(2)},,,,');
      } else {
        for (final t in cat.transazionis) {
          final data = '${t.data.day.toString().padLeft(2, '0')}/${t.data.month.toString().padLeft(2, '0')}/${t.data.year}';
          final desc = t.descrizione.replaceAll('"', '""');
          buffer.writeln('"${cat.nome}",${cat.budgetCategoria.toStringAsFixed(2)},${spesi.toStringAsFixed(2)},${rimanente.toStringAsFixed(2)},$data,"$desc",${t.importo.toStringAsFixed(2)},${t.transazioneRicorrente ? "Sì" : "No"}');
        }
      }
    }

    final mese = _nomeMese(dashboard.meseScelto.month).toLowerCase();
    final anno = dashboard.meseScelto.year;
    final walletNome = wallet.selectedWallet?.nome.replaceAll(' ', '_') ?? 'wallet';
    final fileName = 'budget_${walletNome}_${mese}_$anno.csv';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], subject: 'Export $fileName');
  }

  String _nomeMese(int mese) {
    const nomi = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];
    return nomi[mese];
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final wallet = context.watch<WalletProvider>();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      onRefresh: _caricaDati,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Navigatore mese — equivalente di < Aprile 2026 > in Vue
            Row(
              children: [
                Expanded(child: _NavigatoreMese(dashboard: dashboard, nomeMese: _nomeMese)),
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: AppColors.textPrimary),
                  tooltip: 'Esporta CSV',
                  onPressed: _esportaCsv,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tre card riepilogative — Budget / Spesi / Rimanenti
            if (!dashboard.isLoading && dashboard.errore == null)
              _CardRiepilogo(dashboard: dashboard, wallet: wallet),

            const SizedBox(height: 16),

            // Loading
            if (dashboard.isLoading) const DashboardSkeleton(),

            // Errore
            if (dashboard.errore != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Text(dashboard.errore!, style: const TextStyle(color: AppColors.error)),
              ),

            // Nessun wallet selezionato
            if (!dashboard.isLoading && wallet.selectedWallet == null)
              const Center(
                child: Text(
                  'Seleziona un portafoglio in alto',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            // Lista categorie espandibili
            if (!dashboard.isLoading && dashboard.errore == null)
              ...dashboard.categorieFiltrate.map(
                (cat) => _CardCategoria(
                  categoria: cat,
                  isEspansa: _espanse.contains(cat.documentId),
                  onTap: () {
                    setState(() {
                      if (_espanse.contains(cat.documentId)) {
                        _espanse.remove(cat.documentId);
                      } else {
                        _espanse.add(cat.documentId);
                      }
                    });
                  },
                  onDeleteTransazione: (documentId) async {
                    final token = requireToken(context);
                    if (token == null) return;
                    final ok = await context.read<TransazioneProvider>().elimina(token, documentId);
                    if (ok && context.mounted) {
                      context.read<DashboardProvider>().loadCategorie(
                        token,
                        context.read<WalletProvider>().selectedWallet!.documentId,
                        orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget navigatore mese separato per pulizia
class _NavigatoreMese extends StatelessWidget {
  final DashboardProvider dashboard;
  final String Function(int) nomeMese;

  const _NavigatoreMese({required this.dashboard, required this.nomeMese});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: dashboard.mesePrecedente,
        ),
        Text(
          '${nomeMese(dashboard.meseScelto.month)} ${dashboard.meseScelto.year}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          onPressed: dashboard.meseSuccessivo,
        ),
      ],
    );
  }
}

// Tre card riepilogative in alto
class _CardRiepilogo extends StatelessWidget {
  final DashboardProvider dashboard;
  final WalletProvider wallet;

  const _CardRiepilogo({required this.dashboard, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final rimanente = dashboard.totaleRimanente;
    final coloreRimanente = rimanente < 0 ? AppColors.error : AppColors.accent;

    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            label: 'Budget',
            valore: '€${dashboard.totaleBudget.toStringAsFixed(0)}',
            colore: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniCard(
            label: 'Spesi',
            valore: '€${dashboard.totaleSpesi.toStringAsFixed(0)}',
            colore: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniCard(
            label: 'Rimanenti',
            valore: '€${rimanente.toStringAsFixed(0)}',
            colore: coloreRimanente,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String valore;
  final Color colore;

  const _MiniCard({required this.label, required this.valore, required this.colore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            valore,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colore),
          ),
        ],
      ),
    );
  }
}

// Card categoria espandibile
class _CardCategoria extends StatelessWidget {
  final Category categoria;
  final bool isEspansa;
  final VoidCallback onTap;
  final void Function(String)? onDeleteTransazione;

  const _CardCategoria({
    required this.categoria,
    required this.isEspansa,
    required this.onTap,
    this.onDeleteTransazione,
  });

  @override
  Widget build(BuildContext context) {
    final spesi = categoria.transazionis.fold(0.0, (s, t) => s + t.importo);
    final rimanente = categoria.budgetCategoria - spesi;
    final percentuale = categoria.budgetCategoria > 0
        ? (spesi / categoria.budgetCategoria).clamp(0.0, 1.0)
        : 0.0;
    final coloreRimanente = rimanente < 0 ? AppColors.error : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Riga principale — tap per espandere/collassare
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (categoria.icona.isNotEmpty) ...[
                        Text(categoria.icona, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          categoria.nome,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Budget / Spesi / Rimanente inline
                      Text(
                        '€${spesi.toStringAsFixed(0)} / €${categoria.budgetCategoria.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '€${rimanente.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: coloreRimanente,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isEspansa ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar — equivalente della ProgressBar in Vue
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentuale,
                      minHeight: 6,
                      backgroundColor: AppColors.input,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rimanente < 0 ? AppColors.error : AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transazioni espanse — visibili solo se isEspansa
          if (isEspansa) ...[
            const Divider(color: AppColors.border, height: 1),
            if (categoria.transazionis.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nessuna transazione questo mese',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              ...categoria.transazionis.map(
                (t) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.descrizione.isNotEmpty ? t.descrizione : '—',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${t.data.day.toString().padLeft(2, '0')}/${t.data.month.toString().padLeft(2, '0')}/${t.data.year}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '€${t.importo.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (t.transazioneRicorrente) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
                      ],
                      const SizedBox(width: 4),
                      Consumer<TransazioneProvider>(
                        builder: (context, txProv, _) {
                          final inCorso = txProv.isEliminando(t.documentId);
                          return GestureDetector(
                            onTap: inCorso
                                ? null
                                : () => onDeleteTransazione?.call(t.documentId),
                            child: inCorso
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.error,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
