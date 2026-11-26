-- The standalone window: three totals, a header line with the last price
-- update, a refresh button and four corner grips for diagonal resizing.
--
-- The look is chosen from the settings panel (five styles plus an opacity
-- slider); the window itself carries no settings controls, so it stays a clean
-- HUD frame. The window is a plain frame on UIParent and is deliberately NOT
-- registered in UISpecialFrames: the client hides all special frames when the
-- game menu is opened (which is what closing the options frame does), and that
-- is why the window used to disappear together with the settings panel.
-- Position, size and the collapsed state are saved.

local _, ns = ...

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 320, 194
local MIN_WIDTH, MIN_HEIGHT = 300, 180
local COLLAPSED_HEIGHT = 42
local GRIP_SIZE = 16
local DEFAULT_OPACITY = 0.94
local MIN_OPACITY, MAX_OPACITY = 0.2, 1.0
local TIME_PREFIX = "Last price update: "
local ICON_SIZE = 14

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

-- Short row captions: the full wording ("carried money", "vendor value",
-- "auction value") does not fit the default width, so each row gets a short
-- word plus a coin icon. WoW fonts have no colour emoji, so icons and words are
-- the only readable option here.
local ROWS = {
    { key = "money", label = "Money", icon = "Interface\\MoneyFrame\\UI-GoldIcon" },
    { key = "vendor", label = "Vendor", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { key = "auction", label = "Auction", icon = "Interface\\Icons\\INV_Misc_Coin_05" },
}

-- Five window styles. A style only changes colours, fonts, border and row
-- spacing; the layout code below keeps the same anchors, so every style works
-- at every allowed size.
local SKINS = {
    {
        id = "classic",
        label = "Classic",
        backdrop = {
            bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 16,
            edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bgColor = { 0.05, 0.05, 0.08 },
        borderColor = { 0.62, 0.52, 0.20 },
        titleColor = { 1.00, 0.82, 0.00 },
        timeColor = { 0.58, 0.58, 0.60 },
        labelColor = { 1.00, 0.96, 0.88 },
        statusColor = { 0.95, 0.75, 0.35 },
        countsColor = { 0.52, 0.52, 0.55 },
        valueColors = { { 1.00, 0.85, 0.25 }, { 0.55, 0.85, 0.55 }, { 0.45, 0.70, 1.00 } },
        titleFont = "GameFontNormal",
        labelFont = "GameFontNormal",
        valueFont = "GameFontHighlight",
        smallFont = "GameFontDisableSmall",
        rowsTop = 46,
        rowHeight = 22,
        padding = 14,
    },
    {
        id = "minimal",
        label = "Minimal",
        backdrop = {
            bgFile = TOOLTIP_BG, edgeFile = WHITE8, tile = true, tileSize = 8,
            edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
        },
        bgColor = { 0.02, 0.02, 0.03 },
        borderColor = { 0.42, 0.42, 0.48 },
        titleColor = { 0.92, 0.92, 0.92 },
        timeColor = { 0.55, 0.55, 0.58 },
        labelColor = { 0.85, 0.85, 0.85 },
        statusColor = { 0.95, 0.80, 0.45 },
        countsColor = { 0.48, 0.48, 0.50 },
        valueColors = { { 0.95, 0.90, 0.70 }, { 0.65, 0.85, 0.65 }, { 0.60, 0.78, 0.95 } },
        titleFont = "GameFontNormal",
        labelFont = "GameFontNormalSmall",
        valueFont = "GameFontHighlight",
        smallFont = "GameFontDisableSmall",
        rowsTop = 44,
        rowHeight = 21,
        padding = 12,
    },
    {
        id = "compact",
        label = "Compact",
        backdrop = {
            bgFile = TOOLTIP_BG, tile = true, tileSize = 8,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        bgColor = { 0.03, 0.03, 0.035 },
        borderColor = { 0, 0, 0 },
        titleColor = { 1.00, 0.82, 0.00 },
        timeColor = { 0.50, 0.50, 0.52 },
        labelColor = { 0.90, 0.90, 0.88 },
        statusColor = { 0.95, 0.75, 0.35 },
        countsColor = { 0.45, 0.45, 0.48 },
        valueColors = { { 1.00, 0.85, 0.30 }, { 0.60, 0.85, 0.60 }, { 0.55, 0.75, 1.00 } },
        titleFont = "GameFontNormalSmall",
        labelFont = "GameFontNormalSmall",
        valueFont = "GameFontHighlightSmall",
        smallFont = "GameFontDisableSmall",
        rowsTop = 40,
        rowHeight = 18,
        padding = 10,
    },
    {
        id = "parchment",
        label = "Parchment",
        backdrop = {
            bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 16,
            edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bgColor = { 0.86, 0.80, 0.64 },
        borderColor = { 0.44, 0.32, 0.14 },
        titleColor = { 0.36, 0.22, 0.02 },
        timeColor = { 0.42, 0.34, 0.20 },
        labelColor = { 0.26, 0.18, 0.08 },
        statusColor = { 0.55, 0.22, 0.05 },
        countsColor = { 0.38, 0.30, 0.20 },
        valueColors = { { 0.45, 0.30, 0.00 }, { 0.10, 0.38, 0.12 }, { 0.10, 0.22, 0.52 } },
        titleFont = "GameFontNormal",
        labelFont = "GameFontNormal",
        valueFont = "GameFontHighlight",
        smallFont = "GameFontDisableSmall",
        rowsTop = 46,
        rowHeight = 22,
        padding = 14,
    },
    {
        id = "arcane",
        label = "Arcane",
        backdrop = {
            bgFile = TOOLTIP_BG, edgeFile = WHITE8, tile = true, tileSize = 8,
            edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        bgColor = { 0.05, 0.03, 0.12 },
        borderColor = { 0.30, 0.85, 1.00 },
        titleColor = { 0.55, 0.95, 1.00 },
        timeColor = { 0.50, 0.62, 0.78 },
        labelColor = { 0.88, 0.88, 0.98 },
        statusColor = { 0.95, 0.70, 0.95 },
        countsColor = { 0.50, 0.55, 0.72 },
        valueColors = { { 1.00, 0.86, 0.35 }, { 0.45, 1.00, 0.75 }, { 1.00, 0.55, 0.95 } },
        titleFont = "GameFontNormal",
        labelFont = "GameFontNormal",
        valueFont = "GameFontHighlight",
        smallFont = "GameFontDisableSmall",
        rowsTop = 46,
        rowHeight = 22,
        padding = 14,
    },
}

ns.skinList = SKINS

local MENU_BACKDROP = {
    bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 16,
    edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function skinById(id)
    for index = 1, #SKINS do
        if SKINS[index].id == id then return SKINS[index] end
    end
    return SKINS[1]
end

function ns.GetSkin(id)
    return skinById(id)
end

local function currentSkin()
    return skinById(ns.db and ns.db.skin or SKINS[1].id)
end

local function safeOpacity(value)
    return clamp(ns.SafeNumber(value, DEFAULT_OPACITY), MIN_OPACITY, MAX_OPACITY)
end

function ns.GetOpacity()
    return safeOpacity(ns.db and ns.db.opacity)
end

local function fontObject(name)
    local object = _G[name]
    if type(object) == "table" then return object end
    if type(_G.GameFontNormal) == "table" then return _G.GameFontNormal end
    return nil
end

local function setTextColor(region, color)
    if region and color then
        region:SetTextColor(color[1], color[2], color[3])
    end
end

local function setFont(region, name)
    local object = fontObject(name)
    if region and object then region:SetFontObject(object) end
end

-- UIParent size decides the resize ceiling; it can still be 0 while the client
-- is loading, so every read falls back to a sane screen size.
local function uiSize(getter, fallback)
    if type(UIParent) == "table" and type(UIParent[getter]) == "function" then
        local ok, value = pcall(UIParent[getter], UIParent)
        if ok then
            local number = ns.SafeNumber(value, nil)
            if number and number > 100 then return number end
        end
    end
    return fallback
end

local function maxWidth()
    return math.max(MIN_WIDTH + 40, uiSize("GetWidth", 1600) - 60)
end

local function maxHeight()
    return math.max(MIN_HEIGHT + 40, uiSize("GetHeight", 1000) - 60)
end

local function thresholdSize()
    return math.max(MIN_WIDTH, math.min(maxWidth(), 1200)),
        math.max(MIN_HEIGHT, math.min(maxHeight(), 900))
end

local function applyBounds(frame)
    local maxW, maxH = thresholdSize()
    if type(frame.SetResizeBounds) == "function" then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxW, maxH)
        return
    end
    -- Older builds (and Forever's Lua surface) may only have the two separate
    -- setters; both are best effort.
    if type(frame.SetMinResize) == "function" then
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    if type(frame.SetMaxResize) == "function" then
        frame:SetMaxResize(maxW, maxH)
    end
end

-- Saved layout ---------------------------------------------------------------

local function saveLayout(frame)
    if not ns.db then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = ns.SafeNumber(x, 0),
        y = ns.SafeNumber(y, 0),
        width = ns.SafeNumber(frame:GetWidth(), DEFAULT_WIDTH),
        height = ns.SafeNumber(frame:GetHeight(), DEFAULT_HEIGHT),
        expandedHeight = ns.SafeNumber(frame.expandedHeight, DEFAULT_HEIGHT),
        collapsed = frame.collapsed and true or false,
    }
    ns.db.collapsed = frame.collapsed and true or false
end

-- Layout ---------------------------------------------------------------------
-- Everything below the header is re-anchored whenever the frame size or the
-- style changes, so the rows can never run into the title bar or the footer at
-- the minimum size.

local layoutFrame

layoutFrame = function(frame)
    if not frame or not frame.rows or frame.collapsed then return end
    local skin = currentSkin()
    local padding = skin.padding
    local width = ns.SafeNumber(frame:GetWidth(), DEFAULT_WIDTH)
    local height = ns.SafeNumber(frame:GetHeight(), DEFAULT_HEIGHT)

    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", padding, -10)
    frame.time:ClearAllPoints()
    frame.time:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    if frame.time.SetWidth then
        frame.time:SetWidth(math.max(80, width - 2 * padding - 52))
    end

    -- Header height comes from the style; the footer always reserves room for
    -- the refresh button and the counts line.
    local rowsTop = skin.rowsTop
    local footer = 64
    local available = height - rowsTop - footer
    if available < 54 then available = 54 end
    local step = math.floor(available / 3)
    if step > skin.rowHeight then step = skin.rowHeight end
    if step < 18 then step = 18 end

    for index = 1, #frame.rows do
        local row = frame.rows[index]
        local y = -(rowsTop + (index - 1) * step)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", padding, y)
        row.label:SetWidth(math.floor(width * 0.40))
        row.value:ClearAllPoints()
        row.value:SetPoint("TOPRIGHT", -padding, y + 1)
    end

    frame.counts:ClearAllPoints()
    frame.counts:SetPoint("BOTTOMLEFT", padding, 34)
    frame.counts:SetWidth(math.max(100, width - 2 * padding))
    frame.status:ClearAllPoints()
    frame.status:SetPoint("BOTTOMLEFT", padding, 48)
    frame.status:SetWidth(math.max(100, width - 2 * padding))
    frame.refresh:ClearAllPoints()
    frame.refresh:SetPoint("BOTTOMLEFT", padding, 8)
end

local function applySkin(frame)
    local skin = currentSkin()

    if type(frame.SetBackdrop) == "function" then
        local backdrop = {}
        for key, value in pairs(skin.backdrop) do
            if key ~= "insets" then backdrop[key] = value end
        end
        local insets = skin.backdrop.insets
        if insets then
            backdrop.insets = {
                left = insets.left, right = insets.right,
                top = insets.top, bottom = insets.bottom,
            }
        end
        frame:SetBackdrop(backdrop)
        local bg = skin.bgColor
        frame:SetBackdropColor(bg[1], bg[2], bg[3], safeOpacity(ns.db and ns.db.opacity))
        if backdrop.edgeFile then
            local border = skin.borderColor
            frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        end
    end

    if frame.title then
        setFont(frame.title, skin.titleFont)
        setTextColor(frame.title, skin.titleColor)
    end
    if frame.time then
        setFont(frame.time, skin.smallFont)
        setTextColor(frame.time, skin.timeColor)
    end
    if frame.status then
        setFont(frame.status, skin.smallFont)
        setTextColor(frame.status, skin.statusColor)
    end
    if frame.counts then
        setFont(frame.counts, skin.smallFont)
        setTextColor(frame.counts, skin.countsColor)
    end
    if frame.rows then
        for index = 1, #frame.rows do
            local row = frame.rows[index]
            setFont(row.label, skin.labelFont)
            setTextColor(row.label, skin.labelColor)
            setFont(row.value, skin.valueFont)
            setTextColor(row.value, skin.valueColors[index])
        end
    end
    layoutFrame(frame)
end

-- Collapse -------------------------------------------------------------------

local function setContentShown(frame, shown)
    local content = frame.content or {}
    for index = 1, #content do
        local region = content[index]
        if shown then region:Show() else region:Hide() end
    end
end

-- Collapsed keeps the title row, the timestamp of the last price update and the
-- two window buttons; the height is pinned to the header and the grips are
-- disabled so a drag cannot stretch the empty shell.
local function applyCollapsed(frame, collapsed, silent)
    collapsed = collapsed and true or false
    if frame.collapsed == collapsed then return end
    frame.collapsed = collapsed

    if collapsed then
        local height = ns.SafeNumber(frame:GetHeight(), DEFAULT_HEIGHT)
        if height > COLLAPSED_HEIGHT then frame.expandedHeight = height end
        setContentShown(frame, false)
        if frame.status then frame.status:Hide() end
        frame:SetResizable(false)
        frame:SetHeight(COLLAPSED_HEIGHT)
    else
        setContentShown(frame, true)
        frame:SetResizable(true)
        frame:SetHeight(clamp(ns.SafeNumber(frame.expandedHeight, DEFAULT_HEIGHT),
            MIN_HEIGHT, maxHeight()))
        if frame.update and frame.lastResult then
            frame.update(frame.lastResult)
        elseif frame.status then
            frame.status:Hide()
        end
    end

    if frame.collapseButton then
        frame.collapseButton:SetText(collapsed and "+" or "-")
    end
    if frame.grips then
        for index = 1, #frame.grips do
            local grip = frame.grips[index]
            if collapsed then grip:Disable() else grip:Enable() end
        end
    end
    if ns.db then ns.db.collapsed = collapsed end
    if not silent then saveLayout(frame) end
end

-- Source menu ----------------------------------------------------------------

local function closeSourceMenu()
    local menu, closer = ns.sourceMenu, ns.sourceCloser
    ns.sourceMenu, ns.sourceCloser = nil, nil
    if menu then menu:Hide() end
    if closer then closer:Hide() end
end

local function setMenuBackdrop(frame)
    if type(frame.SetBackdrop) ~= "function" then return end
    frame:SetBackdrop(MENU_BACKDROP)
    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
    end
    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(0.62, 0.52, 0.20, 1)
    end
end

local function openSourceMenu(anchor)
    closeSourceMenu()

    local menu = CreateFrame("Frame", "BagValueSourceMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    setMenuBackdrop(menu)

    local sources = ns.PriceSources or {}
    local rowHeight = 20
    local height = 34 + #sources * rowHeight + 8
    menu:SetSize(300, height)
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    menu:SetClampedToScreen(true)

    local title = menu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Price source")

    local current = ns.db and ns.db.priceSource or "auto"
    for index = 1, #sources do
        local source = sources[index]
        local button = CreateFrame("Button", nil, menu)
        button:SetPoint("TOPLEFT", 10, -(30 + (index - 1) * rowHeight))
        button:SetSize(280, rowHeight - 2)

        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 4, 0)
        label:SetJustifyH("LEFT")
        label:SetWidth(270)

        local text = source.label
        if source.id ~= "auto" and source.id ~= "vendor" and not ns.IsSourceAvailable(source.id) then
            text = text .. "  (not detected)"
        end
        if source.id == current then
            text = "> " .. text
            label:SetTextColor(1, 0.82, 0)
        end
        label:SetText(text)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")

        local sourceId = source.id
        button:SetScript("OnClick", function()
            closeSourceMenu()
            if ns.SetPriceSource then ns.SetPriceSource(sourceId) end
        end)
    end

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("FULLSCREEN")
    closer:SetScript("OnClick", closeSourceMenu)

    ns.sourceMenu, ns.sourceCloser = menu, closer
end

ns.OpenSourceMenu = openSourceMenu
ns.CloseSourceMenu = closeSourceMenu

-- Window ---------------------------------------------------------------------

local function addGrip(frame, corner)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint(corner, frame, corner, 0, 0)
    grip:SetFrameLevel(ns.SafeNumber(frame:GetFrameLevel(), 1) + 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    if type(grip.SetHighlightTexture) == "function" then
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function(self)
        if frame:IsResizable() then
            frame:StartSizing(corner)
            self:SetScript("OnUpdate", nil)
        end
    end)
    grip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        saveLayout(frame)
    end)
    grip.corner = corner
    return grip
end

local function countsText(result)
    local parts = {
        ("%d items"):format(result.itemSlots or 0),
        ("%d stacks"):format(result.stackCount or 0),
    }
    if (result.unpricedSlots or 0) > 0 then
        parts[#parts + 1] = ("%d no price"):format(result.unpricedSlots)
    elseif result.hasSource then
        parts[#parts + 1] = ("%d priced"):format(result.pricedSlots or 0)
    end
    if (result.boundSlots or 0) > 0 then
        parts[#parts + 1] = ("%d bound"):format(result.boundSlots)
    end
    return table.concat(parts, " · ")
end

local function countsDetail(result)
    local lines = {
        ("Items: %d in %d stacks"):format(result.itemSlots or 0, result.stackCount or 0),
        ("Auctionable with a price: %d"):format(result.pricedSlots or 0),
    }
    if (result.unpricedSlots or 0) > 0 then
        lines[#lines + 1] = ("No price yet: %d"):format(result.unpricedSlots)
    end
    if (result.boundSlots or 0) > 0 then
        lines[#lines + 1] = ("Soulbound (not auctionable): %d"):format(result.boundSlots)
    end
    if (result.pending or 0) > 0 then
        lines[#lines + 1] = ("Item data still loading: %d"):format(result.pending)
    end
    return table.concat(lines, "\n")
end

local function createWindow()
    local frame = CreateFrame("Frame", "BagValueFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    applyBounds(frame)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveLayout(self)
    end)
    frame:HookScript("OnHide", closeSourceMenu)
    frame:SetScript("OnSizeChanged", function(self)
        layoutFrame(self)
    end)

    local content = {}
    local grips = {}

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("BagValue")
    frame.title = title

    -- The timestamp moved out of the footer into the header: it stays visible
    -- when the window is collapsed and is short enough for one line.
    local time = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    time:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    time:SetJustifyH("LEFT")
    if type(time.SetWordWrap) == "function" then time:SetWordWrap(false) end
    time:SetText(TIME_PREFIX .. "—")
    frame.time = time

    -- Top-right buttons: close first, collapse to its left. Both stay visible
    -- while the window is collapsed, so the frame can be reopened.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ns.HideWindow() end)

    local collapse = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    collapse:SetSize(18, 18)
    collapse:SetPoint("TOPRIGHT", close, "TOPLEFT", 2, 1)
    collapse:SetText("-")
    collapse:SetScript("OnClick", function()
        applyCollapsed(frame, not frame.collapsed)
    end)
    collapse:SetScript("OnEnter", function(self)
        if type(GameTooltip) ~= "table" then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(frame.collapsed and "Expand" or "Collapse")
    end)
    collapse:SetScript("OnLeave", function()
        if type(GameTooltip) == "table" then GameTooltip:Hide() end
    end)
    frame.collapseButton = collapse

    local rows = {}
    for index = 1, #ROWS do
        local spec = ROWS[index]
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 14, -46 - (index - 1) * 22)
        label:SetText(("|T%s:%d:%d|t %s"):format(spec.icon, ICON_SIZE, ICON_SIZE, spec.label))
        content[#content + 1] = label

        local value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetPoint("TOPRIGHT", -14, -45 - (index - 1) * 22)
        value:SetJustifyH("RIGHT")
        if type(value.SetWordWrap) == "function" then value:SetWordWrap(false) end
        value:SetText("—")
        content[#content + 1] = value

        rows[index] = { label = label, value = value }
    end
    frame.rows = rows

    -- Warning line: only visible when the auction side cannot be computed.
    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 14, 48)
    status:SetJustifyH("LEFT")
    status:SetText("")
    status:Hide()

    local counts = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    counts:SetPoint("BOTTOMLEFT", 14, 34)
    counts:SetJustifyH("LEFT")
    counts:SetText("")
    content[#content + 1] = counts

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(84, 20)
    refresh:SetPoint("BOTTOMLEFT", 18, 8)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        if ns.RequestRefresh then ns.RequestRefresh(0, true) end
    end)
    content[#content + 1] = refresh

    -- The counts line is short enough for the default width; the tooltip holds
    -- the full breakdown, so nothing has to wrap into the rows above.
    counts:SetScript("OnEnter", function(self)
        if type(GameTooltip) ~= "table" or not frame.lastResult then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Bag scan")
        local lines = countsDetail(frame.lastResult)
        for line in lines:gmatch("[^\n]+") do
            GameTooltip:AddLine(line, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    counts:SetScript("OnLeave", function()
        if type(GameTooltip) == "table" then GameTooltip:Hide() end
    end)

    for _, corner in ipairs({ "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" }) do
        local grip = addGrip(frame, corner)
        grips[#grips + 1] = grip
        content[#content + 1] = grip
    end

    frame.content = content
    frame.grips = grips
    frame.collapsed = false
    frame.expandedHeight = DEFAULT_HEIGHT
    frame.counts = counts
    frame.status = status
    frame.refresh = refresh

    local function update(result)
        if not result then return end
        frame.lastResult = result

        local skin = currentSkin()
        rows[1].value:SetText(ns.MoneyString(result.money))
        rows[2].value:SetText(ns.MoneyString(result.vendor))
        local auctionColor = skin.valueColors[3]
        if result.auction ~= nil then
            rows[3].value:SetText(ns.MoneyString(result.auction))
            rows[3].value:SetTextColor(auctionColor[1], auctionColor[2], auctionColor[3])
        else
            rows[3].value:SetText("—")
            rows[3].value:SetTextColor(0.55, 0.55, 0.55)
        end

        frame.time:SetText(TIME_PREFIX .. (result.stamp or "—"))

        local warning
        if result.noPriceData then
            warning = "No auction prices — scan the AH first"
        elseif not result.hasSource then
            warning = "No auction source — vendor only"
        end
        if warning and not frame.collapsed then
            frame.status:SetText(warning)
            frame.status:Show()
        else
            frame.status:SetText("")
            frame.status:Hide()
        end

        frame.counts:SetText(countsText(result))
    end

    frame.update = update

    applySkin(frame)

    -- Restore the saved layout. The window is intentionally absent from
    -- UISpecialFrames, so nothing hides it when the options frame or the game
    -- menu closes.
    local saved = ns.db and ns.db.window
    if type(saved) == "table" then
        local width = clamp(ns.SafeNumber(saved.width, DEFAULT_WIDTH), MIN_WIDTH, maxWidth())
        local height = clamp(ns.SafeNumber(saved.height, DEFAULT_HEIGHT), MIN_HEIGHT, maxHeight())
        frame.expandedHeight = clamp(ns.SafeNumber(saved.expandedHeight, height), MIN_HEIGHT, maxHeight())
        frame:SetSize(width, height)
        if type(saved.point) == "string" then
            frame:ClearAllPoints()
            frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point,
                ns.SafeNumber(saved.x, 0), ns.SafeNumber(saved.y, 0))
        end
        if saved.collapsed then
            applyCollapsed(frame, true, true)
        end
    else
        frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    end

    return frame
end

function ns.EnsureWindow()
    if not ns.window then
        ns.window = createWindow()
    end
    return ns.window
end

function ns.UpdateWindow(result)
    if ns.window and ns.window.update then
        ns.window.update(result)
    end
end

-- Style / opacity -------------------------------------------------------------

function ns.SetSkin(id)
    local skin = skinById(id)
    if not ns.db then return false end
    ns.db.skin = skin.id
    if ns.window then
        applySkin(ns.window)
        if ns.window.lastResult then ns.window.update(ns.window.lastResult) end
    end
    if ns.onSkinChanged then ns.onSkinChanged(skin.id) end
    return true
end

function ns.SetOpacity(value)
    local opacity = safeOpacity(value)
    if ns.db then ns.db.opacity = opacity end
    if ns.window and type(ns.window.SetBackdropColor) == "function" then
        local bg = currentSkin().bgColor
        ns.window:SetBackdropColor(bg[1], bg[2], bg[3], opacity)
    end
    if ns.onOpacityChanged then ns.onOpacityChanged(opacity) end
    return opacity
end

-- Visibility intent ----------------------------------------------------------
-- windowIntent records what the player asked for: shown (login, slash command,
-- settings button) or hidden (the close button). It lets the addon restore the
-- window if a client-side routine hides it as a side effect of closing another
-- frame.

function ns.ShowWindow()
    local frame = ns.EnsureWindow()
    ns.windowIntent = true
    frame:Show()
    if frame.update and ns.lastScan then
        frame.update(ns.lastScan)
    end
    if ns.RequestRefresh then ns.RequestRefresh(0, true) end
end

function ns.HideWindow()
    ns.windowIntent = false
    if ns.window then ns.window:Hide() end
end

function ns.ToggleWindow()
    if ns.IsWindowShown() then
        ns.HideWindow()
    else
        ns.ShowWindow()
    end
end

function ns.IsWindowShown()
    return ns.window ~= nil and ns.window:IsShown()
end

-- Re-shows the window after an unrelated frame closed, but only when the player
-- left it open on purpose.
function ns.RestoreWindowIfIntended()
    if ns.windowIntent and ns.window and not ns.window:IsShown() then
        ns.window:Show()
    end
end

-- Collapse / layout ----------------------------------------------------------

function ns.SetCollapsed(collapsed)
    local frame = ns.EnsureWindow()
    applyCollapsed(frame, collapsed)
end

function ns.ToggleCollapsed()
    local frame = ns.EnsureWindow()
    applyCollapsed(frame, not frame.collapsed)
end

function ns.IsCollapsed()
    return ns.window ~= nil and ns.window.collapsed and true or false
end

function ns.ResetLayout()
    local frame = ns.EnsureWindow()
    frame.collapsed = false
    frame.expandedHeight = DEFAULT_HEIGHT
    frame:SetResizable(true)
    setContentShown(frame, true)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    if frame.collapseButton then frame.collapseButton:SetText("-") end
    if frame.grips then
        for index = 1, #frame.grips do frame.grips[index]:Enable() end
    end
    if frame.update and ns.lastScan then frame.update(ns.lastScan) end
    if ns.db then
        ns.db.window = nil
        ns.db.collapsed = false
    end
    saveLayout(frame)
end
