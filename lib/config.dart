class Config {
  // URL del backend Strapi. Impostalo alla build/run con --dart-define, es:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:1337   (emulatore Android)
  //   flutter build apk --dart-define=API_BASE_URL=https://tuo-backend.example.com
  // Il default qui sotto è un placeholder: sostituiscilo o passa sempre --dart-define.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:1337',
  );
}
