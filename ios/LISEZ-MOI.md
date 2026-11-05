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

Pour installer via TestFlight, il reste à ajouter une icône d’application, enregistrer l’identifiant iOS dans votre compte Apple Developer, puis configurer la signature et l’envoi vers App Store Connect. Le workflow de compilation de cette archive ne produit pas de fichier installable.
