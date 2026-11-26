# Changelog

## [0.3.0] - 2026-11-26

### Added

- Five window styles — Classic, Minimal, Compact, Parchment and Arcane — picked in the settings, not on the window. Each style has its own background, border, fonts and value colours.
- Window opacity slider (20–100%) in the settings; the choice is saved per account.
- `/bagvalue style <name>` and `/bagvalue opacity <percent>` to change both without opening the settings.

### Changed

- Row captions are short now ("Money", "Vendor", "Auction") with a coin icon in front, so the values have room even at the minimum window size.
- The last scan time moved from the footer into the header and reads "Last price update: HH:MM:SS"; it stays visible when the window is collapsed.
- The footer counters are shorter ("2 items · 4 stacks · 2 priced"), and the full breakdown is available on hover.
- The "Source: ..." button is gone from the window; the source picker lives only in the settings.
- Row layout is recomputed from the frame height, which fixes the overlapping footer text at small sizes. The default size is now 320x194 and the minimum 300x180.

## [0.2.0] - 2026-11-25

### Fixed

- The window no longer closes together with the game options panel. It was registered in `UISpecialFrames`, so the client's `CloseSpecialWindows()` hid it when the options or the game menu closed. The registration is gone; the window is a plain HUD frame and is only shown or hidden by the addon.

### Added

- The window now opens at login by default and stays open while you play (setting "Keep the window open"). Existing installs are migrated once to saved data version 2.
- Diagonal resizing from any of the four corners, with a minimum size; the size is saved together with the position.
- Collapse/expand button in the top right: rolls the window up to a title bar and restores the expanded size.
- "Reset window size and position" button in the settings, plus `/bagvalue reset-window` and `/bagvalue collapse`.

### Changed

- Smaller default size (292x176 instead of 340x226); rows, labels and buttons re-flow when the window is resized.

## [0.1.1] - 2026-11-25

- Fixed the Auto price source: it returned no prices because the auto lookup was treated as a named adapter.
- Fixed the Settings panel not being built when the login event reaches only the addon's own frame.
- Offline harness now covers all three totals, source switching and the no-data path.

## [0.1.0] - unreleased

### Added

- Initial release for World of Warcraft: Forever (Interface 16001).
- Standalone movable window with three totals: carried money, vendor value of every bag item, auction value of the auctionable items.
- Full bag scan: backpack, bag slots and reagent bag, stacks multiplied by quantity, soulbound items excluded from the auction total.
- Pluggable auction price sources: TSM, Auctionator, Auctinator (best effort), Auctioneer, AHDB, Wowecon, `GetAuctionBuyout`, a user-provided global function, and vendor-only.
- Auto source that picks the first detected source with data for the item.
- Settings panel with source selection, custom function name, enable toggle and show-at-login.
- Throttled refresh on bag, money and merchant events; item data loading retries.
- Forever-safe helpers: secret-value guards, coin formatting, missing-API fallbacks.

All notable changes to BagValue are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/) and [Semantic Versioning](https://semver.org/).
