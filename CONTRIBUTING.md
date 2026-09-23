# Contributing to Stash

Thank you for looking. Bug reports and ideas are welcome as [issues](https://github.com/KiraMurano/stash/issues).

## Before a larger change, open an issue

A small fix — a typo, a crash, a wrong string — can go straight to a pull request. Anything bigger, such as a new feature, a new platform or a change to how the journal behaves, should start as an issue. Say what you want to change and why, and we can agree on it before you spend an evening on the code. A pull request that arrives without that conversation may be declined, however well it is made.

## What Stash supports

- **macOS 13 and newer**, on Apple silicon and Intel. Stash only supports what its maintainers can run and check, so older systems are out of scope. A fork for them is welcome, and the README can link to it.
- **Swift 6**, in the Swift 6 language mode, built with the current Xcode.

## Building and testing

```bash
swift build
swift test
Scripts/build_app.sh
```

The last command puts the app in `.build/Stash.app`. Signing, versioning and the release flow are described in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Pull requests

- One change per pull request.
- `swift test` passes.
- Match the code around you: its naming, its comments, and its habit of explaining why rather than what.
- In the description, say what you checked and what you could not check. It speeds up the review more than anything else.
