# Pokédex

A Pokédex for iOS built with SwiftUI and Swift 6 on top of [PokéAPI](https://pokeapi.co).

## Requirements

- Xcode 16 or later
- iOS 17.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Getting started

```bash
brew install xcodegen
git clone https://github.com/salvattore315/iOS-Pokedex.git
cd iOS-Pokedex
xcodegen generate
open Pokedex.xcodeproj
```

The Xcode project is not committed. It is generated from `project.yml`, so run `xcodegen generate` again after changing targets or settings.

## Architecture

The app uses SwiftUI views, `@Observable` view models, a service protocol and two local Swift Packages: `Networking` and `DesignSystem`. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Tests

Run the tests in Xcode with ⌘U. They use Swift Testing, plus one XCUITest flow.
