local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL SKIN
-- Modern, transparent skin for Blizzard's character panel
-- Inspired by Aurora - works WITH Blizzard's frames, not against them
---------------------------------------------------------------------------

local ColorPalette = nil
local FontKit = nil
local skinned = false

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function CharacterPane:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function CharacterPane:OnDBReady()
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    
    if not ColorPalette then return end
    
    self.db = AbstractUI.db:RegisterNamespace("CharacterPane", {
        profile = {
            enabled = true,
        }
    })
    
   self:RegisterEvent("ADDON_LOADED")
    
    if CharacterFrame then
        self:ApplySkin()
    end
end

function CharacterPane:ADDON_LOADED(event, addon)
    if addon == "Blizzard_CharacterFrame" or (addon == "AbstractUI" and CharacterFrame) then
        C_Timer.After(0.1, function()
            if CharacterFrame and not skinned then
                self:ApplySkin()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

local function GetThemeColors()
    if not ColorPalette then
        return 0.55, 0.60, 0.70, 0.85, 0.05, 0.05, 0.05, 0.65
    end
    local pr, pg, pb, pa = ColorPalette:GetColor('primary')
    local bgr, bgg, bgb, bga = ColorPalette:GetColor('panel-bg')
    return pr, pg, pb, pa or 0.85, bgr, bgg, bgb, bga or 0.65
end

local function IsEnabled()
    return CharacterPane.db and CharacterPane.db.profile.enabled
end

---------------------------------------------------------------------------
-- STRIP BLIZZARD TEXTURES (AURORA-STYLE)
---------------------------------------------------------------------------

local function StripBlizzardTextures()
    if not CharacterFrame then return end
    
    -- Hide CharacterFrame's own Bg if it exists
    if CharacterFrame.Bg then
        CharacterFrame.Bg:SetAlpha(0)
        CharacterFrame.Bg:Hide()
    end
    
    -- Hide all unnamed child frames (decorative borders/bars), but keep sidebar tabs
    local children = {CharacterFrame:GetChildren()}
    for i, child in ipairs(children) do
        local childName = child:GetName()
        -- Skip if this is PaperDollSidebarTabs or any named sidebar tab
        if child == PaperDollSidebarTabs or (childName and childName:find("PaperDollSidebarTab")) then
            -- Don't hide sidebar tabs
        elseif not childName or childName == "" then
            -- Hide unnamed decorative frames
            child:Hide()
            child:SetAlpha(0)
            
            -- Also hide all regions within
            if child.GetNumRegions then
                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                    end
                end
            end
        end
    end
    
    -- Strip ALL texture regions directly from CharacterFrame
    for i = 1, CharacterFrame:GetNumRegions() do
        local region = select(i, CharacterFrame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            -- Don't hide the portrait texture (we'll handle that separately)
            if region ~= CharacterFramePortrait then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
    -- Hide all the background/border textures from CharacterFrame
    local texturesToHide = {
        -- Character model background corners
        "CharacterModelFrameBackgroundTopLeft",
        "CharacterModelFrameBackgroundTopRight",
        "CharacterModelFrameBackgroundBotLeft",
        "CharacterModelFrameBackgroundBotRight",
        "CharacterModelFrameBackgroundOverlay",
        
        -- Inner borders around equipment area
        "PaperDollInnerBorderTopLeft",
        "PaperDollInnerBorderTopRight",
        "PaperDollInnerBorderBottomLeft",
        "PaperDollInnerBorderBottomRight",
        "PaperDollInnerBorderLeft",
        "PaperDollInnerBorderRight",
        "PaperDollInnerBorderTop",
        "PaperDollInnerBorderBottom",
        "PaperDollInnerBorderBottom2",
        
        -- Weapon slot decorative elements
        "PaperDollItemsFrameItemFlyoutHighlight",
    }
    
    for _, name in ipairs(texturesToHide) do
        local tex = _G[name]
        if tex then
            tex:Hide()
            tex:SetAlpha(0)
        end
    end
    
    -- Weapon slot backgrounds/bars - hide frames and all contents
    local weaponFrames = {
        "CharacterHandsSlotFrame",
        "CharacterMainHandSlotFrame", 
        "CharacterSecondaryHandSlotFrame",
    }
    
    for _, name in ipairs(weaponFrames) do
        local frame = _G[name]
        if frame then
            -- Nuclear approach - make them completely invisible
            frame:Hide()
            frame:SetAlpha(0)
            frame:SetScale(0.001)
            
            -- Move them off-screen
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10000, 10000)
            
            -- Prevent them from being shown
            if not frame._abstractHidden then
                hooksecurefunc(frame, "Show", function(self)
                    self:Hide()
                end)
                hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                    if alpha > 0 then
                        self:SetAlpha(0)
                    end
                end)
                frame._abstractHidden = true
            end
            
            -- Hide all texture regions within the frame
            if frame.GetNumRegions then
                for i = 1, frame:GetNumRegions() do
                    local region = select(i, frame:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                        if region.SetVertexColor then
                            region:SetVertexColor(0, 0, 0, 0)
                        end
                    end
                end
            end
            
            -- Hide all children
            if frame.GetChildren then
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    child:Hide()
                    child:SetAlpha(0)
                    
                    -- Also hide child's regions
                    if child.GetNumRegions then
                        for j = 1, child:GetNumRegions() do
                            local region = select(j, child:GetRegions())
                            if region then
                                region:SetAlpha(0)
                                region:Hide()
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Hide PaperDollItemsFrame decorations
    if PaperDollItemsFrame then
        -- Hide all texture regions
        for i = 1, PaperDollItemsFrame:GetNumRegions() do
            local region = select(i, PaperDollItemsFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
        
        -- Hide any child frames that aren't equipment slots or sidebar tabs
        local children = {PaperDollItemsFrame:GetChildren()}
        for _, child in ipairs(children) do
            local childName = child:GetName()
            -- Skip if this is PaperDollSidebarTabs, any sidebar tab, or an equipment slot
            if child == PaperDollSidebarTabs or 
               (childName and (childName:find("Slot$") or childName:find("PaperDollSidebarTab"))) then
                -- Don't hide these
            else
                -- Hide decorative frames
                child:Hide()
                child:SetAlpha(0)
                
                -- Hide the child's regions too
                if child.GetNumRegions then
                    for i = 1, child:GetNumRegions() do
                        local region = select(i, child:GetRegions())
                        if region then
                            region:SetAlpha(0)
                            region:Hide()
                        end
                    end
                end
            end
        end
    end
    
    -- Strip ALL textures from CharacterFrame's NineSlice including Center
    if CharacterFrame.NineSlice then
        -- Hide the entire NineSlice
        CharacterFrame.NineSlice:SetAlpha(0)
        CharacterFrame.NineSlice:Hide()
        
        local nineSlicePieces = {
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
            "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "Center"
        }
        
        for _, piece in ipairs(nineSlicePieces) do
            if CharacterFrame.NineSlice[piece] then
                CharacterFrame.NineSlice[piece]:SetAlpha(0)
                CharacterFrame.NineSlice[piece]:Hide()
            end
        end
    end
    
    -- Strip portrait
    if CharacterFramePortrait then
        CharacterFramePortrait:SetAlpha(0)
        CharacterFramePortrait:Hide()
    end
    
    -- Hide PaperDollFrame background completely
    if PaperDollFrame then
        if PaperDollFrame.Bg then
            PaperDollFrame.Bg:SetAlpha(0)
            PaperDollFrame.Bg:Hide()
        end
        
        -- Hide the level text (we create our own in titlebar)
        if CharacterLevelText then
            CharacterLevelText:Hide()
            CharacterLevelText:SetAlpha(0)
        end
        
        for i = 1, PaperDollFrame:GetNumRegions() do
            local region = select(i, PaperDollFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
    -- Strip textures from inset frames completely
    if CharacterFrame.Inset then
        CharacterFrame.Inset:SetAlpha(0)
        CharacterFrame.Inset:Hide()
        if CharacterFrame.Inset.Bg then
            CharacterFrame.Inset.Bg:SetAlpha(0)
            CharacterFrame.Inset.Bg:Hide()
        end
        if CharacterFrame.Inset.NineSlice then
            CharacterFrame.Inset.NineSlice:SetAlpha(0)
            CharacterFrame.Inset.NineSlice:Hide()
        end
    end
    
    -- Strip textures from InsetRight but KEEP IT VISIBLE (contains PaperDollSidebarTabs)
    if CharacterFrame.InsetRight then
        -- Don't hide or set alpha on the frame itself - it contains the sidebar tabs!
        CharacterFrame.InsetRight:Show()  -- Make sure it's visible
        CharacterFrame.InsetRight:SetAlpha(1)  -- Make sure it's fully opaque
        
        -- Only hide its background textures
        if CharacterFrame.InsetRight.Bg then
            CharacterFrame.InsetRight.Bg:SetAlpha(0)
            CharacterFrame.InsetRight.Bg:Hide()
        end
        if CharacterFrame.InsetRight.NineSlice then
            CharacterFrame.InsetRight.NineSlice:SetAlpha(0)
            CharacterFrame.InsetRight.NineSlice:Hide()
        end
    end
    
    -- Make model scene completely transparent background - hide ALL textures
    if CharacterModelScene then
        CharacterModelScene:SetAlpha(1) -- Keep model visible
        
        -- Reposition character model 15px to the right (preserve size)
        if not CharacterModelScene._abstractRepositioned then
            local point, relativeTo, relativePoint, xOfs, yOfs = CharacterModelScene:GetPoint(1)
            if point and relativeTo and relativePoint then
                CharacterModelScene:ClearAllPoints()
                CharacterModelScene:SetPoint(point, relativeTo, relativePoint, (xOfs or 0) + 15, yOfs or 0)
                CharacterModelScene._abstractRepositioned = true
            end
        end
        
        -- Hide all texture regions
        for i = 1, CharacterModelScene:GetNumRegions() do
            local region = select(i, CharacterModelScene:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
        
        -- Hide backdrop if it exists
        if CharacterModelScene.backdrop then
            CharacterModelScene.backdrop:SetAlpha(0)
            CharacterModelScene.backdrop:Hide()
        end
    end
    
    -- Hide sidebar tab decorations but keep tabs visible
    if PaperDollSidebarTabs then
        -- Make sure the tab container is visible
        PaperDollSidebarTabs:Show()
        PaperDollSidebarTabs:SetAlpha(1)
        
        if PaperDollSidebarTabs.DecorLeft then
            PaperDollSidebarTabs.DecorLeft:Hide()
            PaperDollSidebarTabs.DecorLeft:SetAlpha(0)
        end
        if PaperDollSidebarTabs.DecorRight then
            PaperDollSidebarTabs.DecorRight:Hide()
            PaperDollSidebarTabs.DecorRight:SetAlpha(0)
        end
    end
    
    -- Strip textures from stats pane completely
    if CharacterStatsPane then
        if CharacterStatsPane.ClassBackground then
            CharacterStatsPane.ClassBackground:SetAlpha(0)
            CharacterStatsPane.ClassBackground:Hide()
        end
        
        -- Hide all texture regions in stats pane
        for i = 1, CharacterStatsPane:GetNumRegions() do
            local region = select(i, CharacterStatsPane:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
    -- Hide Blizzard's titles pane completely
    if PaperDollFrame and PaperDollFrame.TitlesPane then
        PaperDollFrame.TitlesPane:Hide()
        PaperDollFrame.TitlesPane:SetAlpha(0)
    end
    if _G["PaperDollTitlesPane"] then
        _G["PaperDollTitlesPane"]:Hide()
        _G["PaperDollTitlesPane"]:SetAlpha(0)
    end

end

---------------------------------------------------------------------------
-- REPOSITION EQUIPMENT SLOTS WITH INFO
---------------------------------------------------------------------------

-- Equipment slots data storage
local equipmentInfo = {}

local function CreateEquipmentInfo(slotButton, slotName, side)
    if not slotButton or slotButton._infoCreated then return end
    
    local info = {}
    
    -- Position text based on which side the slot is on
    if side == "left" then
        -- Left side: text goes to the RIGHT of icon
        info.nameText = slotButton:CreateFontString(nil, "OVERLAY")
        info.nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        info.nameText:SetPoint("LEFT", slotButton, "RIGHT", 5, 11)
        info.nameText:SetJustifyH("LEFT")
        info.nameText:SetWidth(180)
        
        info.levelText = slotButton:CreateFontString(nil, "OVERLAY")
        info.levelText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        info.levelText:SetPoint("LEFT", slotButton, "RIGHT", 5, 0)
        info.levelText:SetJustifyH("LEFT")
        info.levelText:SetWidth(180)
        info.levelText:SetTextColor(1, 0.82, 0, 1)
        
        info.enchantText = slotButton:CreateFontString(nil, "OVERLAY")
        info.enchantText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        info.enchantText:SetPoint("LEFT", slotButton, "RIGHT", 5, -11)
        info.enchantText:SetJustifyH("LEFT")
        info.enchantText:SetWidth(180)
        
        -- Gems on the left of icon
        info.gems = {}
        for i = 1, 3 do
            local gem = slotButton:CreateTexture(nil, "OVERLAY")
            gem:SetSize(12, 12)
            gem:SetPoint("RIGHT", slotButton, "LEFT", -3, 12 - (i-1) * 15)
            gem:Hide()
            info.gems[i] = gem
        end
    else
        -- Right side: text goes to the LEFT of icon
        info.nameText = slotButton:CreateFontString(nil, "OVERLAY")
        info.nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        info.nameText:SetPoint("RIGHT", slotButton, "LEFT", -5, 11)
        info.nameText:SetJustifyH("RIGHT")
        info.nameText:SetWidth(180)
        
        info.levelText = slotButton:CreateFontString(nil, "OVERLAY")
        info.levelText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        info.levelText:SetPoint("RIGHT", slotButton, "LEFT", -5, 0)
        info.levelText:SetJustifyH("RIGHT")
        info.levelText:SetWidth(180)
        info.levelText:SetTextColor(1, 0.82, 0, 1)
        
        info.enchantText = slotButton:CreateFontString(nil, "OVERLAY")
        info.enchantText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        info.enchantText:SetPoint("RIGHT", slotButton, "LEFT", -5, -11)
        info.enchantText:SetJustifyH("RIGHT")
        info.enchantText:SetWidth(180)
        
        -- Gems on the right of icon
        info.gems = {}
        for i = 1, 3 do
            local gem = slotButton:CreateTexture(nil, "OVERLAY")
            gem:SetSize(12, 12)
            gem:SetPoint("LEFT", slotButton, "RIGHT", 3, 12 - (i-1) * 15)
            gem:Hide()
            info.gems[i] = gem
        end
    end
    
    equipmentInfo[slotName] = info
    slotButton._infoCreated = true
end

local function UpdateEquipmentInfo(slotButton, slotID)
    local slotName = slotButton:GetName()
    local info = equipmentInfo[slotName]
    if not info then return end
    
    local itemLink = GetInventoryItemLink("player", slotID)
    
    if not itemLink then
        -- No item equipped
        info.nameText:SetText("")
        info.levelText:SetText("")
        info.enchantText:SetText("")
        for i = 1, 3 do
            info.gems[i]:Hide()
        end
        return
    end
    
    -- Get item info
    local itemName, _, itemQuality, itemLevel = C_Item.GetItemInfo(itemLink)
    
    -- Set item name with quality color
    if itemName and itemQuality then
        local r, g, b = C_Item.GetItemQualityColor(itemQuality)
        -- Truncate to 20 characters
        if #itemName > 20 then
            itemName = itemName:sub(1, 20) .. "..."
        end
        info.nameText:SetText(itemName)
        info.nameText:SetTextColor(r, g, b, 1)
    end
    
    -- Get current item level using ItemLocation
    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
    local levelText = ""
    
    if itemLocation and itemLocation:IsValid() then
        local actualItemLevel = C_Item.GetCurrentItemLevel(itemLocation)
        
        if actualItemLevel and actualItemLevel > 0 then
            levelText = tostring(actualItemLevel)
        elseif itemLevel then
            levelText = tostring(itemLevel)
        end
        
        -- Try to get detailed item level info with upgrade track
        local detailedLevel, _, baseLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
        if detailedLevel and baseLevel then
            -- Check if item has upgrade information
            local itemString = string.match(itemLink, "item[%-?%d:]+")
            if itemString then
                -- Try to determine upgrade track from item
                -- Look for upgrade level in the item (this is a simplified approach)
                local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)
                if tooltipData and tooltipData.lines then
                    for _, line in ipairs(tooltipData.lines) do
                        if line.leftText then
                            local text = line.leftText
                            -- Look for patterns like "Champion 1/6", "Hero 4/6", etc.
                            -- The pattern is usually: TrackName Number/Number
                            local track, curr, maxUp = text:match("^(.-)%s+(%d+)/(%d+)$")
                            if track and curr and maxUp and tonumber(maxUp) > 0 then
                                -- Strip "Upgrade Level: " prefix if present
                                track = track:gsub("^Upgrade Level:%s*", "")
                                levelText = levelText .. " (" .. track .. " " .. curr .. "/" .. maxUp .. ")"
                                break
                            end
                        end
                    end
                end
            end
        end
    elseif itemLevel then
        levelText = tostring(itemLevel)
    end
    
    info.levelText:SetText(levelText)
    
    -- Check for enchant
    local enchantText = ""
    local hasEnchant = false
    
    -- Try to detect enchant via tooltip scan
    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)
    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            if line.leftText then
                local text = line.leftText
                -- Common enchant indicators
                if text:find("Enchanted:") or text:find("Enchant ") then
                    hasEnchant = true
                    enchantText = text:gsub("Enchanted: ", "")
                    -- Remove "Enchant [SLOT] - " prefix patterns
                    enchantText = enchantText:gsub("^Enchant %w+ %- ", "")
                    break
                end
            end
        end
    end
    
    -- Check if slot can be enchanted (weapons, rings, neck, back, chest, wrist, feet, legs)
    local enchantableSlots = {
        [1] = false, -- head
        [2] = true,  -- neck
        [3] = false, -- shoulder
        [5] = true,  -- chest
        [6] = false, -- waist
        [7] = true,  -- legs
        [8] = true,  -- feet
        [9] = true,  -- wrist
        [11] = true, -- finger
        [12] = true, -- finger
        [15] = true, -- back
        [16] = true, -- main hand
        [17] = true, -- off hand
    }
    
    if enchantableSlots[slotID] then
        if hasEnchant then
            info.enchantText:SetText(enchantText)
            info.enchantText:SetTextColor(0, 1, 0, 1) -- Green
        else
            info.enchantText:SetText("No Enchant")
            info.enchantText:SetTextColor(1, 0, 0, 1) -- Red
        end
    else
        info.enchantText:SetText("")
    end
    
    -- Get gem info
    -- Try to get socket information by checking each potential socket
    for i = 1, 3 do
        local gemName, gemLink = GetItemGem(itemLink, i)
        if gemLink then
            -- Socket is filled with a gem
            local gemItemID = tonumber(string.match(gemLink, "item:(%d+)"))
            if gemItemID then
                local gemTexture = C_Item.GetItemIconByID(gemItemID)
                if gemTexture then
                    info.gems[i]:SetTexture(gemTexture)
                    info.gems[i]:Show()
                else
                    info.gems[i]:Hide()
                end
            else
                info.gems[i]:Hide()
            end
        else
            info.gems[i]:Hide()
        end
    end
end

local function RepositionEquipmentSlots()
    if not PaperDollItemsFrame then return end
    
    local spacing = 41  -- Vertical spacing between items
    
    -- Position anchor slots first
    local headSlot = _G["CharacterHeadSlot"]
    local handsSlot = _G["CharacterHandsSlot"]
    
    if headSlot and not headSlot._abstractRepositioned then
        headSlot:ClearAllPoints()
        headSlot:SetPoint("TOPLEFT", PaperDollItemsFrame, "TOPLEFT", 20, -40)
        headSlot._abstractRepositioned = true
        CreateEquipmentInfo(headSlot, "CharacterHeadSlot", "left")
    end
    
    if handsSlot and not handsSlot._abstractRepositioned then
        handsSlot:ClearAllPoints()
        handsSlot:SetPoint("TOPLEFT", PaperDollItemsFrame, "TOPLEFT", 330, -40)
        handsSlot._abstractRepositioned = true
        CreateEquipmentInfo(handsSlot, "CharacterHandsSlot", "right")
    end
    
    -- Left column (relative to Head)
    local leftSlots = {
        { name = "CharacterNeckSlot", offset = 1 },
        { name = "CharacterShoulderSlot", offset = 2 },
        { name = "CharacterBackSlot", offset = 3 },
        { name = "CharacterChestSlot", offset = 4 },
        { name = "CharacterShirtSlot", offset = 5 },
        { name = "CharacterTabardSlot", offset = 6 },
        { name = "CharacterWristSlot", offset = 7 },
    }
    
    for _, data in ipairs(leftSlots) do
        local slot = _G[data.name]
        if slot and headSlot and not slot._abstractRepositioned then
            slot:ClearAllPoints()
            slot:SetPoint("TOP", headSlot, "TOP", 0, -spacing * data.offset)
            slot._abstractRepositioned = true
            CreateEquipmentInfo(slot, data.name, "left")
        end
    end
    
    -- Right column (relative to Hands)
    local rightSlots = {
        { name = "CharacterWaistSlot", offset = 1 },
        { name = "CharacterLegsSlot", offset = 2 },
        { name = "CharacterFeetSlot", offset = 3 },
        { name = "CharacterFinger0Slot", offset = 4 },
        { name = "CharacterFinger1Slot", offset = 5 },
        { name = "CharacterTrinket0Slot", offset = 6 },
        { name = "CharacterTrinket1Slot", offset = 7 },
    }
    
    for _, data in ipairs(rightSlots) do
        local slot = _G[data.name]
        if slot and handsSlot and not slot._abstractRepositioned then
            slot:ClearAllPoints()
            slot:SetPoint("TOP", handsSlot, "TOP", 0, -spacing * data.offset)
            slot._abstractRepositioned = true
            CreateEquipmentInfo(slot, data.name, "right")
        end
    end
    
    -- Weapon slots (bottom, positioned relative to frame)
    local mainHandSlot = _G["CharacterMainHandSlot"]
    local offHandSlot = _G["CharacterSecondaryHandSlot"]
    
    if mainHandSlot and not mainHandSlot._abstractRepositioned then
        mainHandSlot:ClearAllPoints()
        mainHandSlot:SetPoint("TOPLEFT", PaperDollItemsFrame, "TOPLEFT", 120, -370)
        mainHandSlot._abstractRepositioned = true
        CreateEquipmentInfo(mainHandSlot, "CharacterMainHandSlot", "right")  -- Text goes left
    end
    
    if offHandSlot and not offHandSlot._abstractRepositioned then
        offHandSlot:ClearAllPoints()
        offHandSlot:SetPoint("TOPLEFT", PaperDollItemsFrame, "TOPLEFT", 180, -370)
        offHandSlot._abstractRepositioned = true
        CreateEquipmentInfo(offHandSlot, "CharacterSecondaryHandSlot", "left")  -- Text goes right
    end
    
    -- Update all slot info
    for slotName, _ in pairs(equipmentInfo) do
        local slot = _G[slotName]
        if slot then
            local slotID = slot:GetID()
            if slotID then
                -- Initial update
                UpdateEquipmentInfo(slot, slotID)
                
                -- Hook to update when items change
                if not slot._eventHooked then
                    slot:HookScript("OnEvent", function(self, event)
                        if event == "PLAYER_EQUIPMENT_CHANGED" then
                            UpdateEquipmentInfo(self, slotID)
                        end
                    end)
                    
                    -- Register for equipment changes if not already registered
                    if not slot:IsEventRegistered("PLAYER_EQUIPMENT_CHANGED") then
                        slot:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
                    end
                    slot._eventHooked = true
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- SKIN EQUIPMENT SLOT BUTTONS
---------------------------------------------------------------------------

local function SkinItemSlot(button)
    if not button or button._abstractSkinned then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Hide Blizzard's background frame aggressively
    local frameName = button:GetName() .. "Frame"
    local frame = _G[frameName]
    if frame then
        frame:Hide()
        frame:SetAlpha(0)
        
        -- Also hide all its regions if it's a frame
        if frame.GetNumRegions then
            for i = 1, frame:GetNumRegions() do
                local region = select(i, frame:GetRegions())
                if region then
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        end
    end
    
    -- Store references to unnamed children and hide them once
    local children = {button:GetChildren()}
    
    for i, child in ipairs(children) do
        local childName = child:GetName()
        -- Hide unnamed children (these are the decorative bars)
        if not childName or childName == "" then
            -- One-time hiding
            child:Hide()
            child:SetAlpha(0)
            
            -- Hook Show() to prevent re-showing (only triggers when Show() is called)
            if not child._abstractHidden then
                hooksecurefunc(child, "Show", function(self)
                    self:Hide()
                end)
                child._abstractHidden = true
            end
            
            -- Hide all regions once
            if child.GetNumRegions then
                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                    end
                end
            end
        end
    end
    
    -- Remove default textures
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    
    -- Create backdrop frame (equipment slots don't have BackdropTemplate)
    if not button.backdrop then
        local backdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        backdrop:SetAllPoints()
        backdrop:SetFrameLevel(button:GetFrameLevel() - 1)
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        backdrop:SetBackdropColor(bgr, bgg, bgb, 0.3)
        backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
        button.backdrop = backdrop
    end
    
    -- Style icon
    if button.icon then
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    
    -- Style IconBorder (quality border)
    if button.IconBorder then
        button.IconBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.IconBorder:ClearAllPoints()
        button.IconBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.IconBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.IconBorder:SetDrawLayer("OVERLAY", 0)
        
        -- Hook to update border color based on quality
        hooksecurefunc(button.IconBorder, "SetVertexColor", function(self, r, g, b)
            if button.backdrop and r and g and b and (r > 0.1 or g > 0.1 or b > 0.1) then
                button.backdrop:SetBackdropBorderColor(r, g, b, 0.8)
            elseif button.backdrop then
                button.backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
            end
        end)
    end
    
    -- Create highlight texture
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.1)
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    
    button._abstractSkinned = true
end

local function SkinAllEquipmentSlots()
    -- Equipment slots (sides)
    local slots = {
        "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
        "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
        "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
        "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    }
    
    for _, slotName in ipairs(slots) do
        local slot = _G[slotName]
        if slot then
            SkinItemSlot(slot)
        end
    end
    
    -- Weapon slots (bottom)
    local weaponSlots = {
        "CharacterMainHandSlot",
        "CharacterSecondaryHandSlot",
    }
    
    for _, slotName in ipairs(weaponSlots) do
        local slot = _G[slotName]
        if slot then
            SkinItemSlot(slot)
        end
    end
end

---------------------------------------------------------------------------
-- STATS OVERLAY VISIBILITY MANAGEMENT
---------------------------------------------------------------------------

-- Declare statsOverlay at module level so all functions can access it
local statsOverlay = nil
local titlesOverlay = nil

-- Track which sidebar tab is currently selected (1=Stats, 2=Titles, 3=EquipmentManager)
local selectedSidebarTab = 1  -- Default to Stats tab

-- Forward declare functions
local UpdateStatsOverlayVisibility
local UpdateTitlesOverlay

-- Function to update stats overlay visibility based on selected tab
UpdateStatsOverlayVisibility = function()
    if not statsOverlay then return end
    
    -- Show stats overlay only when Stats tab (1) is selected
    if selectedSidebarTab == 1 then
        statsOverlay:Show()
    else
        statsOverlay:Hide()
    end
    
    -- Show titles overlay only when Titles tab (2) is selected
    if titlesOverlay then
        if selectedSidebarTab == 2 then
            titlesOverlay:Show()
        else
            titlesOverlay:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- SKIN TABS
---------------------------------------------------------------------------

local function SkinCharacterTabs()
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Bottom tabs (Character, Reputation, Currency)
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab and not tab._abstractSkinned then
            -- Aggressively remove ALL default textures
            tab:SetNormalTexture("")
            tab:SetPushedTexture("")
            tab:SetDisabledTexture("")
            
            -- Hide ALL texture regions from the tab
            for j = 1, tab:GetNumRegions() do
                local region = select(j, tab:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    region:SetTexture("")
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
            
            -- Create backdrop frame
            if not tab.backdrop then
                local backdrop = CreateFrame("Frame", nil, tab, "BackdropTemplate")
                backdrop:SetAllPoints()
                backdrop:SetFrameLevel(tab:GetFrameLevel() - 1)
                backdrop:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                backdrop:SetBackdropColor(bgr, bgg, bgb, 0.6)
                backdrop:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
                tab.backdrop = backdrop
            end
            
            -- Style text
            local text = tab:GetFontString()
            if text then
                text:SetTextColor(pr, pg, pb, 1)
                text:SetShadowOffset(1, -1)
                text:SetShadowColor(0, 0, 0, 1)
            end
            
            -- Highlight
            local highlight = tab:GetHighlightTexture()
            if highlight then
                highlight:SetColorTexture(pr, pg, pb, 0.2)
                highlight:ClearAllPoints()
                highlight:SetPoint("TOPLEFT", 1, -1)
                highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            end
            
            -- Selected state - update on click
            tab:HookScript("OnClick", function(self)
                for j = 1, 3 do
                    local t = _G["CharacterFrameTab" .. j]
                    if t and t.backdrop then
                        local text = t:GetFontString()
                        if j == i then
                            -- Selected tab
                            t.backdrop:SetBackdropColor(bgr * 1.5, bgg * 1.5, bgb * 1.5, 0.9)
                            t.backdrop:SetBackdropBorderColor(pr, pg, pb, 1)
                            if text then
                                text:SetTextColor(1, 1, 1, 1)
                            end
                        else
                            -- Unselected tabs
                            t.backdrop:SetBackdropColor(bgr, bgg, bgb, 0.6)
                            t.backdrop:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
                            if text then
                                text:SetTextColor(pr * 0.8, pg * 0.8, pb * 0.8, 1)
                            end
                        end
                    end
                end
            end)
            
            -- Set initial selected state
            if PanelTemplates_GetSelectedTab(CharacterFrame) == i then
                tab.backdrop:SetBackdropColor(bgr * 1.5, bgg * 1.5, bgb * 1.5, 0.9)
                tab.backdrop:SetBackdropBorderColor(pr, pg, pb, 1)
                local text = tab:GetFontString()
                if text then
                    text:SetTextColor(1, 1, 1, 1)
                end
            end
            
            tab._abstractSkinned = true
        end
    end
    
    -- Sidebar tabs (right side)
    if PaperDollSidebarTabs then
        -- Make sure the tab container is visible
        PaperDollSidebarTabs:Show()
        PaperDollSidebarTabs:SetAlpha(1)
        
        -- Try to skin up to 3 sidebar tabs (Stats, Titles, Gear Sets)
        local numTabs = PAPERDOLL_SIDEBARS and #PAPERDOLL_SIDEBARS or 3
        for i = 1, numTabs do
            local tab = _G["PaperDollSidebarTab" .. i]
            if tab then
                -- Make sure the tab itself is visible
                tab:Show()
                tab:SetAlpha(1)
                
                if not tab._abstractSkinned then
                    -- Hide default textures but not completely
                    if tab.TabBg then
                        tab.TabBg:SetAlpha(0)
                        tab.TabBg:Hide()
                    end
                    if tab.Hider then
                        tab.Hider:SetTexture("")
                        tab.Hider:Hide()
                    end
                    
                    -- Create backdrop frame offset 15px to the right within the tab
                    if not tab.backdrop then
                        local backdrop = CreateFrame("Frame", nil, tab, "BackdropTemplate")
                        backdrop:SetFrameLevel(tab:GetFrameLevel() - 1)
                        backdrop:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8x8",
                            edgeFile = "Interface\\Buttons\\WHITE8x8",
                            edgeSize = 1,
                        })
                        backdrop:SetBackdropColor(bgr, bgg, bgb, 0.4)
                        backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
                        backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", 15, 0)
                        backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 15, 0)
                        tab.backdrop = backdrop
                    end
                    
                    -- Style icon - move 15px to the right
                    if tab.Icon then
                        tab.Icon:Show()
                        tab.Icon:SetAlpha(1)
                        tab.Icon:SetDrawLayer("ARTWORK")
                        tab.Icon:ClearAllPoints()
                        tab.Icon:SetPoint("CENTER", tab, "CENTER", 15, 0)
                    end
                    
                    -- Highlight - offset 15px to the right
                    if tab.Highlight then
                        tab.Highlight:SetColorTexture(pr, pg, pb, 0.2)
                        tab.Highlight:SetDrawLayer("HIGHLIGHT")
                        tab.Highlight:ClearAllPoints()
                        tab.Highlight:SetPoint("TOPLEFT", tab, "TOPLEFT", 15, 0)
                        tab.Highlight:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 15, 0)
                    end
                    
                    -- Extend the tab's hit area 15px to the right to include the visual offset
                    tab:SetHitRectInsets(0, -15, 0, 0)
                    
                    tab._abstractSkinned = true
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- SKIN CHARACTER FRAME BACKDROP
---------------------------------------------------------------------------

local function SkinCharacterFrameBackdrop()
    if not CharacterFrame or not CharacterFrame.NineSlice then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Create custom backdrop with class-colored border and background
    if not CharacterFrame.AbstractBackdrop then
        local backdrop = CreateFrame("Frame", nil, CharacterFrame, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        backdrop:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
        backdrop:SetFrameLevel(CharacterFrame:GetFrameLevel() - 1)
        
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        
        -- Background with transparency
        backdrop:SetBackdropColor(bgr, bgg, bgb, 0.85)
        
        -- Class-colored border
        backdrop:SetBackdropBorderColor(pr, pg, pb, 1)
        
        CharacterFrame.AbstractBackdrop = backdrop
    end
    
    -- Make NineSlice completely transparent so game world shows through
    if CharacterFrame.NineSlice.Center then
        CharacterFrame.NineSlice.Center:SetAlpha(0)
        CharacterFrame.NineSlice.Center:Hide()
    end
    
    -- Hide the portrait completely
    if CharacterFramePortrait then
        CharacterFramePortrait:SetAlpha(0)
    end
    
    -- Hide Blizzard's close button and create our own
    if CharacterFrame.CloseButton then
        CharacterFrame.CloseButton:Hide()
        CharacterFrame.CloseButton:SetAlpha(0)
    end
    
    -- Create custom themed close button
    if not CharacterFrame.AbstractCloseButton then
        local closeBtn = CreateFrame("Button", nil, CharacterFrame, "BackdropTemplate")
        closeBtn:SetSize(18, 18)
        closeBtn:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -8, -8)
        
        -- Backdrop
        closeBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        closeBtn:SetBackdropColor(bgr, bgg, bgb, 0.5)
        closeBtn:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
        
        -- X text
        local xText = closeBtn:CreateFontString(nil, "OVERLAY")
        xText:SetPoint("CENTER", 0, 0)
        xText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        xText:SetText("X")
        xText:SetTextColor(pr, pg, pb, 1)
        
        -- Hover effect
        closeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(pr * 0.8, pg * 0.8, pb * 0.8, 0.8)
            xText:SetTextColor(1, 1, 1, 1)
        end)
        
        closeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bgr, bgg, bgb, 0.5)
            xText:SetTextColor(pr, pg, pb, 1)
        end)
        
        -- Click to close
        closeBtn:SetScript("OnClick", function()
            HideUIPanel(CharacterFrame)
        end)
        
        CharacterFrame.AbstractCloseButton = closeBtn
    end
    
    -- Hide Blizzard's level text (we'll create our own)
    if CharacterLevelText then
        CharacterLevelText:Hide()
        CharacterLevelText:SetAlpha(0)
    end
    
    -- Create custom titlebar layout: Name | Item Level | Level/Spec/Class
    if not CharacterFrame.AbstractTitleBar then
        local titleFrame = CreateFrame("Frame", nil, CharacterFrame)
        titleFrame:SetPoint("TOP", CharacterFrame, "TOP", 0, -10)
        titleFrame:SetSize(640, 20)
        
        -- Character Name (left-aligned but more centered)
        local nameText = titleFrame:CreateFontString(nil, "OVERLAY")
        nameText:SetPoint("LEFT", titleFrame, "LEFT", 80, 0)
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        nameText:SetTextColor(pr, pg, pb, 1)
        nameText:SetShadowOffset(1, -1)
        nameText:SetShadowColor(0, 0, 0, 1)
        titleFrame.nameText = nameText
        
        -- Item Level (after name)
        local ilvlText = titleFrame:CreateFontString(nil, "OVERLAY")
        ilvlText:SetPoint("LEFT", nameText, "RIGHT", 20, 0)
        ilvlText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        ilvlText:SetTextColor(0.9, 0.9, 0.9, 1)
        ilvlText:SetShadowOffset(1, -1)
        ilvlText:SetShadowColor(0, 0, 0, 1)
        titleFrame.ilvlText = ilvlText
        
        -- Level/Spec/Class (after ilvl)
        local infoText = titleFrame:CreateFontString(nil, "OVERLAY")
        infoText:SetPoint("LEFT", ilvlText, "RIGHT", 20, 0)
        infoText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        infoText:SetTextColor(0.9, 0.9, 0.9, 1)
        infoText:SetShadowOffset(1, -1)
        infoText:SetShadowColor(0, 0, 0, 1)
        titleFrame.infoText = infoText
        
        -- Update function
        titleFrame.Update = function(self)
            -- Check which tab is active
            local selectedTab = PanelTemplates_GetSelectedTab(CharacterFrame) or 1
            
            -- Get character info
            local name = UnitName("player")
            local level = UnitLevel("player")
            local specIndex = GetSpecialization()
            local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "No Spec"
            local className = UnitClass("player")
            local infoString = string.format("Level %d %s %s", level, specName, className)
            
            -- Tab 1 is Character (main equipment view)
            -- Other tabs (Reputation, Currency, etc.) just show the character info
            if selectedTab == 1 then
                -- Show all three sections
                self.nameText:Show()
                self.ilvlText:Show()
                self.infoText:Show()
                
                self.nameText:SetText(name or "")
                
                local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
                self.ilvlText:SetText(string.format("Item Level |cff%02x%02x%02x%.1f|r", pr*255, pg*255, pb*255, avgItemLevelEquipped))
                
                -- Reset infoText position to normal (after ilvl)
                self.infoText:ClearAllPoints()
                self.infoText:SetPoint("LEFT", self.ilvlText, "RIGHT", 20, 0)
                self.infoText:SetText(infoString)
            else
                -- Hide name and item level, show only character info centered
                self.nameText:Hide()
                self.ilvlText:Hide()
                self.infoText:Show()
                
                -- Center the info text
                self.infoText:ClearAllPoints()
                self.infoText:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
                self.infoText:SetText(infoString)
            end
        end
        
        -- Initial update
        titleFrame:Update()
        
        -- Update on events
        titleFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        titleFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
        titleFrame:RegisterEvent("PLAYER_LEVEL_UP")
        titleFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        titleFrame:SetScript("OnEvent", function(self)
            self:Update()
        end)
        
        -- Hook each tab button to update title when clicked
        for i = 1, 4 do
            local tab = _G["CharacterFrameTab" .. i]
            if tab then
                tab:HookScript("OnClick", function()
                    C_Timer.After(0, function()
                        if CharacterFrame.AbstractTitleBar then
                            CharacterFrame.AbstractTitleBar:Update()
                        end
                    end)
                end)
            end
        end
        
        CharacterFrame.AbstractTitleBar = titleFrame
    end
    
    -- Style title text (hide Blizzard's default title)
    if CharacterFrame.TitleContainer and CharacterFrame.TitleContainer.TitleText then
        local title = CharacterFrame.TitleContainer.TitleText
        title:Hide()
        title:SetAlpha(0)
    end
end

---------------------------------------------------------------------------
-- SKIN STATS PANE
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- CUSTOM STATS PANEL
---------------------------------------------------------------------------

local function FormatStatValue(value)
    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    else
        return tostring(math.floor(value))
    end
end

local function CreateStatsOverlay()
    if not CharacterFrameInsetRight then return end
    
    -- Hide all Blizzard stats UI
    if CharacterStatsPane then
        CharacterStatsPane:Hide()
        CharacterStatsPane:SetAlpha(0)
    end
    
    -- Create our custom overlay frame
    if not statsOverlay then
        statsOverlay = CreateFrame("Frame", "AbstractUI_StatsOverlay", CharacterFrameInsetRight)
        -- Position right below the sidebar tabs
        statsOverlay:SetPoint("TOPRIGHT", CharacterFrameInsetRight, "TOPRIGHT", -10, -12)
        statsOverlay:SetWidth(140)
        statsOverlay:SetHeight(500)
        
        -- Storage for all text elements
        statsOverlay.texts = {}
        
        local function CreateText(name, isHeader)
            local text = statsOverlay:CreateFontString(nil, "OVERLAY")
            text:SetFont("Fonts\\FRIZQT__.TTF", isHeader and 13 or 12, "OUTLINE")
            text:SetJustifyH("LEFT")
            text:SetWidth(70)
            return text
        end
        
        local function CreateStatLine(label, valueKey, yOffset)
            local labelText = CreateText(label .. "Label", false)
            labelText:SetPoint("TOPLEFT", statsOverlay, "TOPLEFT", 0, yOffset)
            labelText:SetText(label)
            labelText:SetTextColor(1, 1, 1, 1)
            
            local valueText = CreateText(label .. "Value", false)
            valueText:SetPoint("TOPRIGHT", statsOverlay, "TOPRIGHT", 0, yOffset)
            valueText:SetJustifyH("RIGHT")
            valueText:SetWidth(70)
            valueText:SetTextColor(1, 1, 1, 1)
            
            statsOverlay.texts[valueKey] = { label = labelText, value = valueText }
            return yOffset - 16
        end
        
        local function CreateHeader(text, yOffset)
            local header = CreateText(text .. "Header", true)
            header:SetPoint("TOPLEFT", statsOverlay, "TOPLEFT", 0, yOffset)
            local pr, pg, pb = GetThemeColors()
            header:SetTextColor(pr, pg, pb, 1)
            header:SetText(text)
            return yOffset - 18
        end
        
        -- Build the stats layout
        local y = 0
        
        -- Health and Power
        y = CreateStatLine("Health", "health", y)
        y = CreateStatLine("Power", "power", y)
        
        -- Primary section
        y = y - 5
        y = CreateHeader("Primary", y)
        y = CreateStatLine("Strength", "strength", y)
        y = CreateStatLine("Agility", "agility", y)
        y = CreateStatLine("Stamina", "stamina", y)
        y = CreateStatLine("Intellect", "intellect", y)
        
        -- Secondary section
        y = y - 5
        y = CreateHeader("Secondary", y)
        y = CreateStatLine("Crit", "crit", y)
        y = CreateStatLine("Haste", "haste", y)
        y = CreateStatLine("Mastery", "mastery", y)
        y = CreateStatLine("Versatility", "versatility", y)
        
        -- Defense section
        y = y - 5
        y = CreateHeader("Defense", y)
        y = CreateStatLine("Armor", "armor", y)
        y = CreateStatLine("Dodge", "dodge", y)
        y = CreateStatLine("Parry", "parry", y)
        y = CreateStatLine("Block", "block", y)
        
        -- Utility section
        y = y - 5
        y = CreateHeader("Utility", y)
        y = CreateStatLine("Leech", "leech", y)
        y = CreateStatLine("Speed", "speed", y)
    end
    
    -- Set initial visibility based on selected tab
    UpdateStatsOverlayVisibility()
end

local function UpdateStatsOverlay()
    if not statsOverlay or not statsOverlay.texts then return end
    
    local texts = statsOverlay.texts
    
    -- Health
    local health = UnitHealthMax("player")
    if texts.health then texts.health.value:SetText(FormatStatValue(health)) end
    
    -- Power (mana/energy/rage/etc)
    local powerType = UnitPowerType("player")
    local power = UnitPowerMax("player", powerType)
    if texts.power then 
        local _, powerToken = UnitPowerType("player")
        local powerColor = PowerBarColor[powerToken] or PowerBarColor["MANA"]
        texts.power.label:SetTextColor(powerColor.r, powerColor.g, powerColor.b, 1)
        texts.power.value:SetText(FormatStatValue(power))
        texts.power.value:SetTextColor(powerColor.r, powerColor.g, powerColor.b, 1)
    end
    
    -- Attributes
    local str = UnitStat("player", 1)
    local agi = UnitStat("player", 2)
    local sta = UnitStat("player", 3)
    local int = UnitStat("player", 4)
    if texts.strength then texts.strength.value:SetText(FormatStatValue(str)) end
    if texts.agility then texts.agility.value:SetText(FormatStatValue(agi)) end
    if texts.stamina then texts.stamina.value:SetText(FormatStatValue(sta)) end
    if texts.intellect then texts.intellect.value:SetText(FormatStatValue(int)) end
    
    -- Secondary stats
    local crit = GetCritChance()
    local critRating = GetCombatRating(CR_CRIT_MELEE)
    if texts.crit then 
        texts.crit.value:SetText(string.format("%s (%.1f%%)", FormatStatValue(critRating), crit))
    end
    
    local hasteRating = GetCombatRating(CR_HASTE_MELEE)
    local hastePercent = GetHaste()
    if texts.haste then 
        texts.haste.value:SetText(string.format("%s (%.1f%%)", FormatStatValue(hasteRating), hastePercent))
    end
    
    local masteryRating = GetCombatRating(CR_MASTERY)
    local masteryPercent = GetMasteryEffect()
    if texts.mastery then 
        texts.mastery.value:SetText(string.format("%s (%.1f%%)", FormatStatValue(masteryRating), masteryPercent))
    end
    
    local versRating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
    local versPercent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    if texts.versatility then 
        texts.versatility.value:SetText(string.format("%s (%.1f%%)", FormatStatValue(versRating), versPercent))
    end
    
    -- Defense
    local baseArmor, effectiveArmor, armor, posBuff, negBuff = UnitArmor("player")
    if texts.armor then texts.armor.value:SetText(FormatStatValue(effectiveArmor)) end
    
    local dodge = GetDodgeChance()
    if texts.dodge then texts.dodge.value:SetText(string.format("%.2f%%", dodge)) end
    
    local parry = GetParryChance()
    if texts.parry then texts.parry.value:SetText(string.format("%.2f%%", parry)) end
    
    local block = GetBlockChance()
    if texts.block then texts.block.value:SetText(string.format("%.2f%%", block)) end
    
    -- Utility
    local leechRating = GetCombatRating(CR_LIFESTEAL)
    local leechPercent = GetCombatRatingBonus(CR_LIFESTEAL)
    if texts.leech then 
        texts.leech.value:SetText(string.format("%.2f%%", leechPercent))
    end
    
    local speedRating = GetCombatRating(CR_SPEED)
    local speedPercent = GetCombatRatingBonus(CR_SPEED)
    if texts.speed then 
        texts.speed.value:SetText(string.format("%.2f%%", speedPercent))
    end
end

local function SkinStatsPane()
    if not CharacterStatsPane then return end
    
    -- Hide Blizzard's stats pane completely
    CharacterStatsPane:Hide()
    CharacterStatsPane:SetAlpha(0)
    
    -- Create and show our custom overlay
    CreateStatsOverlay()
    UpdateStatsOverlay()
    
    -- Now that statsOverlay exists, set up tab click hooks
    local numTabs = PAPERDOLL_SIDEBARS and #PAPERDOLL_SIDEBARS or 3
    for i = 1, numTabs do
        local tab = _G["PaperDollSidebarTab" .. i]
        if tab and not tab._abstractStatsHooked then
            local tabNumber = i  -- Capture for closure
            tab:HookScript("OnClick", function(self)
                selectedSidebarTab = tabNumber
                UpdateStatsOverlayVisibility()
                
                -- Refresh titles list when Titles tab is clicked
                if tabNumber == 2 and titlesOverlay then
                    UpdateTitlesOverlay()
                end
            end)
            tab._abstractStatsHooked = true
        end
    end
    
    -- Update when character frame is shown
    if not CharacterFrame._statsUpdateHooked then
        CharacterFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, function()
                UpdateStatsOverlay()
                UpdateStatsOverlayVisibility()
            end)
        end)
        CharacterFrame._statsUpdateHooked = true
    end
