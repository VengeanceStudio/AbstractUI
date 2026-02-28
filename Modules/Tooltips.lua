local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Tooltips = MidnightUI:NewModule("Tooltips", "AceEvent-3.0", "AceHook-3.0")

-- ============================================================================
-- Module Initialization
-- ============================================================================

function Tooltips:OnInitialize()
    self.db = MidnightUI.db:RegisterNamespace("Tooltips", {
        profile = {
            borderSize = 2,
            backdropAlpha = 0.95,
            fontSize = 12,
            
            -- Cursor Following
            cursorFollow = false,
            cursorAnchor = "BOTTOMRIGHT",
            offsetX = 0,
            offsetY = 0,
            fadeDelay = 0.2,
            scale = 1.0,
            
            -- Tooltip Anchor (when not following cursor)
            anchorPosition = {
                point = "BOTTOMRIGHT",
                x = -100,
                y = 100
            },
            
            -- Player Information
            classColor = true,
            classColoredBorders = true,
            showGuild = true,
            yourGuildColor = {r = 0.25, g = 1.0, b = 0.25},
            otherGuildColor = {r = 0.67, g = 0.83, b = 0.45},
            showStatus = true,
            showItemLevel = true,
            showFaction = true,
            showMount = true,
            showRole = true,
            showMythicScore = true,
            showTargetOf = true,
            
            -- Item Tooltips
            qualityBorderColors = true,
            
            -- Combat
            hideInCombat = false,
            hideInInstance = false,
        }
    })
    
    -- Store references to tooltip frames we'll be styling
    self.tooltips = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        FriendsTooltip,
        WorldMapTooltip,
        WorldMapCompareTooltip1,
        WorldMapCompareTooltip2,
    }
    
    -- Cache for player data and inspection throttling
    self.playerCache = {}
    self.lastInspectTime = 0
    self.lastInspectGUID = nil
    self.inspectThrottle = 1.5  -- seconds
end

function Tooltips:OnEnable()
    -- Wait for theme system to be ready
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "Initialize")
    -- Listen for move mode changes
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
end

function Tooltips:OnDisable()
    self:UnhookAll()
end

function Tooltips:Initialize()
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    if not ColorPalette or not FontKit then
        MidnightUI:Print("Tooltips module: ColorPalette or FontKit not available")
        return
    end
    
    self.ColorPalette = ColorPalette
    self.FontKit = FontKit
    
    -- Apply styling to all tooltip frames
    self:StyleTooltips()
    
    -- Hook for dynamic tooltips
    self:SecureHook("GameTooltip_SetDefaultAnchor")
    
    -- Hook tooltip show events for cursor following
    if self.db.profile.cursorFollow then
        self:EnableCursorFollow()
    end
    
    -- Hook unit tooltips for player information using modern API
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            self:OnTooltipSetUnit(tooltip)
        end)
        -- Hook for item tooltips
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            self:OnTooltipSetItem(tooltip)
        end)
    else
        -- Fallback for older API - hook OnShow and check for unit
        GameTooltip:HookScript("OnShow", function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit then
                self:OnTooltipSetUnit(tooltip)
            end
        end)
    end
    
    -- Hook for combat hiding
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    -- Hook for target-based inspection
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Listen for inspect data
    self:RegisterEvent("INSPECT_READY")
    
    -- Listen for theme changes
    self:RegisterMessage("MIDNIGHTUI_THEME_CHANGED", "OnThemeChanged")
    
    -- Create tooltip anchor frame
    self:CreateTooltipAnchor()
    
    -- Hook all tooltips including addon tooltips (safe delayed scan)
    C_Timer.After(2, function()
        self:HookAllTooltips()
    end)
end

