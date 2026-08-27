import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_client.dart';

/// I motori selezionabili dalle impostazioni.
enum MotoreAi { ollama, openrouter, llamacpp }

MotoreAi motoreDaStringa(String? s) => switch (s) {
      'openrouter' => MotoreAi.openrouter,
      'llamacpp' => MotoreAi.llamacpp,
      _ => MotoreAi.ollama,
    };

class ImpostazioniAi {
  final MotoreAi motore;
  final String url;
  final String modello;
  final bool chiaveImpostata; // chiave OpenRouter — non torna mai dal server
  final bool chiaveLlamacppImpostata; // chiave llama.cpp, idem

  const ImpostazioniAi({
    this.motore = MotoreAi.ollama,
    this.url = '',
    this.modello = '',
    this.chiaveImpostata = false,
    this.chiaveLlamacppImpostata = false,
  });

  /// La chiave del motore attualmente selezionato è già salvata?
  bool get chiaveMotoreImpostata =>
      motore == MotoreAi.llamacpp ? chiaveLlamacppImpostata : chiaveImpostata;

  ImpostazioniAi copyWith({
    MotoreAi? motore,
    String? url,
    String? modello,
    bool? chiaveImpostata,
    bool? chiaveLlamacppImpostata,
  }) =>
      ImpostazioniAi(
        motore: motore ?? this.motore,
        url: url ?? this.url,
        modello: modello ?? this.modello,
        chiaveImpostata: chiaveImpostata ?? this.chiaveImpostata,
        chiaveLlamacppImpostata:
            chiaveLlamacppImpostata ?? this.chiaveLlamacppImpostata,
      );
}

class AiSettingsService {
  /// Legge le impostazioni AI da /api/users/me.
  /// La chiave non arriva mai (è `private` nello schema Strapi): sappiamo solo
  /// se è stata impostata.
  Future<ImpostazioniAi> carica(String token) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/users/me');
    final res = await ApiClient.get(url, token: token);
    if (res.statusCode != 200) throw Exception('Errore caricamento impostazioni AI');
    final j = jsonDecode(res.body);
    return ImpostazioniAi(
      motore: motoreDaStringa(j['aiMotore']),
      url: j['aiUrl'] ?? '',
      modello: j['aiModello'] ?? '',
      chiaveImpostata: j['aiChiaveImpostata'] ?? false,
      chiaveLlamacppImpostata: j['aiChiaveLlamacppImpostata'] ?? false,
    );
  }

  /// Salva su Strapi. [chiave] va passata solo se l'utente l'ha (ri)scritta:
  /// null lascia intatta quella già salvata.
  Future<void> salva(
    String token,
    int userId,
    ImpostazioniAi s, {
    String? chiave,
  }) async {
    final campoChiave =
        s.motore == MotoreAi.llamacpp ? 'aiChiaveLlamacpp' : 'aiChiave';
    final campoFlag = s.motore == MotoreAi.llamacpp
        ? 'aiChiaveLlamacppImpostata'
        : 'aiChiaveImpostata';
    final body = {
      'aiMotore': s.motore.name,
      'aiUrl': s.url,
      'aiModello': s.modello,
      if (chiave != null && chiave.isNotEmpty) ...{
        campoChiave: chiave,
        campoFlag: true,
      },
    };
    final url = Uri.parse('${Config.apiBaseUrl}/api/users/$userId');
    final res = await ApiClient.put(url, token: token, body: jsonEncode(body));
    if (res.statusCode != 200) throw Exception('Errore salvataggio impostazioni AI');
  }

  /// Prova la connessione col motore, usando i valori del form (anche non
  /// ancora salvati). Ritorna il messaggio da mostrare.
  Future<(bool, String)> prova(
    String token,
    ImpostazioniAi s, {
    String? chiave,
  }) async {
    final url = Uri.parse('${Config.apiBaseUrl}/api/analisi-test-ai');
    final res = await ApiClient.post(
      url,
      token: token,
      body: jsonEncode({
        'motore': s.motore.name,
        'url': s.url,
        'modello': s.modello,
        if (chiave != null && chiave.isNotEmpty) 'chiave': chiave,
      }),
    );
    if (res.statusCode != 200) return (false, 'Errore ${res.statusCode}');
    final j = jsonDecode(res.body);
    return (j['ok'] == true, (j['messaggio'] ?? '').toString());
  }

  /// Elenco modelli di OpenRouter (endpoint pubblico, nessuna chiave).
  /// I gratuiti (`:free`) vengono messi in cima.
  Future<List<String>> modelliOpenRouter() async {
    final res = await http
        .get(Uri.parse('https://openrouter.ai/api/v1/models'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Errore ${res.statusCode}');
    final dati = (jsonDecode(res.body)['data'] as List? ?? [])
        .map((m) => (m['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    dati.sort((a, b) {
      final aFree = a.endsWith(':free');
      final bFree = b.endsWith(':free');
      if (aFree != bFree) return aFree ? -1 : 1;
      return a.compareTo(b);
    });
    return dati;
  }
}
