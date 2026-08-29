import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../providers/dashboard_provider.dart';
import '../services/anno_service.dart';
import '../services/api_client.dart';
import '../services/transazioni_query.dart';
import '../theme.dart';

/// Riepilogo annuale del portafoglio aperto.
///
/// Sta in una schermata sua e non come modalità della dashboard di proposito:
/// il percorso mensile ha addosso notifiche, avvisi di soglia e push al widget
/// in home, tutti legati al mese selezionato. Infilarci una modalità anno
/// significherebbe rischiare di rompere cose che funzionano, per una vista di
/// sola lettura che si apre su richiesta.
class AnnoScreen extends StatefulWidget {
  final Wallet wallet;

  const AnnoScreen({super.key, required this.wallet});

  @override
  State<AnnoScreen> createState() => _AnnoScreenState();
}

class _AnnoScreenState extends State<AnnoScreen> {
  late int _anno = DateTime.now().year;

  RiepilogoAnno? _riepilogo;
  bool _caricando = true;
  String? _errore;

  /// Righe raccolte meno di quelle dichiarate dal server: il totale mostrato
  /// sarebbe più basso del vero, e va detto invece di lasciarlo passare.
  int _mancanti = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carica());
  }

  Future<void> _carica() async {
    final token = requireToken(context);
    if (token == null) return;

    setState(() {
      _caricando = true;
      _errore = null;
    });

    try {
      final esito = await TransazioniQuery.carica(
        token,
        dal: DateTime(_anno, 1, 1),
        al: DateTime(_anno, 12, 31),
        walletId: widget.wallet.documentId,
      );
      if (!mounted) return;

      setState(() {
        _riepilogo = AnnoService.calcola(
          anno: _anno,
          transazioni: esito.righe,
          // I budget vengono dalle categorie già caricate per questo
          // portafoglio: ci sono anche per le categorie senza spese.
          categorie: context.read<DashboardProvider>().categorie,
        );
        _mancanti = esito.completo ? 0 : esito.mancanti;
        _caricando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = erroreLeggibile(e);
        _caricando = false;
      });
    }
  }

  void _cambiaAnno(int passo) {
    setState(() => _anno += passo);
    _carica();
  }

  @override
  Widget build(BuildContext context) {
    final r = _riepilogo;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        title: Text('Anno · ${widget.wallet.nome}'),
      ),
      body: Column(
        children: [
          _NavigatoreAnno(
            anno: _anno,
            bloccato: _caricando,
            onCambia: _cambiaAnno,
          ),
          Expanded(
            child: _caricando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _errore != null
                    ? _Messaggio(testo: _errore!, errore: true)
                    : r == null || r.vuoto
                        ? _Messaggio(
                            testo: 'Nessuna spesa registrata nel $_anno.',
                          )
                        : _Contenuto(riepilogo: r, mancanti: _mancanti),
          ),
        ],
      ),
    );
  }
}

class _NavigatoreAnno extends StatelessWidget {
  final int anno;
  final bool bloccato;
  final void Function(int passo) onCambia;

  const _NavigatoreAnno({
    required this.anno,
    required this.bloccato,
    required this.onCambia,
  });

  @override
  Widget build(BuildContext context) {
    // Frecce spente durante il caricamento: un anno sono più pagine, e due tap
    // rapidi partirebbero in corsa fra loro.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            tooltip: 'Anno precedente',
            onPressed: bloccato ? null : () => onCambia(-1),
          ),
          Text(
            '$anno',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            tooltip: 'Anno successivo',
            onPressed: bloccato ? null : () => onCambia(1),
          ),
        ],
      ),
    );
  }
}

class _Messaggio extends StatelessWidget {
  final String testo;
  final bool errore;

  const _Messaggio({required this.testo, this.errore = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          testo,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: errore ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Contenuto extends StatelessWidget {
  final RiepilogoAnno riepilogo;
  final int mancanti;

  const _Contenuto({required this.riepilogo, required this.mancanti});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (mancanti > 0) ...[
          _Avviso(
            testo: 'Mancano $mancanti transazioni: il totale qui sotto è più '
                'basso di quello reale. Riprova, o segnalalo se si ripete.',
          ),
          const SizedBox(height: 12),
        ],
        _CardTotale(riepilogo: riepilogo),
        const SizedBox(height: 16),
        _GraficoMesi(perMese: riepilogo.perMese),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PER CATEGORIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...riepilogo.categorie
            .where((c) => c.speso > 0 || c.budgetStimato > 0)
            .map((c) => _RigaCategoria(categoria: c)),
        const SizedBox(height: 16),
        const _NotaStima(),
      ],
    );
  }
}

class _Avviso extends StatelessWidget {
  final String testo;
  const _Avviso({required this.testo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              testo,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTotale extends StatelessWidget {
  final RiepilogoAnno riepilogo;
  const _CardTotale({required this.riepilogo});

  @override
  Widget build(BuildContext context) {
    final stima = riepilogo.budgetStimato;

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
          const Text(
            'SPESO NELL\'ANNO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '€${riepilogo.speso.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (stima > 0) ...[
            const SizedBox(height: 6),
            Text(
              'su €${stima.toStringAsFixed(0)} di budget stimato '
              '(${riepilogo.mesiConsiderati} mesi)',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barre mese per mese. Stile ripreso da salvadanaio_screen.dart, che è già la
/// convenzione dei grafici in questa app.
class _GraficoMesi extends StatelessWidget {
  final List<double> perMese;
  const _GraficoMesi({required this.perMese});

  static const _nomi = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final massimo = perMese.fold<double>(0, math.max);
    final ora = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: math.max(massimo * 1.4, 100),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.input,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${_nomi[group.x]}\n${rod.toY.toStringAsFixed(0)}€',
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i > 11) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      // Solo le iniziali: dodici etichette intere non ci stanno
                      // sulla larghezza di un telefono.
                      child: Text(
                        _nomi[i].substring(0, 1),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(12, (i) {
              final corrente = i + 1 == ora.month;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: perMese[i],
                    color: corrente
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.45),
                    width: 14,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }
}

class _RigaCategoria extends StatelessWidget {
  final CategoriaAnno categoria;
  const _RigaCategoria({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final perc = categoria.percentuale;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (categoria.icona.isNotEmpty) ...[
                Text(categoria.icona, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  categoria.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '€${categoria.speso.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: categoria.oltreStima
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (categoria.budgetStimato > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (perc ?? 0).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.input,
                color:
                    categoria.oltreStima ? AppColors.error : AppColors.accent,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'stima budget €${categoria.budgetStimato.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Perché il budget annuo è una stima. Va detto: un numero derivato che si
/// presenta come rilevato è peggio di un numero assente.
class _NotaStima extends StatelessWidget {
  const _NotaStima();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Lo speso è esatto. Il budget annuo è una stima: l\'app conserva solo '
        'il budget attuale di ogni categoria, non lo storico, quindi se durante '
        'l\'anno l\'hai cambiato la stima non lo riflette.',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