function Tooltips:HookAllTooltips()
    -- Don't scan during combat to avoid taint
    if InCombatLockdown() then
        C_Timer.After(2, function()
            self:HookAllTooltips()
        end)
        return
    end
    
    -- Only hook specific known tooltip frames to avoid taint
    local tooltipNames = {
        "GameTooltip",
        "ItemRefTooltip",
        "ShoppingTooltip1",
        "ShoppingTooltip2",
        "BaganatorTooltip",
        "BaganatorItemViewTooltip",
    }
    
    for _, name in ipairs(tooltipNames) do
        local tooltip = _G[name]
        if tooltip and tooltip.GetObjectType and tooltip:GetObjectType() == "GameTooltip" then
            if not self:IsHooked(tooltip, "OnShow") then
                self:HookScript(tooltip, "OnShow", function(tip)
                    self:StyleTooltip(tip)
                end)
            end
        end
    end
end

-- ============================================================================
-- Tooltip Anchor Frame (for non-cursor following mode)
-- ============================================================================

function Tooltips:CreateTooltipAnchor()
    if self.anchorFrame then return end
    
    local Movable = MidnightUI:GetModule("Movable", true)
    if not Movable then return end
    
    local frame = CreateFrame("Frame", "MidnightUI_TooltipAnchor", UIParent, "BackdropTemplate")
    frame:SetSize(32, 32)
    
    local pos = self.db.profile.anchorPosition
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    -- Backdrop (match UnitFrame move boxes exactly)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    frame:SetBackdropColor(0, 0.5, 0, 0.2)  -- Semi-transparent green
    frame:SetBackdropBorderColor(0, 1, 0, 1) -- Bright green border
    
    -- Text "T"
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.text:SetPoint("CENTER")
    frame.text:SetText("T")
    frame.text:SetTextColor(1, 1, 1, 1)
    frame.text:SetShadowOffset(2, -2)
    frame.text:SetShadowColor(0, 0, 0, 1)
    
    -- Use Movable for drag functionality
    Movable:MakeFrameDraggable(
        frame,
        function(point, x, y)
            self.db.profile.anchorPosition = { point = point, x = x, y = y }
            Movable:UpdateNudgeArrows(frame)
        end,
        function() return true end -- Always movable when visible
    )
    
    -- Create nudge arrows
    Movable:CreateNudgeArrows(frame, self.db)
    
    -- Hide by default (only show in move mode)
    frame:Hide()
    
    self.anchorFrame = frame
end

function Tooltips:OnMoveModeChanged(event, moveMode)
    if not self.anchorFrame then return end
    
    if moveMode then
        self.anchorFrame:Show()
    else
        self.anchorFrame:Hide()
    end
end

-- ============================================================================
-- Tooltip Styling
-- ============================================================================

function Tooltips:StyleTooltips()
    if not self.ColorPalette then return end
    
    for _, tooltip in ipairs(self.tooltips) do
        if tooltip then
            self:StyleTooltip(tooltip)
        end
    end
end