end

---------------------------------------------------------------------------
-- CUSTOM TITLES PANEL
---------------------------------------------------------------------------

local function CreateTitlesOverlay()
    if not CharacterFrameInsetRight then return end
    
    -- Hide Blizzard's titles scroll frame - try multiple possible names
    local blizzTitles = PaperDollFrame and PaperDollFrame.TitlesPane
    if blizzTitles then
        blizzTitles:Hide()
        blizzTitles:SetAlpha(0)
    end
    
    -- Also try global frame names
    if _G["PaperDollTitlesPane"] then
        _G["PaperDollTitlesPane"]:Hide()
        _G["PaperDollTitlesPane"]:SetAlpha(0)
    end
    
    if _G["CharacterFrameTitlePane"] then
        _G["CharacterFrameTitlePane"]:Hide()
        _G["CharacterFrameTitlePane"]:SetAlpha(0)
    end
    
    -- Create our custom titles overlay frame
    if not titlesOverlay then
        titlesOverlay = CreateFrame("ScrollFrame", "AbstractUI_TitlesOverlay", CharacterFrameInsetRight, "UIPanelScrollFrameTemplate")
        titlesOverlay:SetPoint("TOPLEFT", CharacterFrameInsetRight, "TOPLEFT", 8, -12)
        titlesOverlay:SetPoint("BOTTOMRIGHT", CharacterFrameInsetRight, "BOTTOMRIGHT", -30, 8)
        titlesOverlay:SetWidth(200)  -- Narrower width to avoid equipment slots
        
        -- Create scroll child
        local scrollChild = CreateFrame("Frame", nil, titlesOverlay)
        scrollChild:SetWidth(180)
        scrollChild:SetHeight(1)  -- Will be set dynamically
        titlesOverlay:SetScrollChild(scrollChild)
        titlesOverlay.scrollChild = scrollChild
        
        -- Storage for title buttons
        titlesOverlay.buttons = {}
    end
    
    -- Set initial visibility
    if selectedSidebarTab == 2 then
        titlesOverlay:Show()
    else
        titlesOverlay:Hide()
    end
