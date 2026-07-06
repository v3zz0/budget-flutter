import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/analisi_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/analisi_service.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/analisi/report_giudizio_widget.dart';
import '../widgets/analisi/report_mancanti_widget.dart';
import '../widgets/analisi/report_sforamenti_widget.dart';

// Schermata per analizzare un estratto conto PDF
// Flusso: seleziona PDF + mese → upload al backend → mostra report
class AnalisiScreen extends StatefulWidget {
  const AnalisiScreen({super.key});

  @override
  State<AnalisiScreen> createState() => _AnalisiScreenState();
}

class _AnalisiScreenState extends State<AnalisiScreen> {
  @override
  void initState() {
    super.initState();
    // Default: mese corrente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AnalisiProvider>();
      if (provider.meseSelezionato == null) {
        final ora = DateTime.now();
        final m = '${ora.year}-${ora.month.toString().padLeft(2, '0')}';
        provider.setMese(m);
      }
    });
  }

  Future<void> _selezionaDocumenti() async {
    // Selezione multipla: PDF o CSV, anche da conti diversi.
    // Su web il picker legge i bytes in memoria — `path` non esiste.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final docs = <AnalisiDoc>[];
    for (final picked in result.files) {
      if (kIsWeb) {
        if (picked.bytes == null) continue;
        docs.add(AnalisiDoc(bytes: picked.bytes, nome: picked.name));
      } else {
        if (picked.path == null) continue;
        docs.add(AnalisiDoc(file: File(picked.path!), nome: picked.name));
      }
    }
    if (docs.isNotEmpty) {
      context.read<AnalisiProvider>().aggiungiDocs(docs);
    }
  }

  Future<void> _selezionaMese() async {
    final provider = context.read<AnalisiProvider>();
    final ora = DateTime.now();
    DateTime iniziale = ora;
    if (provider.meseSelezionato != null) {
      try {
        iniziale = DateFormat('yyyy-MM').parse(provider.meseSelezionato!);
      } catch (_) {}
    }

    // Picker mese: showDatePicker non ha modalità solo-mese, usiamo un dialog custom semplice
    final scelta = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MesePicker(iniziale: iniziale),
    );
    if (scelta == null || !mounted) return;
    final m = '${scelta.year}-${scelta.month.toString().padLeft(2, '0')}';
    provider.setMese(m);
  }

  Future<void> _analizza() async {
    final token = requireToken(context);
    if (token == null) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un wallet')),
      );
      return;
    }

    await context.read<AnalisiProvider>().analizza(
      token: token,
      walletId: wallet.selectedWallet!.documentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalisiProvider>();
    final report = provider.report;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analisi estratto conto',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Carica uno o più estratti (PDF o CSV), anche da conti diversi: '
                'l\'AI li confronta insieme con le transazioni registrate',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              _SelectorCard(
                icona: Icons.upload_file,
                titolo: 'Documenti (PDF o CSV)',
                valore: provider.hasDoc
                    ? '${provider.docs.length} file selezionati'
                    : 'Nessun file selezionato',
                onTap: provider.isLoading ? null : _selezionaDocumenti,
              ),
              // Lista dei documenti scelti, con rimozione singola
              ...provider.docs.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      InkWell(
                        onTap: provider.isLoading
                            ? null
                            : () => context
                                .read<AnalisiProvider>()
                                .rimuoviDoc(i),
                        child: const Icon(Icons.close,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              _SelectorCard(
                icona: Icons.calendar_month,
                titolo: 'Mese da analizzare',
                valore: provider.meseSelezionato ?? '—',
                onTap: provider.isLoading ? null : _selezionaMese,
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (provider.pronto && !provider.isLoading) ? _analizza : null,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(provider.isLoading ? 'Analisi in corso…' : 'Analizza'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              if (provider.isLoading) ...[
                const SizedBox(height: 12),
                const Text(
                  'L\'AI sta leggendo il PDF e confrontando le transazioni.\n'
                  'L\'operazione può durare anche 30-60 secondi.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],

              if (provider.errore != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errore!,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (report != null) ...[
                const SizedBox(height: 20),
                if (!report.validazione.ok && report.validazione.warning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFEAB308), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFEAB308)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report.validazione.warning!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ReportGiudizioWidget(report: report),
                const SizedBox(height: 16),
                ReportSforamentiWidget(sforamenti: report.sforamenti),
                const SizedBox(height: 8),
                ReportMancantiWidget(mancanti: report.mancanti),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String valore;
  final VoidCallback? onTap;

  const _SelectorCard({
    required this.icona,
    required this.titolo,
    required this.valore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icona, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valore,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// Picker semplice per mese/anno
class _MesePicker extends StatefulWidget {
  final DateTime iniziale;
  const _MesePicker({required this.iniziale});

  @override
  State<_MesePicker> createState() => _MesePickerState();
}

class _MesePickerState extends State<_MesePicker> {
  late int _anno;
  late int _mese;

  @override
  void initState() {
    super.initState();
    _anno = widget.iniziale.year;
    _mese = widget.iniziale.month;
  }

  @override
  Widget build(BuildContext context) {
    final mesi = List.generate(12, (i) {
      return DateFormat.MMMM('it_IT').format(DateTime(2000, i + 1));
    });

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Seleziona mese',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() => _anno--),
              ),
              Text(
                _anno.toString(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() => _anno++),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final selezionato = (i + 1) == _mese;
              return GestureDetector(
                onTap: () => setState(() => _mese = i + 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selezionato
                        ? AppColors.accent
                        : AppColors.input,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mesi[i].substring(0, 3),
                    style: TextStyle(
                      color: selezionato
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(DateTime(_anno, _mese)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