function Tooltips:StyleTooltip(tooltip, itemQuality, classColor)
    if not tooltip or not self.ColorPalette then return end
    
    local br, bg, bb, ba = self.ColorPalette:GetColor("panel-border")
    local bgr, bgg, bgb, bga = self.ColorPalette:GetColor("tooltip-bg")
    
    -- Override border color with class color if provided and enabled
    if classColor and self.db.profile.classColoredBorders then
        br, bg, bb = classColor.r, classColor.g, classColor.b
    -- Override border color with item quality color if enabled
    elseif itemQuality and self.db.profile.qualityBorderColors then
        local r, g, b, hex = C_Item.GetItemQualityColor(itemQuality)
        if r then
            br, bg, bb = r, g, b
        end
    end
    
    -- Apply backdrop alpha override if set
    if self.db.profile.backdropAlpha then
        bga = self.db.profile.backdropAlpha
    end
    
    -- Modern WoW uses NineSlice system for tooltips
    if tooltip.NineSlice then
        -- Style the NineSlice border textures
        local borderSize = self.db.profile.borderSize or 2
        
        -- Set border color
        if tooltip.NineSlice.TopEdge then
            tooltip.NineSlice.TopEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.TopEdge:SetHeight(borderSize)
        end
        if tooltip.NineSlice.BottomEdge then
            tooltip.NineSlice.BottomEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.BottomEdge:SetHeight(borderSize)
        end
        if tooltip.NineSlice.LeftEdge then
            tooltip.NineSlice.LeftEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.LeftEdge:SetWidth(borderSize)
        end
        if tooltip.NineSlice.RightEdge then
            tooltip.NineSlice.RightEdge:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.RightEdge:SetWidth(borderSize)
        end
        
        -- Set corner colors to match border
        if tooltip.NineSlice.TopLeftCorner then
            tooltip.NineSlice.TopLeftCorner:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.TopLeftCorner:SetSize(borderSize, borderSize)
        end
        if tooltip.NineSlice.TopRightCorner then
            tooltip.NineSlice.TopRightCorner:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.TopRightCorner:SetSize(borderSize, borderSize)
        end
        if tooltip.NineSlice.BottomLeftCorner then
            tooltip.NineSlice.BottomLeftCorner:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.BottomLeftCorner:SetSize(borderSize, borderSize)
        end
        if tooltip.NineSlice.BottomRightCorner then
            tooltip.NineSlice.BottomRightCorner:SetColorTexture(br, bg, bb, ba)
            tooltip.NineSlice.BottomRightCorner:SetSize(borderSize, borderSize)
        end
        
        -- Create or update background texture
        if not tooltip.MidnightBG then
            tooltip.MidnightBG = tooltip:CreateTexture(nil, "BACKGROUND")
            tooltip.MidnightBG:SetAllPoints(tooltip)
            tooltip.MidnightBG:SetDrawLayer("BACKGROUND", -8)
        end
        tooltip.MidnightBG:SetColorTexture(bgr, bgg, bgb, bga)
    end
    
    -- Hook to update font when tooltip shows
    if self.FontKit and not self:IsHooked(tooltip, "OnShow") then
        self:HookScript(tooltip, "OnShow", "OnTooltipShow")
    end
end

function Tooltips:OnTooltipShow(tooltip)
    if not self.FontKit or not tooltip then return end
    
    -- Apply font to tooltip text
    local font, size = self.FontKit:GetFont("body", "small")
    local fontSize = self.db.profile.fontSize or 12
    
    -- Update header font
    if tooltip.TextLeft1 then
        tooltip.TextLeft1:SetFont(font, fontSize + 2, "OUTLINE")
    end
    
    -- Update all other text lines
    for i = 2, tooltip:NumLines() do
        local leftText = _G[tooltip:GetName() .. "TextLeft" .. i]
        local rightText = _G[tooltip:GetName() .. "TextRight" .. i]
        
        if leftText then
            leftText:SetFont(font, fontSize, "")
        end
        if rightText then
            rightText:SetFont(font, fontSize, "")
        end
    end
    
    -- Position shopping tooltips if this is GameTooltip
    if tooltip == GameTooltip then
        self:PositionShoppingTooltips()
    end
end

