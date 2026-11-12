# SnippetsBar

Gérez les **Remplacements de texte de macOS** depuis la barre des menus.

- Liste et recherche instantanée de tous vos snippets
- Clic = copie le texte, double-clic = modifier
- Ajout (⌘N), modification, suppression
- Détection des raccourcis en double
- Sauvegarde automatique de la base avant la première modification
- Export et import `.plist` (même format que Réglages Système) : à l'import, les doublons
  exacts sont ignorés et une seule question est posée pour les raccourcis existants avec un
  autre texte (remplacer ou conserver)
- Ouverture au démarrage (menu **⋯ › Ouvrir au démarrage**)
- Clic droit sur l'icône de la barre des menus : réglages (exporter, importer, ouvrir au démarrage, quitter)

Requiert macOS 13 (Ventura) ou plus récent.

## Installation

### Depuis les Releases

1. Téléchargez `SnippetsBar-vX.Y.Z.zip` depuis la page
   [Releases](https://github.com/giboow/SnippetsBar/releases), décompressez-le et
   placez `SnippetsBar.app` dans `/Applications`.
2. L'app n'est pas signée par un développeur Apple identifié : au premier lancement,
   macOS refuse de l'ouvrir. Allez dans **Réglages Système › Confidentialité et sécurité**,
   puis cliquez sur **Ouvrir quand même** en bas de la page.
   Ou, dans le Terminal :
   ```bash
   xattr -d com.apple.quarantine /Applications/SnippetsBar.app
   ```

### Depuis les sources

```bash
git clone https://github.com/giboow/SnippetsBar.git && cd SnippetsBar
./build-app.sh
mv SnippetsBar.app /Applications/
open /Applications/SnippetsBar.app
```

(Il faut Xcode ou au minimum les Command Line Tools : `xcode-select --install`.)
Une app compilée sur votre Mac n'est pas mise en quarantaine : pas d'étape Gatekeeper.

Pour développer : `open Package.swift` dans Xcode, ou `swift run`. Tests : `swift test`.

### Publier une version

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Le workflow GitHub Actions lance les tests, compile l'app (Apple Silicon + Intel)
et publie le `.zip` dans une release.

### Accès complet au disque

La base se trouve dans `~/Library/KeyboardServices/TextReplacements.db`.
Si l'app affiche une erreur d'ouverture, ajoutez SnippetsBar dans
**Réglages Système › Confidentialité et sécurité › Accès complet au disque**
(un bouton y mène directement), puis cliquez sur « Réessayer ».

**Après une mise à jour**, macOS considère la nouvelle version comme une autre app
(signature ad hoc) : retirez SnippetsBar de la liste avec le bouton « – », puis
ajoutez-le de nouveau.

Pour la lancer au démarrage : menu **⋯ › Ouvrir au démarrage**. L'app apparaît alors dans
Réglages Système › Général › Ouverture, où vous pouvez aussi la désactiver.

## Comment ça marche

Apple ne fournit pas d'API publique pour les remplacements de texte. SnippetsBar
lit et écrit directement la base SQLite (Core Data) utilisée par macOS :

- **Ajout / modification** : l'entrée est marquée `ZNEEDSSAVETOCLOUD = 1`
  pour que la synchro iCloud la pousse vers vos autres appareils.
- **Suppression** : suppression « douce » (`ZWASDELETED = 1`), comme le fait macOS,
  pour que la suppression se propage aussi.
- **Avant la première écriture** de chaque session, une copie de la base est faite dans
  `~/Library/Application Support/SnippetsBar/Backups/`.

⚠️ Comme il s'agit d'un format interne non documenté :

- les changements s'appliquent généralement tout de suite, mais certaines apps
  ou les Réglages peuvent ne les voir qu'après un redémarrage de session ;
- une future version de macOS peut changer le format. En cas de souci, restaurez une
  sauvegarde, ou utilisez **⋯ › Exporter en .plist** et glissez le fichier dans
  Réglages Système › Clavier › Remplacements de texte (méthode 100 % officielle).

## Licence

Copyright © 2026 Philippe Gibert

SnippetsBar est un logiciel libre distribué sous licence
[GNU GPL v3](LICENSE) : vous pouvez le redistribuer et le modifier selon les
termes de cette licence. Il est fourni sans aucune garantie.
