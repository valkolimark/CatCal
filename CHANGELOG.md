# Changelog

All notable changes to CatCal are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Project bootstrap via XcodeGen: SwiftUI iOS app target `CatCal` (bundle id `com.valkolimark.catcal`, iOS 26.0, Swift 6), `CatCalTests` unit test target, and source layout under `Sources/{App,Models,Services,Views,Resources}`.
- Design system foundation (`Theme.swift`): brand color palette with light/dark variants, calendar source tags (Google/Outlook/iCloud), rounded type scale, spacing and radius tokens.
- App icon and color asset catalog.
- SwiftData models: `AppTask`, `UserProgress`, `Achievement`, `Cosmetic`, each with an `ownerID`.
- `AuthServiceProtocol` + `CurrentUser` mock identity helper, so real auth can drop in later without touching models.
- `ProgressEngine`: flat 150 XP/level curve and a level → cat growth stage lookup (Newborn/Kitten/Teen cat/Adult/Majestic), with unit tests.

### Changed

### Fixed
