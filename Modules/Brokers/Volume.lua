-- MidnightUI Volume Broker
-- Displays master volume and provides volume mixer popup with sliders and settings

if not BrokerBar then return end

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local volFrame
local volObj

-- Create the volume mixer popup
function BrokerBar:CreateVolumeFrame()
    if volFrame then return end
    volFrame = CreateFrame("Frame", "MidnightVolumePopout", UIParent, "BackdropTemplate")
    volFrame:SetSize(220, 320); volFrame:SetFrameStrata("DIALOG"); volFrame:EnableMouse(true); volFrame:Hide()
    
    -- Don't skin on creation, wait for OnShow to apply themed backdrop
    -- MidnightUI:SkinFrame(volFrame)

    local vTitle = volFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vTitle:SetPoint("TOP", 0, -10)
    vTitle:SetText("Volume Mixer")

    -- Add OnShow script to update Title Font/Color dynamically based on current settings
    volFrame:SetScript("OnShow", function()
        -- Refresh backdrop with current theme
        MidnightUI:ApplyThemedBackdrop(volFrame)
        
        local db = BrokerBar.db.profile
        local fontPath, fontSize, fontFlags
        local FontKit = _G.MidnightUI_FontKit
        if FontKit then
            fontPath = FontKit:GetFont('header')
            fontSize = FontKit:GetSize('large')
            fontFlags = "OUTLINE"
        else
            fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
            fontSize = db.fontSize + 2
            fontFlags = "OUTLINE"
        end
        local r, g, b = GetColor()
        vTitle:SetFont(fontPath, fontSize, fontFlags)
        vTitle:SetTextColor(r, g, b)
    end)


    volFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then
            self.timer = 0
        else
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then
                self:Hide()
            end
        end
    end)

    -- Move slider and checkbox creation inside the function
    local function CreateSlider(name, label, cvar, parent, yOffset)
        local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        s:SetPoint("TOP", parent, "TOP", 0, yOffset); s:SetWidth(180)
        local config = BrokerBar:GetSafeConfig("MidnightVolume")
        local step = config.volumeStep or 0.05
        s:SetMinMaxValues(0, 1); s:SetValueStep(step)
        _G[s:GetName().."Text"]:SetText(label)
        s:SetScript("OnShow", function(self) 
            self:SetValue(tonumber(GetCVar(cvar)) or 0) 
        end)
        s:SetScript("OnValueChanged", function(self, value) 
            -- Snap to nearest multiple of step
            value = math.max(0, math.min(1, value))
            local stepCount = math.floor(1 / step + 0.5)
            value = math.floor((value * stepCount) + 0.5) / stepCount
            SetCVar(cvar, value)
            if cvar == "Sound_MasterVolume" then 
                BrokerBar:UpdateAllModules() 
            end 
        end)
    end
    CreateSlider("MUI_VolMaster", "Master", "Sound_MasterVolume", volFrame, -50)
    CreateSlider("MUI_VolMusic", "Music", "Sound_MusicVolume", volFrame, -90)
    CreateSlider("MUI_VolAmbience", "Ambience", "Sound_AmbienceVolume", volFrame, -130)
    CreateSlider("MUI_VolDialog", "Dialog", "Sound_DialogVolume", volFrame, -170)

    local function CreateCheck(label, cvar, parent, yOffset)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        if cb.Text then 
            cb.Text:SetText(label) 
        elseif cb.text then 
            cb.text:SetText(label) 
        end
        cb:SetScript("OnShow", function(self) 
            self:SetChecked(GetCVar(cvar)=="1") 
        end)
        cb:SetScript("OnClick", function(self) 
            SetCVar(cvar, self:GetChecked() and "1" or "0") 
        end)
    end
    -- UPDATED CHECKBOX LABELS
    CreateCheck("Loop Music", "Sound_ZoneMusicNoDelay", volFrame, -210)
    CreateCheck("Sound in Background", "Sound_EnableSoundWhenGameIsInBG", volFrame, -240) 
    CreateCheck("Play Error Speech", "Sound_EnableErrorSpeech", volFrame, -270)
end

-- Register the broker
volObj = LDB:NewDataObject("MidnightVolume", { 
    type = "data source", text = "0%", icon = "Interface\\Common\\VoiceChat-Speaker",
    OnClick = function(self, button) 
        if button == "RightButton" then 
            if not volFrame then 
                BrokerBar:CreateVolumeFrame() 
            end
            volFrame.owner = self
            SmartAnchor(volFrame, self)
            volFrame:Show()
        else 
            local current = tonumber(GetCVar("Sound_MasterVolume")) or 0
            if current > 0 then
                -- Muting: Save current PERCENTAGE value (whole number) to DB
                local currentPercent = math.floor(current * 100)
                BrokerBar.db.profile.lastVolume = currentPercent
                SetCVar("Sound_MasterVolume", "0")
            else
                -- Unmuting: Restore from DB as decimal
                local restorePercent = BrokerBar.db.profile.lastVolume or 100
                if restorePercent == 0 then restorePercent = 100 end
                -- Convert percentage back to decimal (0.0 - 1.0)
                local restoreDecimal = restorePercent / 100
                SetCVar("Sound_MasterVolume", tostring(restoreDecimal))
            end
            BrokerBar:UpdateAllModules()
        end
    end,
    OnMouseWheel = function(_, d) 
        local config = BrokerBar:GetSafeConfig("MidnightVolume")
        local step = config.volumeStep or 0.05
        local v = (tonumber(GetCVar("Sound_MasterVolume")) or 0) + (d>0 and step or -step)
        v = math.max(0, math.min(1, v))
        -- Snap to nearest multiple of step
        local stepCount = math.floor(1 / step + 0.5)
        v = math.floor((v * stepCount) + 0.5) / stepCount
        SetCVar("Sound_MasterVolume", v)
        BrokerBar:UpdateAllModules() 
    end
})
