import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

/// Dialog per scegliere un mese (frecce sull'anno + griglia dei dodici mesi),
/// oppure il solo anno con [soloAnno].
///
/// Nato dentro analisi_screen.dart ed estratto qui quando è servito anche
/// all'export: showDatePicker non ha una modalità solo-mese, e riscriverne un
/// secondo avrebbe significato due dialog da tenere allineati.
///
/// Ritorna un DateTime col primo giorno del periodo scelto, oppure null se
/// l'utente annulla.
class MesePicker extends StatefulWidget {
  final DateTime iniziale;

  /// Nasconde la griglia dei mesi: restano solo le frecce dell'anno.
  final bool soloAnno;

  const MesePicker({
    super.key,
    required this.iniziale,
    this.soloAnno = false,
  });

  /// Scorciatoia: apre il dialog e restituisce la scelta.
  static Future<DateTime?> mostra(
    BuildContext context, {
    required DateTime iniziale,
    bool soloAnno = false,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => MesePicker(iniziale: iniziale, soloAnno: soloAnno),
    );
  }

  @override
  State<MesePicker> createState() => _MesePickerState();
}

class _MesePickerState extends State<MesePicker> {
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
      title: Text(
        widget.soloAnno ? 'Seleziona anno' : 'Seleziona mese',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Anno precedente',
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
                tooltip: 'Anno successivo',
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() => _anno++),
              ),
            ],
          ),
          if (!widget.soloAnno) ...[
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
                      color: selezionato ? AppColors.accent : AppColors.input,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mesi[i].substring(0, 3),
                      style: TextStyle(
                        color:
                            selezionato ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          // In modalità solo-anno il mese non conta: si torna gennaio, così
          // chi chiama ha comunque una data valida da cui ricavare l'anno.
          onPressed: () => Navigator.of(context)
              .pop(DateTime(_anno, widget.soloAnno ? 1 : _mese)),
          // Senza foregroundColor il testo prende onPrimary del tema, che è
          // rimasto al viola scuro di default: scritta illeggibile sul blu.
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
