# Compiler Maintelio Tycoon (Android et iOS)

La compilation se fait sur GitHub : aucune installation n'est nécessaire sur votre poste.

## 1. Mettre le projet sur GitHub

1. Créez un dépôt **privé** sur GitHub (par exemple `maintelio-tycoon`).
2. Envoyez-y tout le contenu de ce dossier sur la branche `main`.
3. Ouvrez l'onglet **Actions** du dépôt : le workflow **Build mobile** démarre à chaque envoi sur `main`. Vous pouvez aussi le lancer à la main avec **Run workflow**.

Les dossiers natifs `android/` et `ios/` sont générés et configurés automatiquement à chaque compilation (`tool/patch_platforms.py`).

## 2. Android

À la fin du workflow, téléchargez l'artefact **maintelio-tycoon-android** :

- `maintelio_tycoon.apk` : à installer directement sur un téléphone Android (autorisez l'installation depuis une source inconnue).
- `maintelio_tycoon.aab` : pour le Google Play Store, produit seulement si une clé de signature est configurée.

**Publication sur le Play Store** (optionnel) : créez une clé d'envoi, puis ajoutez ces secrets au dépôt (*Settings → Secrets and variables → Actions*) :

| Secret | Contenu |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | le fichier `.jks` encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | alias de la clé |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Créer la clé : `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
Encoder la clé : `base64 -i upload-keystore.jks | pbcopy` (Mac) ou `base64 -w0 upload-keystore.jks` (Linux).

## 3. iOS

L'artefact **maintelio-tycoon-ios** contient :

- `maintelio_tycoon_simulateur.zip` : application pour le simulateur iPhone d'un Mac (glisser `Runner.app` sur le simulateur).
- `maintelio_tycoon_non_signe.ipa` : version non signée. Apple impose une signature pour l'installer sur un iPhone.

**Installer sur iPhone via TestFlight** (nécessite un compte Apple Developer, 99 $/an) :

1. Dans *Certificates, Identifiers & Profiles* (developer.apple.com) :
   - enregistrez l'identifiant d'application **`com.ghyksos.maintelioTycoon`** ;
   - enregistrez au moins un iPhone dans *Devices* (exigé par la signature automatique).
2. Dans App Store Connect, créez l'application avec cet identifiant.
3. Dans *Utilisateurs et accès → Intégrations*, créez une clé API avec le rôle **Admin** et téléchargez le fichier `.p8`.
4. Ajoutez ces secrets au dépôt :

| Secret | Contenu |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_BASE64` | le fichier `.p8` encodé en base64 |
| `APP_STORE_CONNECT_KEY_ID` | identifiant de la clé |
| `APP_STORE_CONNECT_ISSUER_ID` | identifiant de l'émetteur (Issuer ID) |
| `APPLE_TEAM_ID` | identifiant d'équipe Apple (10 caractères) |

Le workflow signe alors l'application et l'envoie sur TestFlight ; elle apparaît dans l'app TestFlight de vos iPhone après le traitement d'Apple.

## 4. Classement en ligne (optionnel)

Installez l'API du dossier `backend_laravel/` sur votre serveur Laravel, puis ajoutez la **variable** de dépôt `LEADERBOARD_URL` (par exemple `https://app.exemple.fr`).

## 5. Compiler sur votre poste (optionnel)

Avec Flutter 3.47 ou plus récent (Mac + Xcode obligatoires pour iOS) :

```
flutter create . --platforms=android,ios --org com.ghyksos --project-name maintelio_tycoon
python3 tool/patch_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run
```