end

UpdateTitlesOverlay = function()
    if not titlesOverlay or not titlesOverlay.scrollChild then return end
    
    local scrollChild = titlesOverlay.scrollChild
    local buttons = titlesOverlay.buttons
    
    -- Get player titles
    local titles = {}
    local numTitles = GetNumTitles()
    local currentTitle = GetCurrentTitle()
    
    -- Add "No Title" option
    table.insert(titles, { id = -1, name = "No Title", isCurrent = (currentTitle == -1 or currentTitle == 0) })
    
   -- Add all available titles
    for i = 1, numTitles do
        local name = GetTitleName(i)
        if name then
            -- Truncate to 20 characters
            if string.len(name) > 20 then
                name = string.sub(name, 1, 17) .. "..."
            end
            table.insert(titles, { id = i, name = name, isCurrent = (currentTitle == i) })
        end
    end
    
    -- Create/update buttons
    local yOffset = 0
    for i, titleData in ipairs(titles) do
        local button = buttons[i]
        if not button then
            button = CreateFrame("Button", nil, scrollChild)
            button:SetSize(180, 20)
            button:SetNormalFontObject("GameFontNormalSmall")
            button:SetHighlightFontObject("GameFontHighlightSmall")
            
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", button, "LEFT", 5, 0)
            text:SetJustifyH("LEFT")
            text:SetWidth(170)
            button.text = text
            
            -- Highlight texture
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)
            
            buttons[i] = button
        end
        
        button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        button.text:SetText(titleData.name)
        
        -- Highlight current title
        if titleData.isCurrent then
            button.text:SetTextColor(1, 0.82, 0)  -- Gold
        else
            button.text:SetTextColor(1, 1, 1)  -- White
        end
        
        -- Click handler
        button:SetScript("OnClick", function(self)
            SetCurrentTitle(titleData.id)
            UpdateTitlesOverlay()
        end)
        
        button:Show()
        yOffset = yOffset - 22
    end
    
  -- Hide unused buttons
    for i = #titles + 1, #buttons do
        buttons[i]:Hide()
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

local function SkinTitlesPane()
    CreateTitlesOverlay()
    UpdateTitlesOverlay()
end

---------------------------------------------------------------------------
-- MAIN SKIN APPLICATION
---------------------------------------------------------------------------

function CharacterPane:ApplySkin()
    if not IsEnabled() or skinned then return end
    if not CharacterFrame then return end
    
    -- Apply all skins
    StripBlizzardTextures()
    SkinCharacterFrameBackdrop()
    RepositionEquipmentSlots()
    SkinAllEquipmentSlots()
    SkinCharacterTabs()
    SkinStatsPane()
    SkinTitlesPane()
    
    -- Re-skin tabs after a delay to catch any late-loading sidebar tabs
    C_Timer.After(0.2, function()
        SkinCharacterTabs()
    end)
    
    skinned = true
    
    -- Listen for theme changes
    self:RegisterMessage("AbstractUI_THEME_CHANGED", "OnThemeChanged")
end

function CharacterPane:OnThemeChanged()
    if not IsEnabled() then return end
    
    -- Reapply skins with new theme colors
    skinned = false
    self:ApplySkin()
end
