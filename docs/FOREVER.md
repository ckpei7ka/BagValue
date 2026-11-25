# Forever platform checklist

Verified for BagValue against the project's Forever notes (`core/forever.mjs`,
`docs/forever-platform.md`).

- [x] Client **1.60.1**, TOC `## Interface: 16001`.
- [x] Install path is `_forever_/Interface/AddOns/<Addon>`, not `_retail_` or `_classic_era_`.
- [x] Lua **5.1** only: no `goto`, no `//`, no bitwise operators, no `table.unpack`.
- [x] `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18) is the reliable Forever check; the addon never needs it at runtime.
- [x] Combat values may be **secret**: every number that reaches Lua goes through `ns.SafeNumber` / `issecretvalue` before arithmetic.
- [x] `GetRealmName()` / `GetRealmID()` can return blank; `ns.RealmKey()` falls back to `"Forever"`.
- [x] SavedVariables (`BAGVALUE_DB`) are declared in the TOC and initialised on `ADDON_LOADED`; only plain data is stored (settings, window position).
- [x] No `loadstring`, `RunScript`, `require`, `io`, `os.execute`; the custom price source only calls an already-defined global function.
- [x] No protected-frame changes in combat; the window is a plain movable frame.
- [x] The window is **not** listed in `UISpecialFrames`: the client calls `CloseSpecialWindows()` when the game menu or the options panel closes, which would hide it. It is shown/hidden only by the addon.
- [x] CurseForge file must be tagged **Forever 1.60.1**, not Retail.
- [x] Release tag matches the TOC `## Version` (currently `0.2.0`).

## Runtime notes

- Bag API: `C_Container.GetContainerNumSlots` / `C_Container.GetContainerItemInfo` with legacy `GetContainer*` fallbacks.
- Item API: `C_Item.GetItemInfo` / `C_Item.RequestLoadItemDataByID` with legacy `GetItemInfo` fallback.
- Coins are rendered with `C_CurrencyInfo.GetCoinTextureString`, with a plain-text fallback.
- Price adapters probe third-party globals (`TSM_API`, `Auctionator.API.v1`, `AuctAdvanced.API`,
  `AuctionDB`, `Wowecon.API`, `Auctinator`, `GetAuctionBuyout`) and wrap every call in `pcall`.
- A price source that reports no data renders the auction total as `—` instead of a misleading `0`.
- The window keeps its own layout state (`ns.db.window`, `ns.db.collapsed`): point, offsets, width, height and the expanded height. Resizing uses `SetResizeBounds` with a `SetMinResize`/`SetMaxResize` fallback, and every corner grip drives `StartSizing`.
