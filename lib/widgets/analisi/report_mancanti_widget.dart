import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_analisi.dart';
import '../../theme.dart';

// Widget che mostra le transazioni trovate in banca ma NON registrate nell'app
class ReportMancantiWidget extends StatelessWidget {
  final List<TransazioneMancante> mancanti;

  const ReportMancantiWidget({super.key, required this.mancanti});

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
        ...mancanti.map((m) => _TransazioneRow(m: m, fmt: fmt, dateFmt: dateFmt)),
      ],
    );
  }
}

class _TransazioneRow extends StatelessWidget {
  final TransazioneMancante m;
  final NumberFormat fmt;
  final DateFormat dateFmt;

  const _TransazioneRow({required this.m, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    String dataLeggibile = m.data;
    try {
      dataLeggibile = dateFmt.format(DateTime.parse(m.data));
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
            fmt.format(m.importo),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
