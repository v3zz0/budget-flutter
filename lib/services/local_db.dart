import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../models/transazione_pendente.dart';

/// Il "quaderno" delle transazioni create offline, in attesa di essere
/// inviate al server. Una riga per transazione, chiave primaria [clientUuid].
///
/// Sta in un file suo (separato da [SyncService]) perché due cose la usano
/// in momenti diversi: il provider ci scrive appena una transazione non può
/// partire, il servizio di sync ci legge quando la rete torna.
class LocalDb {
  static Database? _db;
  static const _tabella = 'transazioni_pendenti';

  static Future<Database> _apri() async {
    if (_db != null) return _db!;
    final percorso = p.join(await getDatabasesPath(), 'budget_offline.db');
    _db = await openDatabase(
      percorso,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_tabella (
          clientUuid TEXT PRIMARY KEY,
          creataIl TEXT NOT NULL,
          transazioneJson TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  static Future<void> salva(TransazionePendente t) async {
    final db = await _apri();
    await db.insert(
      _tabella,
      {
        'clientUuid': t.clientUuid,
        'creataIl': t.creataIl.toIso8601String(),
        'transazioneJson': jsonEncode(_aMappa(t.transazione)),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TransazionePendente>> elenca() async {
    final db = await _apri();
    final righe = await db.query(_tabella, orderBy: 'creataIl ASC');
    return righe.map(_daRiga).toList();
  }

  static Future<void> rimuovi(String clientUuid) async {
    final db = await _apri();
    await db.delete(_tabella, where: 'clientUuid = ?', whereArgs: [clientUuid]);
  }

  // Serializzazione minima: bastano i campi che servono a ricostruire la
  // Transaction, non serve passare dal formato toJson() pensato per Strapi.
  static Map<String, dynamic> _aMappa(Transaction t) => {
        'importo': t.importo,
        'descrizione': t.descrizione,
        'data': t.data.toIso8601String(),
        'transazioneRicorrente': t.transazioneRicorrente,
        'ricorrenzaTemporale': t.ricorrenzaTemporale?.toIso8601String(),
        'contanti': t.contanti,
        'categoriaDocumentId': t.categoriaDocumentId,
        'clientUuid': t.clientUuid,
      };

  static TransazionePendente _daRiga(Map<String, Object?> riga) {
    final m = jsonDecode(riga['transazioneJson'] as String) as Map<String, dynamic>;
    final transazione = Transaction(
      documentId: '',
      importo: (m['importo'] as num).toDouble(),
      descrizione: m['descrizione'] as String,
      data: DateTime.parse(m['data'] as String),
      transazioneRicorrente: m['transazioneRicorrente'] as bool,
      ricorrenzaTemporale: m['ricorrenzaTemporale'] != null
          ? DateTime.parse(m['ricorrenzaTemporale'] as String)
          : null,
      contanti: m['contanti'] as bool,
      categoriaDocumentId: m['categoriaDocumentId'] as String,
      clientUuid: m['clientUuid'] as String?,
    );
    return TransazionePendente(
      clientUuid: riga['clientUuid'] as String,
      creataIl: DateTime.parse(riga['creataIl'] as String),
      transazione: transazione,
    );
  }
}
