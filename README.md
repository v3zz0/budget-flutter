# Budget Flutter

App Flutter (Android) per la gestione del budget personale multi-portafoglio.
Consuma le API del backend Strapi ([budget-api](https://github.com/v3zz0/budget-api)).

## ✅ Prerequisiti

- **Flutter SDK** `>= 3.11` (`flutter doctor` per verificare l'ambiente)
- Il backend [budget-api](https://github.com/v3zz0/budget-api) in esecuzione e raggiungibile

## ⚙️ Configurazione backend (`API_BASE_URL`)

L'URL del backend **non è hardcoded**: si passa a run/build time con `--dart-define`.

```bash
flutter pub get

# Sviluppo su emulatore Android (10.0.2.2 = localhost dell'host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:1337

# Build release puntando al tuo backend
flutter build apk --release --dart-define=API_BASE_URL=https://tuo-backend
```

Se non passi `--dart-define`, il default è `http://localhost:1337` (vedi `lib/config.dart`).

## Comandi build

### Eseguire nel browser (web)

```bash
# Abilita il supporto web (solo la prima volta)
flutter config --enable-web

# Verifica che Chrome sia rilevato come device
flutter devices

# Avvia in modalità debug su Chrome (hot reload attivo)
flutter run -d chrome

# Avvia su una porta fissa (utile per CORS lato Strapi)
flutter run -d chrome --web-port=8080

# Avvia su un altro browser installato (es. Edge, Firefox via web-server)
flutter run -d web-server --web-port=8080
# Poi apri manualmente http://localhost:8080
```

#### Build release per il web

```bash
# Build ottimizzata (output statico in build/web/)
flutter build web --release

# Servila localmente per testare il bundle compilato
cd build/web && python3 -m http.server 8080
# Poi apri http://localhost:8080
```

#### Note importanti per il web

- **CORS:** Strapi deve permettere l'origine del browser. In `budget-api/config/middlewares.js`
  controlla che `strapi::cors` includa `http://localhost:8080` (o la porta che usi)
  nell'array `origin`. Altrimenti le chiamate API falliscono con errori CORS.
- **JWT storage:** su web `flutter_secure_storage` usa `localStorage` come fallback —
  funziona ma è meno sicuro che su mobile (XSS può leggerlo). Per uso personale va bene.
- **Hot reload:** premi `r` nel terminale dopo modifiche per ricaricare senza riavviare.
- **Performance debug vs release:** in `flutter run -d chrome` la versione è in debug
  (lenta, con assertions). Per testare le performance reali usa `flutter build web --release`
  e servila.

### Eseguire su Linux (desktop)

```bash
# Abilita il supporto Linux (solo la prima volta)
flutter config --enable-linux-desktop

# Avvia in modalità debug su Linux
flutter run -d linux

# Build release per Linux
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### Eseguire su telefono Android collegato via USB

```bash
# Verifica che il telefono sia rilevato (USB debugging abilitato sul telefono)
flutter devices

# Avvia in modalità debug sul telefono
flutter run

# Se ci sono più dispositivi, specifica l'ID del telefono
flutter run -d <device-id>
```

### Build APK Android

```bash
# APK debug (per test rapidi)
flutter build apk --debug

# APK release (per distribuzione) — APK universale ~50-70 MB
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# APK divisi per architettura (file più leggeri ~20-22 MB ciascuno)
flutter build apk --split-per-abi --release
# Output:
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (vecchi smartphone 32-bit)
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    (smartphone moderni 64-bit)
#   build/app/outputs/flutter-apk/app-x86_64-release.apk       (emulatori)
```

#### Quale build scegliere

| Scenario | Comando | APK da installare |
| --- | --- | --- |
| Un solo dispositivo (smartphone moderno) | `--split-per-abi --release` | `app-arm64-v8a-release.apk` |
| Distribuire a più persone con dispositivi diversi | `--release` (universale) | `app-release.apk` |
| Pubblicare sul Play Store | `flutter build appbundle --release` | (AAB, lo Store seleziona da solo) |

**Consiglio:** la maggior parte degli smartphone moderni (64-bit) usa l'architettura
`arm64-v8a`. Per un singolo dispositivo conviene `--split-per-abi` e installare solo
`app-arm64-v8a-release.apk` (~22 MB) invece dell'APK universale (~65 MB): trasferimento
più veloce e ~40 MB di spazio risparmiato sul telefono.

#### Differenza tecnica tra le due build

- **APK universale (`--release`):** contiene il codice nativo per tutte e tre
  le architetture (`armeabi-v7a`, `arm64-v8a`, `x86_64`) in un unico file.
  Più semplice da condividere ma porta con sé 2 architetture su 3 inutili.
- **APK split (`--split-per-abi --release`):** genera 3 APK separati, uno per
  architettura. Ogni file pesa ~30-50% meno ma devi scegliere quello giusto
  per il dispositivo target.

### Installare l'APK direttamente sul telefono collegato

```bash
flutter install
```

### Comandi utili

```bash
# Controlla dipendenze e ambiente
flutter doctor

# Scarica le dipendenze
flutter pub get

# Pulisce la cache di build
flutter clean
```
