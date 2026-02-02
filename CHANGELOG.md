# Changelog

All notable changes to Trackmania Announcer will be documented in this file.

## [2.0.0] - 2026-02-02

### Added
- **Medal Sounds** - Announces when you earn a medal (Bronze, Silver, Gold, Author)
- **Custom Sounds Support** - Load your own .wav files from PluginStorage
- **Custom Sounds Guide** - Dedicated settings tab with folder structure examples
- **Reload Button** - Reload custom sounds without restarting the plugin
- **Auto-reload** - Samples automatically reload when toggling custom sounds
- **Checkpoint Intervals** - Sounds play at random intervals instead of every checkpoint
- **Always Play Option** - Setting to play sounds on every checkpoint
- **PB Ghost Detection** - Improved detection of personal best ghosts across languages

### Changed
- Renamed plugin from "Trackmania Turbo Announcer" to "Trackmania Announcer"
- Refactored constants to SCREAMING_SNAKE_CASE
- Improved volume calculation with proper master volume priority
- Medal sounds only play when actually earning a medal (not on every finish)
- Simplified checkpoint interval logic

### Fixed
- Crash detection not working between runs (LocalNativePlayer reference issue)
- Custom sounds path doubling (IO::IndexFolder returns full paths)
- Master volume setting being disregarded
- Trailing whitespace cleanup

## [1.0.3] - Previous Release

### Features
- Crash sounds on speed loss
- Checkpoint sounds with PB comparison
- Lap sounds with final lap announcements
- Volume controls and in-game volume scaling
- Debug mode for troubleshooting
