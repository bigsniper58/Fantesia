#!/usr/bin/env bash
# Genere la partie Android du projet et applique la configuration necessaire.
# A lancer une seule fois, depuis la racine du projet.
set -e

echo "==> Verification de Flutter"
flutter --version

echo "==> Sauvegarde du code de l'application"
rm -rf .setup_backup
mkdir -p .setup_backup
cp -r lib pubspec.yaml .setup_backup/

echo "==> Generation de la coquille Android"
flutter create --platforms=android --org fr.fantesia --project-name fantesia .

echo "==> Restauration du code de l'application"
cp -r .setup_backup/lib .
cp .setup_backup/pubspec.yaml .
rm -rf .setup_backup

echo "==> Configuration du manifeste et du build Gradle"
python3 - <<'PY'
import re, os, glob

# --- AndroidManifest : permission reseau et nom affiche ---------------------
manifest = 'android/app/src/main/AndroidManifest.xml'
s = open(manifest, encoding='utf-8').read()

if 'android.permission.INTERNET' not in s:
    s = s.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n'
        '    <uses-permission android:name="android.permission.WAKE_LOCK"/>',
        1)

s = re.sub(r'android:label="[^"]*"', 'android:label="Fantesia"', s, count=1)

# Le lecteur gere lui-meme la rotation et le redimensionnement.
if 'android:configChanges' in s and 'screenLayout' not in s:
    s = s.replace(
        'android:configChanges="',
        'android:configChanges="screenLayout|smallestScreenSize|screenSize|',
        1)

open(manifest, 'w', encoding='utf-8').write(s)
print('  AndroidManifest.xml : ok')

# --- build.gradle : minSdk 23 requis par media_kit et webview --------------
for path in glob.glob('android/app/build.gradle*'):
    b = open(path, encoding='utf-8').read()
    b = b.replace('flutter.minSdkVersion', '23')
    b = re.sub(r'minSdk\s*=\s*\d+', 'minSdk = 23', b)
    b = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 23', b)
    open(path, 'w', encoding='utf-8').write(b)
    print(f'  {path} : minSdk 23')
PY

echo "==> Recuperation des dependances"
flutter pub get

echo
echo "Termine. Pour produire l'APK :"
echo "  flutter build apk --release --split-per-abi"
echo "L'APK se trouve dans build/app/outputs/flutter-apk/"
