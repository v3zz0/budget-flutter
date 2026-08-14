import 'package:flutter_gemma/flutter_gemma.dart';

/// Modello Gemma 4 E2B che gira dentro il telefono, senza rete e senza che
/// nulla esca dal dispositivo.
///
/// Repo pubblica (Apache-2.0, non "gated"): nessun token Hugging Face.
class GemmaLocaleService {
  // Variante generica: gira su qualsiasi telefono. Esistono build ottimizzate
  // per singolo chip (es. _qualcomm_sm8750 per Snapdragon 8 Elite dell'S25)
  // che vanno un po' più veloci ma pesano di più: si cambiano queste due righe.
  static const String _file = 'gemma-4-E2B-it.litertlm';
  static const String _url =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$_file';

  static const double gbDaScaricare = 2.4;

  /// Il modello è già sul telefono?
  static Future<bool> installato() async {
    try {
      return await FlutterGemma.isModelInstalled(_file);
    } catch (_) {
      return false;
    }
  }

  /// Scarica il modello. [onProgress] riceve la percentuale 0-100.
  /// Su Android i download oltre i 500MB usano da soli un foreground service,
  /// così il sistema non li interrompe dopo 9 minuti.
  static Future<void> scarica({
    required void Function(int percentuale) onProgress,
    CancelToken? annulla,
  }) async {
    var installer = FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      // .litertlm si tratta come .task: i template di chat li gestisce il motore
      fileType: ModelFileType.task,
    ).fromNetwork(_url).withProgress(onProgress);

    if (annulla != null) installer = installer.withCancelToken(annulla);
    await installer.install();
  }

  static Future<void> elimina() => FlutterGemma.uninstallModel(_file);

  /// Una domanda, una risposta. Il prompt chiede sempre JSON, come per gli
  /// altri due motori, così la parte che legge la risposta è la stessa.
  static Future<String> chiedi(String prompt) async {
    final model = await FlutterGemma.getActiveModel(maxTokens: 1024);
    try {
      final chat = await model.createChat();
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final risposta = await chat.generateChatResponse();
      return risposta is TextResponse ? risposta.token : '';
    } finally {
      await model.close();
    }
  }
}
