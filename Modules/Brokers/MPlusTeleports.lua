-- AbstractUI M+ Teleports Broker
-- Displays a list of Midnight Season 1 Mythic Plus dungeon teleports

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local teleportFrame
local teleportObj

-- Midnight Season 1 (12.0) Mythic Plus Dungeons with their teleport spell IDs
-- Spell IDs sourced from M+ Dungeon Teleports addon data
local DUNGEON_TELEPORTS = {
    { name = "Algeth'ar Academy", spellID = 393273 },
    { name = "Maisara Caverns", spellID = 1254559 },
    { name = "Magisters' Terrace", spellID = 1254572 },
    { name = "Nexus-Point Xenas", spellID = 1254563 },
    { name = "Pit of Saron", spellID = 1254555 },
    { name = "Seat of the Triumvirate", spellID = 1254551 },
    { name = "Skyreach", spellID = 159898 },
    { name = "Windrunner Spire", spellID = 1254400 },
}

-- Create the teleports popup frame
local function CreateTeleportFrame()
    if teleportFrame then return end
    
    teleportFrame = CreateFrame("Frame", "AbstractMPlusTeleportsPopup", UIParent, "BackdropTemplate")
    teleportFrame:SetSize(300, 340)
    teleportFrame:SetFrameStrata("DIALOG")
    teleportFrame:EnableMouse(true)
    teleportFrame:Hide()
    
    -- Title
    local titleText = teleportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText("M+ Teleports - Season 1")
    teleportFrame.title = titleText
    
    -- Subtitle
    local subtitleText = teleportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitleText:SetPoint("TOP", 0, -28)
    subtitleText:SetText("Midnight Dungeons")
    subtitleText:SetTextColor(0.7, 0.7, 0.7)
    teleportFrame.subtitle = subtitleText
    
    -- Scroll frame for dungeon list
    local scrollFrame = CreateFrame("ScrollFrame", nil, teleportFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(260, 1)
    scrollFrame:SetScrollChild(scrollChild)
    teleportFrame.scrollChild = scrollChild
    
    -- Create all teleport buttons NOW (in secure context)
    UpdateTeleportButtons()
    
    -- OnShow script to update fonts/colors dynamically
    teleportFrame:SetScript("OnShow", function(self)
        -- Refresh backdrop with current theme
        AbstractUI:ApplyThemedBackdrop(self)
        
        local db = BrokerBar.db.profile
        local FontKit = _G.AbstractUI_FontKit
        local titleFont, titleSize, bodyFont, bodySize, fontFlags
        
        if FontKit then
            titleFont = FontKit:GetFont('header')
            titleSize = FontKit:GetSize('large')
            bodyFont = FontKit:GetFont('body')
            bodySize = FontKit:GetSize('normal')
            fontFlags = "OUTLINE"
        else
            local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
            titleFont, bodyFont = fontPath, fontPath
            titleSize = db.fontSize + 2
            bodySize = db.fontSize
            fontFlags = "OUTLINE"
        end
        
        local r, g, b = GetColor()
        
        -- Update title
        self.title:SetFont(titleFont, titleSize, fontFlags)
        self.title:SetTextColor(r, g, b)
        
        -- Update subtitle
        self.subtitle:SetFont(bodyFont, bodySize - 2, fontFlags)
        
        -- Don't recreate buttons - they were created in secure context
        -- Just update their fonts if needed
        for _, child in ipairs({self.scrollChild:GetChildren()}) do
            if child.nameText then
                child.nameText:SetFont(bodyFont, bodySize, "OUTLINE")
            end
        end
    end)
    
    -- Auto-hide on mouse leave
    teleportFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then
            self.timer = 0
        else
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then
                self:Hide()
            end
        end
    end)
end