function Tooltips:GameTooltip_SetDefaultAnchor(tooltip, parent)
    -- Handle cursor following
    if self.db.profile.cursorFollow then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        tooltip:ClearAllPoints()
        
        local scale = self.db.profile.scale or 1.0
        tooltip:SetScale(scale)
        
        local x, y = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        x = x / uiScale
        y = y / uiScale
        
        local anchor = self.db.profile.cursorAnchor or "BOTTOMRIGHT"
        local offsetX = self.db.profile.offsetX or 0
        local offsetY = self.db.profile.offsetY or 0
        
        tooltip:SetPoint(anchor, UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
        
        -- Set fade delay
        if tooltip.FadeOut then
            tooltip.FadeOut:SetStartDelay(self.db.profile.fadeDelay or 0.2)
        end
    else
        -- Use custom anchor position when not following cursor
        local scale = self.db.profile.scale or 1.0
        tooltip:SetScale(scale)
        
        -- Anchor to our custom position
        local pos = self.db.profile.anchorPosition
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMLEFT", UIParent, pos.point, pos.x, pos.y)
    end
    
    -- Reapply styling when tooltip anchor is set
    self:StyleTooltip(tooltip)
end

function Tooltips:OnThemeChanged()
    -- Reapply styling when theme changes
    self:StyleTooltips()
end

-- ============================================================================
-- Combat & Instance Handling
-- ============================================================================

function Tooltips:PLAYER_REGEN_DISABLED()
    -- Entering combat
    if self.db.profile.hideInCombat then
        local inInstance = self.db.profile.hideInInstance and IsInInstance()
        if not self.db.profile.hideInInstance or inInstance then
            -- Hide all tooltips
            for _, tooltip in ipairs(self.tooltips) do
                if tooltip and tooltip:IsShown() then
                    tooltip:Hide()
                end
            end
        end
    end
end

function Tooltips:PLAYER_REGEN_ENABLED()
    -- Leaving combat - tooltips will show normally again
end

-- ============================================================================
-- Item Tooltip Handling
-- ============================================================================

function Tooltips:OnTooltipSetItem(tooltip)
    if not tooltip then return end
    
    -- Get item quality for border coloring
    if tooltip.GetItem then
        local _, item = tooltip:GetItem()
        if item then
            local itemQuality = C_Item.GetItemQualityByID(item)
            if itemQuality then
                -- Only use quality color for uncommon+ items, but always restyle
                local qualityForBorder = (itemQuality >= Enum.ItemQuality.Uncommon) and itemQuality or nil
                self:StyleTooltip(tooltip, qualityForBorder)
            end
        end
    else
        -- For tooltips without GetItem (like ShoppingTooltips), just apply basic styling
        self:StyleTooltip(tooltip)
    end
end

function Tooltips:PositionShoppingTooltips()
    -- Position shopping tooltips intelligently based on GameTooltip position
    if not GameTooltip:IsShown() then return end
    
    local shoppingTooltip1 = ShoppingTooltip1
    local shoppingTooltip2 = ShoppingTooltip2
    
    if shoppingTooltip1 and shoppingTooltip1:IsShown() then
        shoppingTooltip1:ClearAllPoints()
        
        -- Check if GameTooltip is on the right side of screen
        local gameTooltipCenter = GameTooltip:GetCenter()
        local screenWidth = GetScreenWidth()
        
        if gameTooltipCenter and gameTooltipCenter > (screenWidth / 2) then
            -- GameTooltip is on right, place shopping tooltip on left
            shoppingTooltip1:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -3, 0)
        else
            -- GameTooltip is on left, place shopping tooltip on right
            shoppingTooltip1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 3, 0)
        end
        
        -- Position second shopping tooltip below first
        if shoppingTooltip2 and shoppingTooltip2:IsShown() then
            shoppingTooltip2:ClearAllPoints()
            shoppingTooltip2:SetPoint("TOPLEFT", shoppingTooltip1, "BOTTOMLEFT", 0, -3)
        end
    end
end

-- ============================================================================
-- Cursor Following
-- ============================================================================

function Tooltips:EnableCursorFollow()
    for _, tooltip in ipairs(self.tooltips) do
        if tooltip and not self:IsHooked(tooltip, "OnUpdate") then
            self:HookScript(tooltip, "OnUpdate", "OnTooltipUpdate")
        end
    end
end

