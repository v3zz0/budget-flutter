#!/bin/bash

# Build + release dell'APK su GitHub Releases.
#
# Uso:  ./pusherapk.sh          → bump patch automatico (1.0.2 → 1.0.3)
#       ./pusherapk.sh 1.1.0    → versione esplicita (minor/major)
#
# La versione vive in pubspec.yaml, non qui dentro: unica fonte di verità.

# ─── CONFIGURAZIONE ───────────────────────────────────────────────────────────
APP_NAME="BudgetApp"
# ──────────────────────────────────────────────────────────────────────────────

set -e
cd "$(dirname "$0")"

# Versione corrente da pubspec.yaml, formato "1.0.2+3"
CURRENT=$(grep -m1 '^version:' pubspec.yaml | sed 's/^version: *//')
CUR_NAME="${CURRENT%%+*}"
CUR_BUILD="${CURRENT##*+}"

# Nuova versione: argomento esplicito, altrimenti patch + 1
NEW_NAME="${1:-${CUR_NAME%.*}.$(( ${CUR_NAME##*.} + 1 ))}"
NEW_BUILD=$(( CUR_BUILD + 1 ))
TAG="v${NEW_NAME}"

echo "==> Release: ${CURRENT} → ${NEW_NAME}+${NEW_BUILD}  (tag ${TAG})"

# Controlli preliminari
command -v flutter > /dev/null || { echo "Errore: flutter non trovato."; exit 1; }

if ! gh auth status > /dev/null 2>&1; then
    echo "Errore: gh non autenticato. Lancia 'gh auth login'."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Errore: hai modifiche non committate. Committa prima di rilasciare."
    exit 1
fi

if git ls-remote --exit-code --tags origin "$TAG" > /dev/null 2>&1; then
    echo "Errore: il tag ${TAG} esiste già."
    exit 1
fi

# Bump PRIMA della build, così l'APK contiene il numero di versione giusto
sed -i "s/^version: .*/version: ${NEW_NAME}+${NEW_BUILD}/" pubspec.yaml
git commit -qam "$TAG"
git push -q

# Build
echo ""
echo "==> Build APK release..."
flutter build apk --release

# Il nome del file DIVENTA il nome dell'asset, ed è quello che compare
# nell'URL /releases/latest/download/. Tenerlo fisso = link permanente.
APK="build/app/outputs/flutter-apk/${APP_NAME}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$APK"

# Release
echo ""
echo "==> Upload su GitHub Releases..."
gh release create "$TAG" "$APK" --title "${APP_NAME} ${TAG}" --generate-notes

echo ""
echo "==> Fatto! ${TAG} ($(du -h "$APK" | cut -f1))"
echo "    Link download sempre aggiornato (da salvare sul telefono):"
echo "    $(gh repo view --json url -q .url)/releases/latest/download/${APP_NAME}.apk"
