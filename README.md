# SnippetsBar

Gérez les **Remplacements de texte de macOS** depuis la barre des menus.

- Liste et recherche instantanée de tous vos snippets
- Clic = copie le texte, double-clic = modifier
- Ajout (⌘N), modification, suppression
- Détection des raccourcis en double
- Sauvegarde automatique de la base avant la première modification
- Export `.plist` (méthode officielle d'import dans Réglages Système)

Requiert macOS 13 (Ventura) ou plus récent.

## Installation

```bash
git clone … && cd SnippetsBar
./build-app.sh
mv SnippetsBar.app /Applications/
open /Applications/SnippetsBar.app
```

(Il faut Xcode ou au minimum les Command Line Tools : `xcode-select --install`.)
Pour développer : `open Package.swift` dans Xcode, ou `swift run`. Tests : `swift test`.

### Accès complet au disque

La base se trouve dans `~/Library/KeyboardServices/TextReplacements.db`.
Si l'app affiche une erreur d'ouverture, ajoutez SnippetsBar dans
**Réglages Système › Confidentialité et sécurité › Accès complet au disque**
(un bouton y mène directement), puis cliquez sur « Réessayer ».

Pour la lancer au démarrage : Réglages Système › Général › Ouverture.

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