function Tooltips:OnTooltipUpdate(tooltip, elapsed)
    if not self.db.profile.cursorFollow or not tooltip:IsShown() then return end
    
    local x, y = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    x = x / uiScale
    y = y / uiScale
    
    local anchor = self.db.profile.cursorAnchor or "BOTTOMRIGHT"
    local offsetX = self.db.profile.offsetX or 0
    local offsetY = self.db.profile.offsetY or 0
    
    tooltip:ClearAllPoints()
    tooltip:SetPoint(anchor, UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
end

-- ============================================================================
-- Player Information
-- ============================================================================

function Tooltips:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    
    -- Protect against secret unit values in combat
    local unitExists = false
    local ok = pcall(function()
        unitExists = unit and UnitExists(unit)
    end)
    if not ok or not unitExists then return end
    
    -- Only process players
    local isPlayer = false
    ok = pcall(function()
        isPlayer = UnitIsPlayer(unit)
    end)
    if not ok or not isPlayer then return end
    
    local name, realm = UnitName(unit)
    local guid = UnitGUID(unit)
    
    if not name or not guid then return end
    
    -- Get class color for border (if enabled)
    local classColor = nil
    local _, class = UnitClass(unit)
    if class then
        classColor = RAID_CLASS_COLORS[class]
        
        -- Class coloring for player names
        if self.db.profile.classColor and classColor then
            -- Modify the first line's color instead of clearing and re-adding
            local textLeft1 = _G[tooltip:GetName().."TextLeft1"]
            if textLeft1 then
                textLeft1:SetTextColor(classColor.r, classColor.g, classColor.b)
            end
        end
    end
    
    -- Apply class-colored border if enabled
    if self.db.profile.classColoredBorders and classColor then
        self:StyleTooltip(tooltip, nil, classColor)
    end
    
    -- Guild information
    if self.db.profile.showGuild then
        local guildName, guildRankName, guildRankIndex = GetGuildInfo(unit)
        if guildName then
            local playerGuildName = GetGuildInfo("player")
            local color = self.db.profile.otherGuildColor
            
            if guildName == playerGuildName then
                color = self.db.profile.yourGuildColor
            end
            
            tooltip:AddLine(string.format("<%s>", guildName), color.r, color.g, color.b)
            if guildRankName then
                tooltip:AddLine(guildRankName, 0.7, 0.7, 0.7)
            end
        end
    end
    
    -- Player status (AFK/DND)
    if self.db.profile.showStatus then
        if UnitIsAFK(unit) then
            tooltip:AddLine("|cffFF0000<AFK>|r")
        elseif UnitIsDND(unit) then
            tooltip:AddLine("|cffFF0000<DND>|r")
        end
    end
    
    -- Faction
    if self.db.profile.showFaction then
        local faction = UnitFactionGroup(unit)
        if faction then
            local color = faction == "Horde" and {r = 1, g = 0.1, b = 0.1} or {r = 0.1, g = 0.3, b = 1}
            tooltip:AddLine(faction, color.r, color.g, color.b)
        end
    end
    
    -- Target of target
    if self.db.profile.showTargetOf then
        local target = unit .. "target"
        if UnitExists(target) then
            local targetName = UnitName(target)
            if targetName then
                tooltip:AddLine("Target: " .. targetName, 0.7, 0.7, 1)
            end
        end
    end
    
    -- Role
    if self.db.profile.showRole then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            local roleText = role == "TANK" and "Tank" or role == "HEALER" and "Healer" or role == "DAMAGER" and "DPS" or role
            local roleColor = role == "TANK" and {r = 0.2, g = 0.6, b = 1} or 
                              role == "HEALER" and {r = 0.2, g = 1, b = 0.2} or 
                              {r = 1, g = 0.2, b = 0.2}
            tooltip:AddLine("Role: " .. roleText, roleColor.r, roleColor.g, roleColor.b)
        end
    end
    
    -- Item Level (from cache)
    if self.db.profile.showItemLevel then
        local cachedIlvl = self:GetCachedItemLevel(guid)
        if cachedIlvl then
            tooltip:AddLine("Item Level: " .. cachedIlvl, 1, 0.82, 0)
        end
        -- Don't request inspect here - handled by PLAYER_TARGET_CHANGED
    end
    
    -- Mythic+ Rating
    if self.db.profile.showMythicScore and C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        if summary and summary.currentSeasonScore and summary.currentSeasonScore > 0 then
            local score = summary.currentSeasonScore
            local color = C_ChallengeMode.GetDungeonScoreRarityColor(score) or {r = 1, g = 1, b = 1}
            tooltip:AddLine(string.format("M+ Rating: %.0f", score), color.r, color.g, color.b)
        end
    end
    
    -- Mount information
    if self.db.profile.showMount then
        local mountID = self:GetUnitMountID(unit)
        if mountID then
            local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, 
                  faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountID)
            if name then
                local collectedText = isCollected and "|cff00ff00(Collected)|r" or "|cffff0000(Not Collected)|r"
                tooltip:AddLine("Mount: " .. name .. " " .. collectedText, 1, 0.82, 0)
            end
        end
    end
    
    tooltip:Show()
