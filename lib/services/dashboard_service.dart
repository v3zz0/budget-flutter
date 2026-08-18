import 'dart:convert';
import '../config.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import 'api_client.dart';

/// Quello che serve alla dashboard per un (portafoglio, mese).
class DatiDashboard {
  /// Categorie del portafoglio, con dentro le sole transazioni del mese chiesto.
  final List<Category> categorie;

  /// Template ricorrenti del portafoglio, di qualunque mese. Stanno a parte
  /// perché un template vive nel mese in cui è stato creato: filtrandoli per
  /// mese sparirebbero quasi sempre, e con loro le notifiche e la schermata
  /// delle ricorrenti.
  final List<Transaction> ricorrenti;

  const DatiDashboard({required this.categorie, required this.ricorrenti});
}

class DashboardService {
  /// Carica categorie e transazioni **del solo mese richiesto**.
  ///
  /// Prima era una chiamata sola con `populate=*`, che si tirava dietro tutte
  /// le transazioni mai registrate e le filtrava sul telefono. In Strapi 5 le
  /// relazioni popolate non si possono limitare né paginare, quindi il payload
  /// cresceva senza tetto: a 50 spese al mese, dopo tre anni erano 1800 record
  /// scaricati per aprire la home, a ogni refresh, salvataggio e cambio tab —
  /// col timeout di 15 secondi del client sempre più vicino.
  Future<DatiDashboard> loadCategories(
    String token,
    String walletDocumentId, {
    required DateTime mese,
  }) async {
    final primo = _iso(DateTime(mese.year, mese.month, 1));
    final ultimo = _iso(DateTime(mese.year, mese.month + 1, 0));

    final categorie = await _categorie(token, walletDocumentId);
    if (categorie.isEmpty) {
      return const DatiDashboard(categorie: [], ricorrenti: []);
    }

    // Due liste in parallelo: le spese del mese e i template ricorrenti.
    final risultati = await Future.wait([
      _transazioni(token, walletDocumentId, dal: primo, al: ultimo),
      _transazioni(token, walletDocumentId, soloRicorrenti: true),
    ]);
    final delMese = risultati[0];
    final ricorrenti = risultati[1];

    // Ricomposizione categoria → sue transazioni. Una mappa e non un
    // `where` per categoria: con 20 categorie e 300 spese sarebbero 6000 test.
    final perCategoria = <String, List<Transaction>>{};
    for (final t in delMese) {
      (perCategoria[t.categoriaDocumentId] ??= []).add(t);
    }

    return DatiDashboard(
      categorie: [
        for (final c in categorie)
          Category(
            documentId: c.documentId,
            nome: c.nome,
            budgetCategoria: c.budgetCategoria,
            walletDocumentId: c.walletDocumentId,
            icona: c.icona,
            transazionis: perCategoria[c.documentId] ?? const [],
          ),
      ],
      ricorrenti: ricorrenti,
    );
  }

  Future<List<Category>> _categorie(String token, String walletId) async {
    final uri = Uri.parse('${Config.apiBaseUrl}/api/categories').replace(
      queryParameters: {
        'filters[wallet][documentId][\$eq]': walletId,
        // Solo il wallet: le transazioni arrivano con la loro chiamata.
        'populate': 'wallet',
        'pagination[limit]': '100',
      },
    );
    final response = await ApiClient.get(uri, token: token);
    if (response.statusCode != 200) {
      throw Exception('Errore nel caricamento delle categorie: ${response.statusCode}');
    }
    final List items = jsonDecode(response.body)['data'] ?? [];
    return items.map((i) => Category.fromJson(i)).toList();
  }

  Future<List<Transaction>> _transazioni(
    String token,
    String walletId, {
    String? dal,
    String? al,
    bool soloRicorrenti = false,
  }) async {
    final query = {
      'filters[categorie][wallet][documentId][\$eq]': walletId,
      'populate': 'categorie',
      'sort': 'Data:desc',
      // 100 è il tetto imposto da config/api.js lato server. Un mese con più di
      // 100 spese non esiste in questo uso; i template ricorrenti sono qualche
      // decina. Se un giorno servisse di più, va paginato qui.
      'pagination[limit]': '100',
      'filters[Data][\$gte]': ?dal,
      'filters[Data][\$lte]': ?al,
      if (soloRicorrenti) 'filters[TransazioneRicorrente][\$eq]': 'true',
    };

    final uri = Uri.parse('${Config.apiBaseUrl}/api/transazionis')
        .replace(queryParameters: query);
    final response = await ApiClient.get(uri, token: token);
    if (response.statusCode != 200) {
      throw Exception('Errore nel caricamento delle transazioni: ${response.statusCode}');
    }
    final List items = jsonDecode(response.body)['data'] ?? [];
    return items.map((i) => Transaction.fromJson(i)).toList();
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
