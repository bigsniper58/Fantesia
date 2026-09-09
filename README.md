# Fantesia

Client Android pour le serveur Jellyfin `jellyfin.fantesia.fr`.

L'adresse du serveur est inscrite dans l'application : au lancement, l'écran
de connexion demande uniquement un identifiant et un mot de passe.

## Ce que fait l'application

- Connexion avec le compte Jellyfin, session conservée entre deux ouvertures
- Accueil : reprendre la lecture, prochains épisodes, derniers ajouts
- Médiathèque par bibliothèque, avec tri et chargement au défilement
- Fiche film et fiche série avec saisons, épisodes et titres similaires
- Recherche sur les films, séries et épisodes
- Lecteur plein écran : pistes audio, sous-titres, avance de 10 et 30 secondes
- **Choix de la définition** (Automatique, 4K, 1440p, 1080p, 720p, 480p, 360p)
  au lieu du débit, modifiable en cours de lecture sans perdre la position
- Favoris, marquage vu, progression renvoyée au serveur
- Onglet Demandes ouvrant Jellyseerr (`seer.fantesia.fr`) dans l'application
- Lien vers JFA-GO (`jfa.fantesia.fr`) pour la gestion du compte

## Compiler l'APK

### Option A — sans rien installer, via GitHub

1. Crée un dépôt GitHub et pousse ce dossier dedans.
2. Onglet **Actions** → **Compiler l'APK** → **Run workflow**.
3. Au bout de 5 à 10 minutes, télécharge l'artefact `fantesia-apk`.

`app-arm64-v8a-release.apk` convient à tous les téléphones récents.
`app-release.apk` est l'APK universel, plus lourd mais compatible partout.

### Option B — sur ta machine

Il faut [Flutter](https://docs.flutter.dev/get-started/install) 3.29 ou plus
récent et le SDK Android.

```bash
chmod +x setup.sh
./setup.sh
flutter build apk --release --split-per-abi
```

L'APK sort dans `build/app/outputs/flutter-apk/`.

`setup.sh` génère le dossier `android/` (absent du dépôt, car Flutter le crée
lui-même) puis applique la permission réseau, le nom de l'application et
`minSdk 23`. Il ne touche pas au dossier `lib/`.

### Installer

Transfère l'APK sur le téléphone et ouvre-le. Android demandera d'autoriser
l'installation depuis cette source ; c'est normal pour une application qui ne
vient pas du Play Store.

## Changer une adresse

Tout est dans `lib/config.dart` :

```dart
static const String jellyfinUrl  = 'https://jellyfin.fantesia.fr';
static const String jellyseerrUrl = 'https://seer.fantesia.fr';
static const String jfaGoUrl      = 'https://jfa.fantesia.fr';
```

Recompile après modification.

## Notes techniques

**Définition plutôt que débit.** Jellyfin choisit normalement la résolution de
sortie à partir du débit demandé, ce qui donne des résultats imprévisibles.
L'application envoie donc `maxHeight` **et** un débit cohérent avec cette
hauteur (`lib/api/models.dart`, classe `Quality`). Les paliers supérieurs à la
définition du fichier sont masqués : proposer du 4K sur un fichier 1080p ne
ferait que déclencher un réencodage inutile.

**Mode Automatique.** Il demande le fichier tel quel (`static=true`), sans
transcodage. C'est le mode à privilégier quand le serveur est chargé : aucune
charge CPU côté serveur. Les autres paliers passent par HLS et déclenchent un
transcodage.

**Lecteur.** `media_kit` (libmpv) plutôt que `video_player`, parce qu'il lit
en direct les MKV, le HEVC et les pistes audio DTS ou TrueHD qu'ExoPlayer
refuse. Un fichier refusé par le lecteur forcerait un transcodage serveur, ce
qu'on cherche justement à éviter.

**Authentification.** L'en-tête `Authorization: MediaBrowser ...` est utilisé,
pas l'ancien `X-Emby-Authorization` : ce dernier est abandonné et casse la
connexion sur Jellyfin 10.11 et suivants.

**Jellyseerr.** Intégré en vue web. Jellyseerr accepte la connexion avec le
compte Jellyfin, donc les mêmes identifiants fonctionnent.

## Limites connues

- Pas de téléchargement hors ligne
- Pas de Chromecast
- Musique et livres non pris en charge (l'application vise la vidéo)
- Icône d'application par défaut ; pour la remplacer, ajoute le paquet
  `flutter_launcher_icons` et une image de 1024×1024