-- Update the teleport button list (called once during frame creation)
function UpdateTeleportButtons()
    if not teleportFrame or not teleportFrame.scrollChild then return end
    
    local db = BrokerBar.db.profile
    local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
    local fontSize = db.fontSize
    local yOffset = 0
    
    for i, dungeon in ipairs(DUNGEON_TELEPORTS) do
        local hasSpell = false
        local spellName = ""
        local spellIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
        
        -- Check if player knows the teleport spell
        if dungeon.spellID and dungeon.spellID > 0 then
            hasSpell = IsSpellKnown(dungeon.spellID)
            local spellInfo = C_Spell.GetSpellInfo(dungeon.spellID)
            if spellInfo then
                spellName = spellInfo.name or dungeon.name
                spellIcon = spellInfo.iconID or spellIcon
            end
        end
        
        -- Create button for this dungeon (use SecureActionButton to avoid taint)
        local btn
        if hasSpell and dungeon.spellID > 0 then
            -- Create secure button that can cast spells
            btn = CreateFrame("Button", nil, teleportFrame.scrollChild, "SecureActionButtonTemplate, BackdropTemplate")
            btn:RegisterForClicks("AnyUp")
            -- Use macro to cast spell by name (more reliable than ID)
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/cast " .. (spellName or dungeon.spellID))
        else
            -- Regular button for unlearned spells
            btn = CreateFrame("Button", nil, teleportFrame.scrollChild, "BackdropTemplate")
        end
        
        btn:SetSize(260, 30)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Button backdrop
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        
        if hasSpell then
            -- Learned spell - normal appearance
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        else
            -- Unlearned spell - grayed out
            btn:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
            btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
        end
        
        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 3, 0)
        icon:SetTexture(spellIcon)
        
        if not hasSpell then
            icon:SetDesaturated(true)
            icon:SetAlpha(0.5)
        end
        
        -- Dungeon name text
        local nameText = btn:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(fontPath, fontSize, "OUTLINE")
        nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        nameText:SetPoint("RIGHT", -5, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(dungeon.name)
        btn.nameText = nameText  -- Store reference for later font updates
        
        if hasSpell then
            nameText:SetTextColor(1, 1, 1)
        else
            nameText:SetTextColor(0.5, 0.5, 0.5)
        end
        
        -- Button functionality
        if hasSpell and dungeon.spellID > 0 then
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.2, 0.2, 0.3, 0.9)
                
                -- Show tooltip with spell info
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(dungeon.spellID)
                GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                GameTooltip:Hide()
            end)
            
            -- Secure button handles the spell cast automatically
            -- Add PostClick to hide the frame after casting
            btn:SetScript("PostClick", function(self)
                -- Hide the popup after casting
                if teleportFrame then
                    teleportFrame:Hide()
                end
            end)
        else
            -- Spell not learned - show tooltip explaining
            btn:SetScript("OnEnter", function(self)
                if dungeon.spellID == 0 then
                    -- Placeholder spell ID
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(dungeon.name, 1, 1, 1)
                    GameTooltip:AddLine("Teleport spell not yet available", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("(This is a new dungeon - spell ID pending)", 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                else
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(dungeon.name, 1, 1, 1)
                    GameTooltip:AddLine("Teleport not learned", 0.8, 0.2, 0.2)
                    GameTooltip:AddLine("Complete this dungeon on Mythic +10 difficulty to unlock", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end
            end)
            
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            btn:EnableMouse(true)
            btn:SetScript("OnClick", nil)
        end
        
        yOffset = yOffset - 32
    end
    
    -- Update scroll child height
    teleportFrame.scrollChild:SetHeight(math.abs(yOffset))
end

-- Register the broker
teleportObj = LDB:NewDataObject("AbstractMPlusTeleports", {
    type = "data source",
    text = "M+ Ports",
    icon = "Interface\\Icons\\Spell_Arcane_Portaldalaran", -- Portal icon
    OnEnter = function(self)
        -- Open the teleport menu on hover
        if not teleportFrame then
            CreateTeleportFrame()
        end
        
        teleportFrame.owner = self
        SmartAnchor(teleportFrame, self)
        teleportFrame:Show()
    end,
    OnLeave = function()
        -- Keep frame open if mouse moves into it, handled by frame's OnUpdate
    end,
    OnClick = function(self, button)
        -- Optional: can still add click functionality if desired
        -- For now, just keep the hover behavior
    end,
})

-- Initialize on load - Create the frame immediately in secure context
C_Timer.After(1, function()
    CreateTeleportFrame()
end)

-- Slash command to help find spell IDs
SLASH_MPLUSTELEPORT1 = "/mptele"
SLASH_MPLUSTELEPORT2 = "/mplusteleport"
SlashCmdList["MPLUSTELEPORT"] = function(msg)
    if msg == "list" or msg == "" then
        print("|cff00ff00M+ Teleports - Spell ID Status:|r")
        for i, dungeon in ipairs(DUNGEON_TELEPORTS) do
            local status
            if dungeon.spellID == 0 then
                status = "|cffff0000Unknown|r"
            elseif IsSpellKnown(dungeon.spellID) then
                status = "|cff00ff00Learned|r"
            else
                status = "|cffffff00Not Learned|r"
            end
            print(string.format("%d. %s - Spell ID: %d - %s", i, dungeon.name, dungeon.spellID, status))
        end
        print(" ")
        print("|cff00ff00Commands:|r")
        print("/mptele list - Show all dungeons and spell IDs")
        print("/mptele check <spellID> - Check if you know a spell")
        print(" ")
        print("To find missing spell IDs:")
        print("1. Cast the teleport spell from your spellbook")
        print("2. Check combat log for the spell name")
        print("3. Search spell name on Wowhead to get the ID")
    elseif msg:match("^check%s+(%d+)") then
        local spellID = tonumber(msg:match("^check%s+(%d+)"))
        if spellID then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo then
                local known = IsSpellKnown(spellID)
                print("|cff00ff00Spell ID " .. spellID .. ":|r")
                print("  Name: " .. (spellInfo.name or "Unknown"))
                print("  Known: " .. (known and "|cff00ff00Yes|r" or "|cffff0000No|r"))
            else
                print("|cffff0000Spell ID " .. spellID .. " not found|r")
            end
        end
    else
        print("|cffff0000Unknown command. Use /mptele list for help|r")
    end
end
