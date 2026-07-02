import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_analisi.dart';
import '../../theme.dart';

// Banner in alto che mostra il giudizio sintetico dell'LLM + totali
class ReportGiudizioWidget extends StatelessWidget {
  final ReportAnalisi report;

  const ReportGiudizioWidget({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final sforato = report.totale.rimanente < 0;
    final colore = sforato ? AppColors.error : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colore.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sforato ? Icons.trending_down : Icons.trending_up,
                color: colore,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                sforato ? 'Mese sforato' : 'Mese in regola',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colore,
                ),
              ),
            ],
          ),
          if (report.giudizio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              report.giudizio,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: 'Budget',
                valore: fmt.format(report.totale.budget),
                colore: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Speso',
                valore: fmt.format(report.totale.speso),
                colore: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: sforato ? 'Sforato' : 'Risparmio',
                valore: fmt.format(report.totale.rimanente.abs()),
                colore: colore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String valore;
  final Color colore;

  const _MiniStat({required this.label, required this.valore, required this.colore});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            valore,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colore,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
