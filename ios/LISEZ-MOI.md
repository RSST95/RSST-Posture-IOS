# RSST Posture pour iPhone

Première version pour iPhone sous iOS 17 ou ultérieur, en orientation portrait. Elle comprend la caméra arrière, l’import d’une photo, les vues Profil et Face / Dos, la correction des masques de visage, l’export JPG et un rapport PDF. Les photos sont traitées sur l’appareil. Après vérification de la capture, les exports s’enregistrent via le sélecteur de fichiers iOS.

Cette version utilise Apple Vision. Les formules et les seuils sont repris du code Swift existant et correspondent aux règles du projet Android, mais les points détectés et les angles peuvent différer de l’APK. L’interface et le rapport PDF sont propres à cette première version iOS.

## Ajouter les fichiers au dépôt GitHub

Placez les dossiers ios et .github de cette archive à la racine du dépôt, au même niveau que le fichier construire.sh. Si Windows propose de fusionner les dossiers .github, acceptez. Le nouveau workflow se trouve dans .github/workflows/ios.yml.

Avec GitHub Desktop sous Windows, ouvrez le dépôt privé dans GitHub Desktop, puis cliquez sur **Repository → Show in Explorer** pour trouver le dossier où extraire l’archive. Vérifiez les fichiers ajoutés dans **Changes**, validez-les avec **Commit to main** (le nom dépend de votre branche), puis cliquez sur **Push origin**.

## Lancer la compilation

Sur GitHub, ouvrez **Actions**, choisissez **Compiler RSST Posture pour iPhone**, puis cliquez sur **Run workflow**. Sélectionnez la branche qui contient les nouveaux fichiers. Un envoi de ces fichiers sur GitHub déclenche aussi la compilation.

Le workflow compile pour le simulateur et pour iPhone sans signature. Après cette vérification, testez le comportement sur un iPhone réel, notamment l’orientation de la caméra, la détection sur des captures de référence Android, la couverture des masques et les fichiers exportés.

## Installer sur un iPhone

Pour un essai depuis un Mac, ouvrez ios/RSSTPosture.xcodeproj dans Xcode, choisissez votre équipe dans **Signing & Capabilities** et lancez l’app sur l’iPhone connecté.

## Publier une bêta via TestFlight

1. Activez une adhésion à l’[Apple Developer Program](https://developer.apple.com/programs/enroll/). Dans le compte Apple Developer, enregistrez un identifiant d’app explicite pour fr.rsst.posture.ios. Créez ensuite la fiche **RSST Posture** pour iOS dans [App Store Connect](https://appstoreconnect.apple.com/), avec cet identifiant.
2. Préparez un certificat **Apple Distribution** exporté au format .p12 avec sa clé privée et un [profil de distribution App Store Connect](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/) pour le même certificat et identifiant. Créez une [clé d’équipe App Store Connect](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) avec le rôle Developer pour l’envoi du build.
3. Dans **Settings → Secrets and variables → Actions** du dépôt GitHub, ajoutez les éléments suivants.

| Emplacement | Nom | Valeur |
| --- | --- | --- |
| Variables | APPLE_TEAM_ID | Identifiant de l’équipe Apple Developer |
| Secrets | APPLE_CERTIFICATE_BASE64 | Fichier .p12 encodé en Base64 |
| Secrets | APPLE_CERTIFICATE_PASSWORD | Mot de passe du .p12 |
| Secrets | APPLE_PROFILE_BASE64 | Fichier .mobileprovision encodé en Base64 |
| Secrets | ASC_KEY_ID | Identifiant de la clé App Store Connect |
| Secrets | ASC_ISSUER_ID | Identifiant de l’émetteur App Store Connect |
| Secrets | ASC_PRIVATE_KEY | Contenu intégral du fichier .p8 |

4. Dans **Actions → Envoyer RSST Posture à TestFlight**, lancez le workflow avec **Run workflow** sur la branche principale. Il signe le build et l’envoie à App Store Connect.
5. Une fois le traitement terminé, ouvrez **TestFlight** dans la fiche de l’app, créez un groupe de test interne et ajoutez-y le build et les testeurs autorisés. L’installation se fait ensuite dans l’app TestFlight sur l’iPhone.

Saisissez les valeurs de signature uniquement dans **Secrets** sur GitHub. La compilation ordinaire reste disponible sans compte Apple et produit un build sans signature.