end

function Tooltips:GetUnitMountID(unit)
    -- Check if unit has a mount buff using modern API
    if not C_UnitAuras then return nil end
    
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not auraData then break end
        
        -- Check if this buff is a mount (WoW 12.0: protect against secret spellId)
        if auraData.spellId and C_MountJournal then
            for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
                local mountName, mountSpellID = C_MountJournal.GetMountInfoByID(mountID)
                -- Use pcall to safely compare secret spell IDs
                local ok, matches = pcall(function() return mountSpellID == auraData.spellId end)
                if ok and matches then
                    return mountID
                end
            end
        end
    end
    return nil
end

function Tooltips:INSPECT_READY(event, guid)
    if not guid then return end
    
    -- Cache item level from inspect data (GUID-based storage)
    local unit = self:GetUnitFromGUID(guid)
    if unit then
        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel(unit)
        if avgItemLevelEquipped then
            self.playerCache[guid] = {
                itemLevel = math.floor(avgItemLevelEquipped),
                timestamp = GetTime()
            }
        end
    end
    
    ClearInspectPlayer()
end

function Tooltips:PLAYER_TARGET_CHANGED()
    -- Target-based inspection with throttling
    if not self.db.profile.showItemLevel then return end
    
    local unit = "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    
    local guid = UnitGUID(unit)
    if not guid then return end
    
    -- Check if we already have cached data
    local cached = self:GetCachedItemLevel(guid)
    if cached then return end
    
    -- Check if we can inspect
    if not CanInspect(unit) then return end
    
    -- Throttle inspect requests (1.5 second cooldown)
    local currentTime = GetTime()
    if currentTime - self.lastInspectTime < self.inspectThrottle then
        return
    end
    
    -- Don't spam the same player
    if guid == self.lastInspectGUID and currentTime - self.lastInspectTime < 30 then
        return
    end
    
    -- Send inspect request (taint-safe)
    self.lastInspectTime = currentTime
    self.lastInspectGUID = guid
    NotifyInspect(unit)
end

function Tooltips:GetUnitFromGUID(guid)
    -- Check raid/party
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    end
    
    -- Check target/focus
    if UnitGUID("target") == guid then return "target" end
    if UnitGUID("focus") == guid then return "focus" end
    if UnitGUID("mouseover") == guid then return "mouseover" end
    
    return nil
end

function Tooltips:GetCachedItemLevel(guid)
    local cache = self.playerCache[guid]
    if cache then
        -- Cache expires after 5 minutes
        if GetTime() - cache.timestamp < 300 then
            return cache.itemLevel
        else
            self.playerCache[guid] = nil
        end
    end
    return nil
end

-- ============================================================================
-- Module Enable/Disable
-- ============================================================================

function Tooltips:UpdateSettings()
    
    -- Update cursor following
    if self.db.profile.cursorFollow then
        self:EnableCursorFollow()
    end
    
    -- Reapply all styling with new settings
    self:StyleTooltips()
end

-- ============================================================================
-- Options
-- ============================================================================

