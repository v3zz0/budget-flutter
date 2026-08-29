import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/wallet_provider.dart';
import '../services/api_client.dart';
import '../services/export_service.dart';
import '../services/ricorrenza.dart';
import '../theme.dart';
import '../widgets/mese_picker.dart';

enum AmbitoExport { tutto, anno, mese }

/// Export delle transazioni in CSV.
///
/// Sta in Impostazioni e non più nella AppBar della dashboard: lì l'ambito era
/// implicito (il portafoglio aperto, il mese visualizzato) e non c'era spazio
/// per sceglierlo. Qui l'ambito è esplicito e copre tutti i portafogli.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _service = ExportService();

  AmbitoExport _ambito = AmbitoExport.tutto;
  DateTime _periodo = DateTime.now();
  bool _inCorso = false;

  Future<void> _scegliPeriodo() async {
    final scelta = await MesePicker.mostra(
      context,
      iniziale: _periodo,
      soloAnno: _ambito == AmbitoExport.anno,
    );
    if (scelta != null) setState(() => _periodo = scelta);
  }

  String get _etichettaPeriodo {
    if (_ambito == AmbitoExport.anno) return '${_periodo.year}';
    return '${_periodo.year}-${_periodo.month.toString().padLeft(2, '0')}';
  }

  /// Intervallo di date corrispondente all'ambito scelto.
  ({DateTime? dal, DateTime? al}) get _intervallo {
    switch (_ambito) {
      case AmbitoExport.tutto:
        return (dal: null, al: null);
      case AmbitoExport.anno:
        return (
          dal: DateTime(_periodo.year, 1, 1),
          al: DateTime(_periodo.year, 12, 31),
        );
      case AmbitoExport.mese:
        final ultimo = Ricorrenza.ultimoGiornoDelMese(
          _periodo.year,
          _periodo.month,
        );
        return (
          dal: DateTime(_periodo.year, _periodo.month, 1),
          al: DateTime(_periodo.year, _periodo.month, ultimo),
        );
    }
  }

  String get _nomeFile {
    switch (_ambito) {
      case AmbitoExport.tutto:
        return 'budget_tutto.csv';
      case AmbitoExport.anno:
        return 'budget_${_periodo.year}.csv';
      case AmbitoExport.mese:
        return 'budget_$_etichettaPeriodo.csv';
    }
  }

  Future<void> _esporta() async {
    final token = requireToken(context);
    if (token == null) return;

    // I portafogli esclusi dalle statistiche non entrano nel file: sono
    // promemoria di scadenze, non spesa corrente, e sporcherebbero l'analisi.
    final esclusi = context
        .read<WalletProvider>()
        .wallets
        .where((w) => w.esclusoDaStatistiche)
        .map((w) => w.nome)
        .toSet();

    setState(() => _inCorso = true);
    try {
      final intervallo = _intervallo;
      final esito = await _service.carica(
        token,
        dal: intervallo.dal,
        al: intervallo.al,
        portafogliEsclusi: esclusi,
      );

      if (!mounted) return;

      if (esito.righe.isEmpty) {
        _avviso('Nessuna transazione da esportare in questo periodo');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_nomeFile');
      await file.writeAsString(generaCsv(esito.righe));
      await Share.shareXFiles([XFile(file.path)], subject: 'Export $_nomeFile');

      if (!mounted) return;

      // Un export incompleto deve dirlo: un file che sembra completo e non lo è
      // porta a conclusioni sbagliate senza dare nessun segnale.
      if (!esito.completo) {
        _avviso(
          'Attenzione: esportate ${esito.righe.length} righe ma il server ne '
          'dichiarava ${esito.totaleDichiarato}. Ne mancano ${esito.mancanti}.',
          errore: true,
        );
      } else {
        final extra = esito.escluse > 0
            ? ' (${esito.escluse} da portafogli esclusi)'
            : '';
        _avviso('${esito.righe.length} transazioni esportate$extra');
      }
    } catch (e) {
      if (mounted) _avviso(erroreLeggibile(e), errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  void _avviso(String messaggio, {bool errore = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        backgroundColor: errore ? AppColors.error : AppColors.accent,
        duration: Duration(seconds: errore ? 6 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esclusi = context
        .watch<WalletProvider>()
        .wallets
        .where((w) => w.esclusoDaStatistiche)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Esporta dati'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Un file CSV con una riga per transazione: data, importo, '
            'descrizione, categoria, budget e portafoglio. Comprende tutti i '
            'portafogli.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _opzione(AmbitoExport.tutto, Icons.all_inclusive, 'Tutto lo storico',
              'Ogni transazione mai registrata'),
          _opzione(AmbitoExport.anno, Icons.calendar_today_outlined, 'Un anno',
              'Dal 1° gennaio al 31 dicembre'),
          _opzione(AmbitoExport.mese, Icons.calendar_view_month, 'Un mese',
              'Un mese solo'),

          if (_ambito != AmbitoExport.tutto) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: _inCorso ? null : _scegliPeriodo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _ambito == AmbitoExport.anno
                            ? 'Anno da esportare'
                            : 'Mese da esportare',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    Text(
                      _etichettaPeriodo,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],

          if (esclusi.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Esclusi dall\'export: ${esclusi.map((w) => w.nome).join(', ')}. '
              'Puoi cambiarlo in Portafogli e budget.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _inCorso ? null : _esporta,
            icon: _inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(_inCorso ? 'Preparo il file…' : 'Esporta CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stessa forma delle scelte del motore AI in Impostazioni: una card col
  /// pallino, invece di RadioListTile che in questa versione di Flutter è
  /// deprecato a favore di RadioGroup.
  Widget _opzione(
    AmbitoExport valore,
    IconData icona,
    String titolo,
    String sottotitolo,
  ) {
    final attivo = _ambito == valore;
    return GestureDetector(
      onTap: _inCorso ? null : () => setState(() => _ambito = valore),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              attivo ? AppColors.accent.withValues(alpha: 0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: attivo ? AppColors.accent : AppColors.border,
            width: attivo ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icona,
                color: attivo ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: TextStyle(
                      color: attivo ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sottotitolo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              attivo
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: attivo ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
