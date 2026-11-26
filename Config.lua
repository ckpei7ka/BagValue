-- Configuration surface: a Settings panel when the modern Settings API exists,
-- plus the slash commands in Core.lua as the always-available fallback.

local _, ns = ...

local function buildPanel()
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return nil
    end

    local panel = CreateFrame("Frame", "BagValueOptionsPanel")
    panel.name = "BagValue"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BagValue")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Version " .. ns.version .. " · vendor and auction value of every bag")

    local enable = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    enable.Text:SetText("Enable BagValue")
    enable:SetChecked(ns.db.enabled)
    enable:SetScript("OnClick", function(self)
        ns.db.enabled = self:GetChecked() and true or false
        ns.Print("addon " .. (ns.db.enabled and "enabled" or "disabled"))
    end)

    local showOnLogin = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    showOnLogin:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -6)
    showOnLogin.Text:SetText("Keep the window open (show it at login)")
    showOnLogin:SetChecked(ns.db.showOnLogin)
    showOnLogin:SetScript("OnClick", function(self)
        ns.db.showOnLogin = self:GetChecked() and true or false
        if ns.db.showOnLogin and ns.ShowWindow then
            ns.ShowWindow()
        end
    end)

    local appearanceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceLabel:SetPoint("TOPLEFT", showOnLogin, "BOTTOMLEFT", 0, -18)
    appearanceLabel:SetText("Window style")

    local skinButtons = {}
    local function refreshSkinButtons()
        for index = 1, #skinButtons do
            local button = skinButtons[index]
            local selected = ns.db.skin == button.skinId
            button:SetText((selected and "> " or "") .. button.skinLabel)
            local font = button:GetFontString()
            if font then
                if selected then
                    font:SetTextColor(1, 0.82, 0)
                else
                    font:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    local skins = ns.skinList or {}
    for index = 1, #skins do
        local skin = skins[index]
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(84, 22)
        if index == 1 then
            button:SetPoint("TOPLEFT", appearanceLabel, "BOTTOMLEFT", 0, -6)
        else
            button:SetPoint("LEFT", skinButtons[#skinButtons], "RIGHT", 5, 0)
        end
        button.skinId = skin.id
        button.skinLabel = skin.label
        button:SetScript("OnClick", function(self)
            if ns.SetSkin then ns.SetSkin(self.skinId) end
        end)
        skinButtons[#skinButtons + 1] = button
    end
    refreshSkinButtons()
    ns.onSkinChanged = function()
        refreshSkinButtons()
    end

    -- Opacity slider. The template ships with every mainline client; a plain
    -- slider is the fallback so the settings never disappear if it is missing.
    local created, opacitySlider = pcall(CreateFrame, "Slider", "BagValueOpacitySlider",
        panel, "OptionsSliderTemplate")
    if not created then opacitySlider = nil end

    local fallbackLabel
    if not opacitySlider then
        opacitySlider = CreateFrame("Slider", "BagValueOpacitySliderFallback", panel)
        opacitySlider:SetSize(260, 16)
        opacitySlider:SetOrientation("HORIZONTAL")
        if type(opacitySlider.SetThumbTexture) == "function" then
            opacitySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        end
        fallbackLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fallbackLabel:SetPoint("TOPLEFT", opacitySlider, "TOPLEFT", 0, 20)
    end

    opacitySlider:SetPoint("TOPLEFT", skinButtons[1], "BOTTOMLEFT", 0, -24)
    opacitySlider:SetWidth(260)
    if type(opacitySlider.SetOrientation) == "function" then
        opacitySlider:SetOrientation("HORIZONTAL")
    end
    opacitySlider:SetMinMaxValues(20, 100)
    opacitySlider:SetValueStep(5)
    if type(opacitySlider.SetObeyStepOnDrag) == "function" then
        opacitySlider:SetObeyStepOnDrag(true)
    end

    local sliderLow = _G["BagValueOpacitySliderLow"]
    local sliderHigh = _G["BagValueOpacitySliderHigh"]
    local sliderText = _G["BagValueOpacitySliderText"]
    if sliderLow then sliderLow:SetText("20%") end
    if sliderHigh then sliderHigh:SetText("100%") end

    local function refreshOpacityText(value)
        local percent = math.floor((ns.SafeNumber(value, 94)) + 0.5)
        local label = ("Window opacity: %d%%"):format(percent)
        if sliderText then
            sliderText:SetText(label)
        elseif fallbackLabel then
            fallbackLabel:SetText(label)
        end
    end

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        refreshOpacityText(value)
        if ns.SetOpacity then ns.SetOpacity(value / 100) end
    end)

    -- Keep the slider in sync when the opacity changes from a slash command or
    -- another settings page. The guard stops the callback from bouncing.
    ns.onOpacityChanged = function(opacity)
        local target = math.floor(opacity * 100 + 0.5)
        local current = math.floor(opacitySlider:GetValue() + 0.5)
        if math.abs(current - target) >= 1 then
            opacitySlider:SetValue(target)
        end
    end

    opacitySlider:SetValue(math.floor((ns.GetOpacity and ns.GetOpacity() or 0.94) * 100 + 0.5))
    refreshOpacityText(opacitySlider:GetValue())

    -- Text size slider, next to the opacity one. It always writes an explicit
    -- size; /bagvalue fontsize 0 restores the per-style sizes.
    local sizeCreated, sizeSlider = pcall(CreateFrame, "Slider", "BagValueFontSlider",
        panel, "OptionsSliderTemplate")
    if not sizeCreated then sizeSlider = nil end

    local sizeFallbackLabel
    if not sizeSlider then
        sizeSlider = CreateFrame("Slider", "BagValueFontSliderFallback", panel)
        sizeSlider:SetSize(200, 16)
        sizeSlider:SetOrientation("HORIZONTAL")
        if type(sizeSlider.SetThumbTexture) == "function" then
            sizeSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        end
        sizeFallbackLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sizeFallbackLabel:SetPoint("TOPLEFT", sizeSlider, "TOPLEFT", 0, 20)
    end

    sizeSlider:SetPoint("TOPLEFT", opacitySlider, "TOPLEFT", 300, 0)
    sizeSlider:SetWidth(200)
    if type(sizeSlider.SetOrientation) == "function" then
        sizeSlider:SetOrientation("HORIZONTAL")
    end
    sizeSlider:SetMinMaxValues(8, 20)
    sizeSlider:SetValueStep(1)
    if type(sizeSlider.SetObeyStepOnDrag) == "function" then
        sizeSlider:SetObeyStepOnDrag(true)
    end

    local sizeLow = _G["BagValueFontSliderLow"]
    local sizeHigh = _G["BagValueFontSliderHigh"]
    local sizeText = _G["BagValueFontSliderText"]
    if sizeLow then sizeLow:SetText("8") end
    if sizeHigh then sizeHigh:SetText("20") end

    local function refreshSizeText(value)
        local size = math.floor((ns.SafeNumber(value, 12)) + 0.5)
        local label = ("Text size: %d"):format(size)
        if sizeText then
            sizeText:SetText(label)
        elseif sizeFallbackLabel then
            sizeFallbackLabel:SetText(label)
        end
    end

    local loadingSize = true
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        refreshSizeText(value)
        if loadingSize then return end
        if ns.SetFontSize then ns.SetFontSize(math.floor(value + 0.5)) end
    end)

    local initialSize = (ns.GetEffectiveFontSize and ns.GetEffectiveFontSize()) or 12
    sizeSlider:SetValue(initialSize)
    refreshSizeText(initialSize)
    loadingSize = false

    -- Keep the slider in sync with /bagvalue fontsize.
    ns.onFontSizeChanged = function(size)
        local target = size
        if not (type(target) == "number" and target >= 8) then
            target = (ns.GetEffectiveFontSize and ns.GetEffectiveFontSize()) or 12
        end
        target = math.floor(target + 0.5)
        if math.abs(sizeSlider:GetValue() - target) >= 1 then
            loadingSize = true
            sizeSlider:SetValue(target)
            loadingSize = false
        end
        refreshSizeText(target)
    end

    local appearanceHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    appearanceHint:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -10)
    appearanceHint:SetWidth(440)
    appearanceHint:SetJustifyH("LEFT")
    appearanceHint:SetText("The style, the opacity and the text size apply to the window immediately and are saved per account. " ..
        "Use /bagvalue fontsize 0 to go back to the size that comes with the style.")

    local sourceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sourceLabel:SetPoint("TOPLEFT", appearanceHint, "BOTTOMLEFT", 0, -16)
    sourceLabel:SetText("Auction price source")

    local sourceButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sourceButton:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -6)
    sourceButton:SetSize(300, 24)

    local customBox

    local function refreshSourceButton()
        sourceButton:SetText("Source: " .. (ns.DescribeSource(ns.db.priceSource) or "Auto"))
    end

    sourceButton:SetScript("OnClick", function(self)
        if ns.OpenSourceMenu then ns.OpenSourceMenu(self) end
    end)
    refreshSourceButton()
    ns.onSourceChanged = function()
        refreshSourceButton()
        if customBox then customBox:SetText(ns.db.customFunction or "") end
    end

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", sourceButton, "BOTTOMLEFT", 0, -6)
    hint:SetWidth(420)
    hint:SetJustifyH("LEFT")
    hint:SetText("Auto prefers TSM, then Auctionator. Other detected sources: " .. ns.DetectedSourceSummary())

    local customLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
    customLabel:SetText("Custom price function (global Lua function name)")

    customBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -6)
    customBox:SetSize(260, 20)
    customBox:SetAutoFocus(false)
    customBox:SetMaxLetters(80)
    customBox:SetText(ns.db.customFunction or "")

    local function saveCustomFunction(self)
        ns.db.customFunction = strtrim(self:GetText() or "")
        self:ClearFocus()
    end
    customBox:SetScript("OnEnterPressed", saveCustomFunction)
    customBox:SetScript("OnEditFocusLost", saveCustomFunction)

    local customHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    customHint:SetPoint("TOPLEFT", customBox, "BOTTOMLEFT", 0, -6)
    customHint:SetWidth(420)
    customHint:SetJustifyH("LEFT")
    customHint:SetText("Called as fn(itemLink, itemID) and must return copper. Use it for scanners without a public API.")

    local showButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    showButton:SetPoint("TOPLEFT", customHint, "BOTTOMLEFT", 0, -18)
    showButton:SetSize(180, 24)
    showButton:SetText("Show the window")
    showButton:SetScript("OnClick", function()
        if ns.ShowWindow then ns.ShowWindow() end
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("LEFT", showButton, "RIGHT", 8, 0)
    resetButton:SetSize(200, 24)
    resetButton:SetText("Reset window size and position")
    resetButton:SetScript("OnClick", function()
        if ns.ResetLayout then ns.ResetLayout() end
    end)

    local windowHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    windowHint:SetPoint("TOPLEFT", showButton, "BOTTOMLEFT", 0, -8)
    windowHint:SetWidth(460)
    windowHint:SetJustifyH("LEFT")
    windowHint:SetText("Drag the title bar to move the window, drag any corner to resize it diagonally, " ..
        "use the -/+ button in its top-right corner to collapse or expand it. " ..
        "The close button hides it until you open it again with /bagvalue.")

    -- Safety net for clients that hide unrelated frames when the options frame
    -- closes: restore the window if the player left it open on purpose.
    if type(SettingsPanel) == "table" and type(SettingsPanel.HookScript) == "function" then
        SettingsPanel:HookScript("OnHide", function()
            if ns.RestoreWindowIfIntended then ns.RestoreWindowIfIntended() end
        end)
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    return category
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    local ok, err = pcall(buildPanel)
    if not ok then
        if ns.Debug then ns.Debug("settings panel failed: " .. tostring(err)) end
    end
end)