function Tooltips:GetOptions()
    return {
        name = "Tooltips",
        type = "group",
        args = {
            description = {
                type = "description",
                name = "Customize tooltip appearance and information display. Use the Tooltips toggle on the General tab to enable/disable this module.\n\n|cffFFD700Smart Inspection System:|r Item level data is cached for 5 minutes and only requested when you target a player (1.5s throttle to prevent API rate limiting).",
                order = 1,
                fontSize = "medium",
            },
            spacer1 = {
                type = "description",
                name = " ",
                order = 2,
            },
            
            -- Appearance Settings
            appearanceHeader = {
                type = "header",
                name = "Appearance Settings",
                order = 10
            },
            borderSize = {
                type = "range",
                name = "Border Size",
                desc = "Thickness of tooltip borders",
                min = 1,
                max = 5,
                step = 1,
                order = 11,
                get = function() return self.db.profile.borderSize end,
                set = function(_, value)
                    self.db.profile.borderSize = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            backdropAlpha = {
                type = "range",
                name = "Background Opacity",
                desc = "Opacity of tooltip backgrounds (overrides theme setting)",
                min = 0,
                max = 1,
                step = 0.05,
                order = 12,
                get = function() return self.db.profile.backdropAlpha end,
                set = function(_, value)
                    self.db.profile.backdropAlpha = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            fontSize = {
                type = "range",
                name = "Font Size",
                desc = "Size of tooltip text",
                min = 8,
                max = 18,
                step = 1,
                order = 13,
                get = function() return self.db.profile.fontSize end,
                set = function(_, value)
                    self.db.profile.fontSize = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            spacer2 = {
                type = "description",
                name = " ",
                order = 19,
            },
            
            -- Item Tooltips
            itemHeader = {
                type = "header",
                name = "Item Tooltips",
                order = 19.5
            },
            qualityBorderColors = {
                type = "toggle",
                name = "Quality Border Colors",
                desc = "Color tooltip borders based on item quality (uncommon and above)",
                order = 19.6,
                get = function() return self.db.profile.qualityBorderColors end,
                set = function(_, value)
                    self.db.profile.qualityBorderColors = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            spacer2b = {
                type = "description",
                name = " ",
                order = 19.8,
            },
            
            -- Cursor Following
            cursorHeader = {
                type = "header",
                name = "Cursor Following",
                order = 20
            },
            cursorFollow = {
                type = "toggle",
                name = "Follow Cursor",
                desc = "Tooltips will follow your mouse cursor",
                order = 21,
                get = function() return self.db.profile.cursorFollow end,
                set = function(_, value)
                    self.db.profile.cursorFollow = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            cursorAnchor = {
                type = "select",
                name = "Cursor Anchor",
                desc = "Where the tooltip anchors to the cursor",
                order = 22,
                values = {
                    ["TOPLEFT"] = "Top Left",
                    ["TOP"] = "Top",
                    ["TOPRIGHT"] = "Top Right",
                    ["LEFT"] = "Left",
                    ["CENTER"] = "Center",
                    ["RIGHT"] = "Right",
                    ["BOTTOMLEFT"] = "Bottom Left",
                    ["BOTTOM"] = "Bottom",
                    ["BOTTOMRIGHT"] = "Bottom Right",
                },
                get = function() return self.db.profile.cursorAnchor end,
                set = function(_, value)
                    self.db.profile.cursorAnchor = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.cursorFollow end,
            },
            offsetX = {
                type = "range",
                name = "X Offset",
                desc = "Horizontal offset from cursor",
                min = -100,
                max = 100,
                step = 1,
                order = 23,
                get = function() return self.db.profile.offsetX end,
                set = function(_, value)
                    self.db.profile.offsetX = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.cursorFollow end,
            },
            offsetY = {
                type = "range",
                name = "Y Offset",
                desc = "Vertical offset from cursor",
                min = -100,
                max = 100,
                step = 1,
                order = 24,
                get = function() return self.db.profile.offsetY end,
                set = function(_, value)
                    self.db.profile.offsetY = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.cursorFollow end,
            },
            fadeDelay = {
                type = "range",
                name = "Fade Delay",
                desc = "How quickly tooltips fade out (in seconds)",
                min = 0,
                max = 2,
                step = 0.1,
                order = 25,
                get = function() return self.db.profile.fadeDelay end,
                set = function(_, value)
                    self.db.profile.fadeDelay = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            scale = {
                type = "range",
                name = "Tooltip Scale",
                desc = "Overall size of tooltips (50% to 200%)",
                min = 0.5,
                max = 2.0,
                step = 0.05,
                order = 26,
                get = function() return self.db.profile.scale end,
                set = function(_, value)
                    self.db.profile.scale = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            spacer3 = {
                type = "description",
                name = " ",
                order = 29,
            },
            
            -- Combat & Instances
            combatHeader = {
                type = "header",
                name = "Combat & Instances",
                order = 29.5
            },
            hideInCombat = {
                type = "toggle",
                name = "Hide in Combat",
                desc = "Hide tooltips when entering combat",
                order = 29.6,
                get = function() return self.db.profile.hideInCombat end,
                set = function(_, value)
                    self.db.profile.hideInCombat = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            hideInInstance = {
                type = "toggle",
                name = "Only in Dungeons/Raids",
                desc = "Only hide tooltips in combat when inside a dungeon or raid",
                order = 29.7,
                get = function() return self.db.profile.hideInInstance end,
                set = function(_, value)
                    self.db.profile.hideInInstance = value
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.hideInCombat end,
            },
            spacer3b = {
                type = "description",
                name = " ",
                order = 29.8,
            },
            
            -- Player Information
            playerInfoHeader = {
                type = "header",
                name = "Player Information",
                order = 30
            },
            classColor = {
                type = "toggle",
                name = "Class-Colored Names",
                desc = "Display player names in their class colors",
                order = 31,
                get = function() return self.db.profile.classColor end,
                set = function(_, value)
                    self.db.profile.classColor = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            classColoredBorders = {
                type = "toggle",
                name = "Class-Colored Borders",
                desc = "Color tooltip borders based on player class (overrides theme border color)",
                order = 31.5,
                get = function() return self.db.profile.classColoredBorders end,
                set = function(_, value)
                    self.db.profile.classColoredBorders = value
                    self:UpdateSettings()
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showGuild = {
                type = "toggle",
                name = "Show Guild",
                desc = "Display guild information",
                order = 32,
                get = function() return self.db.profile.showGuild end,
                set = function(_, value)
                    self.db.profile.showGuild = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            yourGuildColor = {
                type = "color",
                name = "Your Guild Color",
                desc = "Color for your guild members",
                order = 33,
                get = function()
                    local c = self.db.profile.yourGuildColor
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    self.db.profile.yourGuildColor = {r = r, g = g, b = b}
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.showGuild end,
            },
            otherGuildColor = {
                type = "color",
                name = "Other Guild Color",
                desc = "Color for other guild members",
                order = 34,
                get = function()
                    local c = self.db.profile.otherGuildColor
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    self.db.profile.otherGuildColor = {r = r, g = g, b = b}
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.showGuild end,
            },
            showStatus = {
                type = "toggle",
                name = "Show AFK/DND Status",
                desc = "Display player AFK or DND status",
                order = 35,
                get = function() return self.db.profile.showStatus end,
                set = function(_, value)
                    self.db.profile.showStatus = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showItemLevel = {
                type = "toggle",
                name = "Show Item Level",
                desc = "Display player item levels (requires inspect)",
                order = 36,
                get = function() return self.db.profile.showItemLevel end,
                set = function(_, value)
                    self.db.profile.showItemLevel = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showFaction = {
                type = "toggle",
                name = "Show Faction",
                desc = "Display player faction (Horde/Alliance)",
                order = 37,
                get = function() return self.db.profile.showFaction end,
                set = function(_, value)
                    self.db.profile.showFaction = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showMount = {
                type = "toggle",
                name = "Show Mount Info",
                desc = "Display mounted player's mount and if you have it collected",
                order = 38,
                get = function() return self.db.profile.showMount end,
                set = function(_, value)
                    self.db.profile.showMount = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showRole = {
                type = "toggle",
                name = "Show Role",
                desc = "Display player role (Tank/Healer/DPS)",
                order = 39,
                get = function() return self.db.profile.showRole end,
                set = function(_, value)
                    self.db.profile.showRole = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showMythicScore = {
                type = "toggle",
                name = "Show Mythic+ Rating",
                desc = "Display player's Mythic+ score",
                order = 40,
                get = function() return self.db.profile.showMythicScore end,
                set = function(_, value)
                    self.db.profile.showMythicScore = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            showTargetOf = {
                type = "toggle",
                name = "Show Target Of Target",
                desc = "Display who the unit is targeting",
                order = 41,
                get = function() return self.db.profile.showTargetOf end,
                set = function(_, value)
                    self.db.profile.showTargetOf = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
        }
    }
end
