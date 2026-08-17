import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/report_analisi.dart';
import '../../models/transaction.dart';
import '../../providers/analisi_provider.dart';
import '../../providers/transazione_provider.dart';
import '../../services/api_client.dart';
import '../../theme.dart';

// Widget che mostra le transazioni trovate in banca ma NON registrate nell'app,
// con il tasto per registrarle senza riscriverle a mano: data, descrizione e
// importo li ha già letti l'analisi, l'unica cosa che manca è la categoria.
class ReportMancantiWidget extends StatelessWidget {
  final List<TransazioneMancante> mancanti;

  // Le categorie del portafoglio arrivano dagli sforamenti dello stesso report:
  // hanno già nome e documentId, quindi non serve nessuna chiamata in più.
  final List<SforatoCategoria> categorie;

  const ReportMancantiWidget({
    super.key,
    required this.mancanti,
    required this.categorie,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFmt = DateFormat('dd MMM', 'it_IT');

    if (mancanti.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981), width: 1),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tutte le transazioni dell\'estratto sono registrate nell\'app',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEAB308), size: 18),
              const SizedBox(width: 6),
              Text(
                'Transazioni mancanti (${mancanti.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Movimenti presenti in banca ma non registrati nell\'app',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        ...mancanti.map((m) => _TransazioneRow(
              m: m,
              fmt: fmt,
              dateFmt: dateFmt,
              categorie: categorie,
            )),
      ],
    );
  }
}

class _TransazioneRow extends StatefulWidget {
  final TransazioneMancante m;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final List<SforatoCategoria> categorie;

  const _TransazioneRow({
    required this.m,
    required this.fmt,
    required this.dateFmt,
    required this.categorie,
  });

  @override
  State<_TransazioneRow> createState() => _TransazioneRowState();
}

class _TransazioneRowState extends State<_TransazioneRow> {
  bool _salvando = false;

  Future<void> _aggiungi() async {
    final m = widget.m;
    if (widget.categorie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna categoria disponibile nel portafoglio')),
      );
      return;
    }

    final categoriaId = await _scegliCategoria(context, m, widget.categorie);
    if (categoriaId == null || !mounted) return; // annullato

    final token = requireToken(context);
    if (token == null) return;

    setState(() => _salvando = true);
    final ok = await context.read<TransazioneProvider>().salva(
          token,
          Transaction(
            documentId: '', // lo assegna Strapi alla creazione
            importo: m.importo,
            descrizione: m.descrizione,
            data: DateTime.parse(m.data),
            transazioneRicorrente: false,
            categoriaDocumentId: categoriaId,
          ),
        );
    if (!mounted) return;
    setState(() => _salvando = false);

    if (ok) {
      // Registrata: sparisce dall'elenco dei mancanti, che è esattamente
      // quello che significa "mancante" — non c'è più.
      context.read<AnalisiProvider>().rimuoviMancante(m);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${m.descrizione} aggiunta')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<TransazioneProvider>().errore ?? 'Errore nel salvataggio',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    String dataLeggibile = m.data;
    try {
      dataLeggibile = widget.dateFmt.format(DateTime.parse(m.data));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.descrizione,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      dataLeggibile,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (m.categoriaSuggerita != null &&
                        m.categoriaSuggerita!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.categoriaSuggerita!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            widget.fmt.format(m.importo),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          _salvando
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _aggiungi,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.accent,
                  tooltip: 'Registra nell\'app',
                  visualDensity: VisualDensity.compact,
                ),
        ],
      ),
    );
  }
}

/// Chiede la categoria e mostra cosa verrà registrato. Data, descrizione e
/// importo arrivano dall'estratto conto e non si toccano qui: se qualcosa non
/// va, la transazione si corregge dalla dashboard come tutte le altre.
Future<String?> _scegliCategoria(
  BuildContext context,
  TransazioneMancante m,
  List<SforatoCategoria> categorie,
) {
  // Preselezione col suggerimento dell'AI, quando c'è e corrisponde davvero a
  // una categoria del portafoglio.
  final suggerita = categorie
      .where((c) => c.nome.toLowerCase() == (m.categoriaSuggerita ?? '').toLowerCase())
      .firstOrNull;
  String? scelta = suggerita?.documentId;

  final fmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Registra transazione',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.descrizione,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${m.data}  ·  ${fmt.format(m.importo)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: scelta,
              isExpanded: true,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Categoria',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(),
              ),
              items: categorie
                  .map((c) => DropdownMenuItem(value: c.documentId, child: Text(c.nome)))
                  .toList(),
              onChanged: (v) => setStateDialog(() => scelta = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: scelta == null ? null : () => Navigator.pop(ctx, scelta),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    ),
  );
}
