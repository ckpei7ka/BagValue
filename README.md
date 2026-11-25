# BagValue

A standalone, movable window with three numbers:

1. **Carried money** — the copper on the character right now.
2. **Vendor value** — what a vendor pays for every item in every bag (backpack, bag slots, reagent bag), stacks multiplied by their count.
3. **Auction value** — what the auctionable items in those bags are worth according to a **configurable price source**: TSM, Auctionator, Auctinator, Auctioneer, AHDB, Wowecon, the generic `GetAuctionBuyout` API, or your own Lua function.

Auction value only counts items the auction house would accept: soulbound items are skipped, and stacks count for their full quantity.

Built for **World of Warcraft: Forever** — client `1.60.1`, TOC `## Interface: 16001`, game type `camelot`, project ID `18`.

## Install

1. Close the game.
2. Copy the `BagValue` folder into:

   ```
   World of Warcraft\_forever_\Interface\AddOns\BagValue
   ```

3. Start the game and enable the addon in the AddOns list.

The CurseForge/App installer places it in the same `_forever_` folder. Do not install the Retail build into `_retail_`.

## Use

- The window is a standalone frame: it shows up at login, stays open while you play, and is **not** tied to the AddOns options panel — closing the game options does not close BagValue.
- `/bagvalue` toggles the window. Drag the frame by its body to move it; the position is saved.
- Drag any of the **four corners** to resize it diagonally. The size is saved, and the rows and labels re-flow with the frame.
- The **collapse button** (top right, left of the close button) rolls the window up to a title bar and back. A collapsed window remembers its expanded size.
- The **close button** hides the window; it comes back with `/bagvalue` or at the next login. "Keep the window open (show it at login)" in the settings controls the login behaviour.
- **Source** button (bottom right of the window) or `/bagvalue source <id>` picks the price source.
- **Refresh** re-reads the bags. The window also refreshes itself on bag changes, money changes and at the merchant.
- Settings open from the game's AddOns options (`/bagvalue options`); "Reset window size and position" restores the default layout.

### Price sources

| Source | Notes |
| --- | --- |
| `auto` | First detected source that has a price for the item: TSM → Auctionator → Auctinator → Auctioneer → AHDB → Wowecon → `GetAuctionBuyout` → custom function. |
| `tsm` | TradeSkillMaster `TSM_API`. Uses the cheaper of `DBMinBuyout` and `DBMarket`. Requires a TSM auction scan for your realm. |
| `auctionator` | `Auctionator.API.v1`, by item link then item ID. Requires an Auctionator scan. |
| `auctinator` | Best effort. Auctinator has no public API; BagValue probes its table/API and its saved price table. Prefer a custom function if you know the exact function. |
| `auctioneer` | `AucAdvanced.API` market-value calls. |
| `ahdb` | The `AuctionDB` (AHDB) saved price history. Experimental — use only if you rely on AHDB. |
| `wowecon` | `Wowecon.API.GetAuctionPrice_ByLink`. |
| `generic` | The global `GetAuctionBuyout(link)` API shipped by Tekkub-style price libraries. |
| `custom` | Your own global Lua function, set in settings: `fn(itemLink, itemID)` must return copper. |
| `vendor` | No auction price at all; the third number shows `—`. |

Every source is feature-detected and called through `pcall`, so a missing or changed addon can never break the window.

### Custom price function

If your auction scanner has no public API, put the name of a global function in the settings. BagValue calls:

```lua
MyScanner_GetPrice(itemLink, itemID) -- must return copper, or nil
```

No `loadstring` is used; only an already-defined global function can be called.

## Commands

| Command | What it does |
| --- | --- |
| `/bagvalue` | Show or hide the window |
| `/bagvalue collapse` | Collapse or expand the window |
| `/bagvalue reset-window` | Reset the window size, position and collapsed state |
| `/bagvalue refresh` | Rescan the bags now |
| `/bagvalue source` | List sources, `*` marks the active one |
| `/bagvalue source tsm` | Switch the price source |
| `/bagvalue options` | Open the settings panel |
| `/bagvalue debug` | Toggle debug output |
| `/bagvalue reset` | Reset saved settings |
| `/bagvalue help` | Print the command list |

## Forever-specific notes

- Lua is **5.1** — no `goto`, no `//`, no bitwise operators.
- Combat values can be **secret**: all arithmetic is gated behind `issecretvalue()`; missing numbers render as `—`.
- Item data is not always loaded right after login: BagValue asks the client to load it and retries the scan a few times.
- Realm functions can return an empty string on Forever; saved data uses a fallback key.
- The addon targets the Mainline API family (`C_Container`, `C_Item`), with legacy fallbacks.

See [`docs/FOREVER.md`](docs/FOREVER.md) for the platform checklist.

## Development

Requirements: Lua 5.1, Python 3.11+ (validation only), Git.

```bash
python tools/validate.py     # TOC + file + Lua 5.1 sanity checks
python tools/package.py      # build dist/BagValue-<version>.zip
```

The pipeline that generated this repository lives in `wow-addon-factory`; it also runs an independent audit (`addon-auditor`, profile `forever`) before release.

## Release

Every release is a Git tag pushed to `main`:

```bash
git tag 1.2.0
git push origin 1.2.0
```

`.github/workflows/release.yml` runs `BigWigsMods/packager@v2.7.0` with `-g 1.60.1`, which:

- builds the zip from the tag,
- creates the GitHub release,
- uploads to CurseForge (requires `CF_API_TOKEN` secret and `## X-Curse-Project-ID` in the TOC),
- uploads to Wago (optional, `WAGO_API_TOKEN` + `## X-Wago-ID`).

**The first CurseForge upload must be done manually** in the CurseForge dashboard: a project only becomes visible after its first file is uploaded and reviewed. After that, tags deploy automatically.

## License

MIT — see [LICENSE](LICENSE).
