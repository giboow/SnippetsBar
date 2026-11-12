# SnippetsBar

macOS menu bar app (Swift, SwiftUI + AppKit) that manages the built-in macOS Text
Replacements by reading and writing `~/Library/KeyboardServices/TextReplacements.db`.

## Language

**Everything in this repository is in English**: code identifiers, comments, commit
messages, branch names, pull request titles and descriptions, release notes, issues,
README and other docs. Conversation with the maintainer may happen in another language;
what lands in the repo does not.

## Scope

Keep the app simple: it is a front end for macOS Text Replacements, nothing more.
Features that go beyond managing text replacements (scripts, variables, expansion
engine…) are out of scope.

## Layout

- `Sources/SnippetsBarCore/` — library, no UI: `Domain/` (Snippet, SnippetDraft,
  ImportPlan, SnippetRepository) and `Infrastructure/` (SQLite access, Core Data
  schema mapping, .plist import/export).
- `Sources/SnippetsBar/` — the app: AppKit entry point, `StatusBarController`
  (menu bar icon, popover, right-click menu), SwiftUI views and `SnippetStore`.
- `Tests/SnippetsBarCoreTests/` — XCTest suite, including a test database that mimics
  the macOS Core Data schema.
- `Localization/<lang>.lproj/Localizable.strings` — translations.

## Commands

- Build: `swift build`
- Test: `swift test`
- App bundle: `./build-app.sh [version]` (universal binary, ad hoc signature)

## Localization

- UI strings in the code are the English text, used as localization keys. SwiftUI
  literals are localized automatically; any other user-facing string goes through
  `String(localized:)`.
- Every new or changed string must be added to **all** `Localizable.strings` files
  (en, fr, es, it, de, pt-BR, ja, zh-Hans). `LocalizationTests` fails if keys or
  placeholders (`%@`, `%lld`) differ between languages.
- Avoid hand-rolled plurals; prefer language-neutral wording such as `Snippets: %lld`.

## Git workflow

- Branch from `develop` (`feat/…`, `fix/…`, `docs/…`) and open pull requests against
  `develop`.
- Releases: pull request `develop` → `main`, then tag `vX.Y.Z` on `main`; the Release
  workflow builds and publishes the zip.
- Do not rewrite published history (`main`, `develop`, tags).

## Safety

Never write to the real `TextReplacements.db` during development or tests: use a copy
or the test fixture. The repository makes an automatic backup before the first write of
each session.
