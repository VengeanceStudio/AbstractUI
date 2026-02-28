
if not UnitFrames then return end
-- MidnightUI UnitFrames: Boss Frames Module

-- Get MidnightUI addon reference for accessing other modules
local MidnightUI = LibStub and LibStub("AceAddon-3.0"):GetAddon("MidnightUI")

-- ============================================================================
-- BOSS FRAMES CREATION
-- ============================================================================

function UnitFrames:CreateBossFrames()
    if not self.db or not self.db.profile or not self.db.profile.showBoss then return end
    local db = self.db.profile
    local bossConfig = db.boss
    if not bossConfig then return end
    
    -- Create 5 boss frames (boss1-boss5) using shared config
    local boss1Frame = nil
    for i = 1, 5 do
        local key = "Boss" .. i .. "Frame"
        local unit = "boss" .. i
        
        if i == 1 then
            -- Boss 1: Use saved position or default
            local baseX = (bossConfig.basePosition and bossConfig.basePosition.x) or -100
            local baseY = (bossConfig.basePosition and bossConfig.basePosition.y) or -200
            
            -- Check for saved position
            if bossConfig.posX then baseX = bossConfig.posX end
            if bossConfig.posY then baseY = bossConfig.posY end
            
            self:CreateUnitFrame(key, unit, UIParent, "CENTER", "CENTER", baseX, baseY)
            boss1Frame = _G["MidnightUI_" .. key]
        else
            -- Boss 2-5: Position relative to boss1 with spacing
            local spacing = bossConfig.spacing or 80
            local yOffset = -spacing * (i - 1)
            
            -- Create frame initially at same position as boss1, then reposition
            self:CreateUnitFrame(key, unit, UIParent, "CENTER", "CENTER", 0, 0)
            
            local bossFrame = _G["MidnightUI_" .. key]
            if bossFrame and boss1Frame then
                -- Position relative to boss1
                bossFrame:ClearAllPoints()
                bossFrame:SetPoint("TOP", boss1Frame, "TOP", 0, yOffset)
            end
        end
        
        -- Configure visibility with state driver
        local bossFrame = _G["MidnightUI_" .. key]
        if bossFrame then
            -- Start hidden - state driver will show when boss exists
            bossFrame:Hide()
            -- Also hide child bars explicitly
            if bossFrame.healthBar then bossFrame.healthBar:Hide() end
            if bossFrame.powerBar then bossFrame.powerBar:Hide() end
            if bossFrame.infoBar then bossFrame.infoBar:Hide() end
            -- Safely register state drivers
            if not InCombatLockdown() then
                UnregisterStateDriver(bossFrame, "visibility")
                RegisterStateDriver(bossFrame, "visibility", "[@" .. unit .. ",exists] show; hide")
            end
            -- If boss exists right now, force update
            if UnitExists(unit) then
                self:UpdateUnitFrame(key, unit)
            end
        end
    end
    
    -- Create a single large movable overlay for all boss frames
    if boss1Frame then
        local Movable = MidnightUI:GetModule("Movable", true)
        if Movable then
            -- Remove existing boss overlay if present
            if _G.MidnightUI_BossFramesOverlay then
                _G.MidnightUI_BossFramesOverlay:Hide()
                _G.MidnightUI_BossFramesOverlay:SetParent(nil)
                _G.MidnightUI_BossFramesOverlay = nil
            end
            
            -- Calculate total height for all 5 boss frames
            local singleFrameHeight = boss1Frame:GetHeight()
            local spacing = bossConfig.spacing or 80
            local totalHeight = singleFrameHeight + (spacing * 4) -- First frame + 4 gaps
            local frameWidth = boss1Frame:GetWidth()
            
            -- Create overlay frame
            local overlay = CreateFrame("Frame", "MidnightUI_BossFramesOverlay", UIParent, "BackdropTemplate")
            overlay:SetFrameStrata("FULLSCREEN_DIALOG")
            overlay:SetFrameLevel(10000)
            overlay:SetSize(frameWidth, totalHeight)
            overlay:SetPoint("TOP", boss1Frame, "TOP", 0, 0)
            
            -- Styling
            overlay:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            overlay:SetBackdropColor(0, 0.5, 0, 0.2)
            overlay:SetBackdropBorderColor(0, 1, 0, 1)
            
            -- Label
            local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            label:SetPoint("CENTER")
            label:SetText("Boss Frames")
            label:SetTextColor(1, 1, 1, 1)
            label:SetShadowOffset(2, -2)
            label:SetShadowColor(0, 0, 0, 1)
            overlay:Hide()
            
            -- Make overlay draggable
            overlay:SetMovable(true)
            overlay:EnableMouse(true)
            overlay:RegisterForDrag("LeftButton")
            overlay:SetClampedToScreen(true)
            boss1Frame:SetMovable(true)
            boss1Frame:SetClampedToScreen(true)
            
            local isDragging = false
            overlay:SetScript("OnDragStart", function(self)
                if MidnightUI.moveMode then
                    isDragging = true
                    boss1Frame:StartMoving()
                end
            end)
            
            overlay:SetScript("OnDragStop", function(self)
                if not isDragging then return end
                boss1Frame:StopMovingOrSizing()
                isDragging = false
                
                -- Save position
                local point, relativeTo, relativePoint, xOfs, yOfs = boss1Frame:GetPoint()
                bossConfig.anchorPoint = point or "CENTER"
                bossConfig.relativePoint = relativePoint or "CENTER"
                bossConfig.posX = xOfs or 0
                bossConfig.posY = yOfs or 0
                
                -- Update overlay position
                overlay:ClearAllPoints()
                overlay:SetPoint("TOP", boss1Frame, "TOP", 0, 0)
            end)
            
            -- Register with Movable system
            overlay.parentFrame = boss1Frame
            overlay.movableHighlight = overlay
            overlay.movableHighlightLabel = label
            table.insert(Movable.registeredFrames, overlay)
            
            -- Add nudge arrows
            Movable:CreateNudgeArrows(boss1Frame, bossConfig, function()
                -- Reset callback
                bossConfig.anchorPoint = "CENTER"
                bossConfig.relativePoint = "CENTER"
                bossConfig.posX = -100
                bossConfig.posY = -200
                boss1Frame:ClearAllPoints()
                boss1Frame:SetPoint("CENTER", UIParent, "CENTER", -100, -200)
                overlay:ClearAllPoints()
                overlay:SetPoint("TOP", boss1Frame, "TOP", 0, 0)
            end)
            
            -- Hook to show/hide arrows
            overlay:HookScript("OnEnter", function()
                if MidnightUI.moveMode and boss1Frame.arrows then
                    if boss1Frame.arrowHideTimer then
                        boss1Frame.arrowHideTimer:Cancel()
                        boss1Frame.arrowHideTimer = nil
                    end
                    Movable:UpdateNudgeArrows(boss1Frame)
                end
            end)
            
            overlay:HookScript("OnLeave", function()
                boss1Frame.arrowHideTimer = C_Timer.NewTimer(0.3, function()
                    if not MouseIsOver(overlay) then
                        local overArrow = false
                        for _, arrow in pairs(boss1Frame.arrows or {}) do
                            if MouseIsOver(arrow) then
                                overArrow = true
                                break
                            end
                        end
                        if not overArrow then
                            Movable:HideNudgeArrows(boss1Frame)
                        end
                    end
                    boss1Frame.arrowHideTimer = nil
                end)
            end)
        end
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetBossOptions_Real()
    return self:GenerateFrameOptions("Boss Frames", "boss", "CreateBossFrames", "MidnightUI_Boss1Frame")
end
