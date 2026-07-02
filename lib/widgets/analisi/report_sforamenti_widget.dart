import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_analisi.dart';
import '../../theme.dart';

// Widget che mostra l'elenco categorie con budget/speso/rimanente
// Sforate evidenziate in rosso, in regola in verde
class ReportSforamentiWidget extends StatelessWidget {
  final List<SforatoCategoria> sforamenti;

  const ReportSforamentiWidget({super.key, required this.sforamenti});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    if (sforamenti.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Categorie del mese',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ...sforamenti.map((c) => _CategoriaRow(cat: c, fmt: fmt)),
      ],
    );
  }
}

class _CategoriaRow extends StatelessWidget {
  final SforatoCategoria cat;
  final NumberFormat fmt;

  const _CategoriaRow({required this.cat, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final percentuale = cat.budget > 0 ? (cat.speso / cat.budget).clamp(0.0, 1.5) : 0.0;
    final coloreBarra = cat.sforato ? AppColors.error : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cat.icona != null && cat.icona!.isNotEmpty) ...[
                Text(cat.icona!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  cat.nome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                cat.sforato
                    ? 'Sforato di ${fmt.format(cat.rimanente.abs())}'
                    : '${fmt.format(cat.rimanente)} rimasti',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: coloreBarra,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentuale > 1 ? 1 : percentuale,
              minHeight: 6,
              backgroundColor: AppColors.input,
              valueColor: AlwaysStoppedAnimation(coloreBarra),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${fmt.format(cat.speso)} / ${fmt.format(cat.budget)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
