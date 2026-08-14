import 'dart:convert';
import '../config.dart';
import '../models/consiglio.dart';
import 'api_client.dart';

class ConsiglioService {
  /// Consigli ancora attivi (i "applicato" e "ignorato" restano nello storico
  /// lato server ma non servono nell'app).
  Future<List<Consiglio>> carica(String token) async {
    final url = Uri.parse(
      '${Config.apiBaseUrl}/api/consiglios'
      '?populate=categorie'
      '&filters[stato][\$in][0]=nuovo'
      '&filters[stato][\$in][1]=letto'
      '&sort=createdAt:desc',
    );
    final res = await ApiClient.get(url, token: token);
    if (res.statusCode != 200) throw Exception('Errore caricamento consigli');
    final data = jsonDecode(res.body)['data'] as List? ?? [];
    return data.map((e) => Consiglio.fromJson(e)).toList();
  }

  /// Scrive il budget proposto sulla categoria.
  Future<void> applica(String token, String documentId) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/consiglios/$documentId/applica');
    final res = await ApiClient.post(url, token: token);
    if (res.statusCode != 200) throw Exception('Errore applicazione consiglio');
  }

  /// stato: "letto" (spegne il pallino) oppure "ignorato" (toglie dalla lista).
  Future<void> segna(String token, String documentId, String stato) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/consiglios/$documentId/segna');
    final res = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode({'stato': stato}),
    );
    if (res.statusCode != 200) throw Exception('Errore aggiornamento consiglio');
  }
}
