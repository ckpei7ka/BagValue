-- luacheck configuration for a World of Warcraft addon (Forever 1.60.1, Lua 5.1).
--
-- The game client injects the WoW API into the global environment; luacheck's
-- "lua51" standard knows none of it. Every client or third-party global the
-- addon touches must be listed here, otherwise luacheck reports it as an
-- undefined variable. `read_globals` are owned by the client (read-only for
-- the addon); `globals` are assigned by the addon itself (slash commands).
-- Add new client API to `read_globals` when the addon starts using it.

std = "lua51"
max_line_length = 160

read_globals = {
    -- WoW client API used by this addon.
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GetRealmName",
    "UnitName",
    "Settings",
    "SettingsPanel",
    "date",
    "Enum",
    "NUM_BAG_SLOTS",
    "GetMoney",
    "C_Container",
    "C_CurrencyInfo",
    "C_Item",
    "C_Timer",
    "GetContainerItemInfo",
    "GetContainerNumSlots",
    "GetItemInfo",
    "GetItemInfoInstant",
    "strtrim",
    "wipe",
    "issecretvalue",

    -- Optional auction-price addons. They are probed at runtime and are never
    -- hard dependencies, but the names are still globals.
    "TSM_API",
    "Auctionator",
    "AuctionDB",
    "AucAdvanced",
    "Wowecon",
    "GetAuctionBuyout",
    "Auctinator",
    "Auctinator_GetPrice",
    "AuctinatorDB",
}

-- Assigned by the addon, read by the client when it registers slash commands.
globals = {
    "SlashCmdList",
    "SLASH_BAGVALUE1",
}

unused_args = false
