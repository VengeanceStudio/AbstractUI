-- MidnightUI Chat Copy Module
local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local ChatCopy = MidnightUI:NewModule("ChatCopy", "AceEvent-3.0", "AceHook-3.0")

local frames = {}
local copyFrame, copyEditBox, copyTopBar, closeButton, bottomButton
local ColorPalette, FontKit

function ChatCopy:OnInitialize()
    ColorPalette = _G.MidnightUI_ColorPalette
    FontKit = _G.MidnightUI_FontKit
end

-- Create the copy frame and edit box
local function CreateCopyFrame()
    if copyFrame then return end
    copyFrame = CreateFrame("Frame", "MidnightUI_ChatCopyFrame", UIParent, "BackdropTemplate")
    copyFrame:SetSize(400, 245)
    copyFrame:SetPoint("CENTER", UIParent, -100, 100)
    copyFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", insets = {top = 0, left = 0, bottom = 0, right = 0}})
    
    if ColorPalette then
        copyFrame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    else
        copyFrame:SetBackdropColor(0, 0, 0, .5)
    end
    copyFrame:SetFrameLevel(129)
    copyFrame:SetFrameStrata("TOOLTIP")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:Hide()
    tinsert(UISpecialFrames, "MidnightUI_ChatCopyFrame")

    -- Top bar
    copyTopBar = CreateFrame("Frame", nil, copyFrame, "ThinGoldEdgeTemplate")
    copyTopBar:SetPoint("TOP", -8, 22)
    copyTopBar:SetWidth(100)
    copyTopBar:SetHeight(18)
    copyTopBar.fs = copyTopBar:CreateFontString(nil, "OVERLAY", "NumberFont_Shadow_Tiny")
    copyTopBar.fs:SetText("Chat Copy")
    copyTopBar.fs:SetPoint("CENTER", 0, 0)
    
    if FontKit then
        FontKit:SetFont(copyTopBar.fs, "heading", "normal")
    end
    if ColorPalette then
        copyTopBar.fs:SetTextColor(ColorPalette:GetColor("text-primary"))
    end
    copyTopBar:SetMovable(true)
    copyTopBar:EnableMouse(true)
    copyTopBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not copyFrame.isMoving then
            copyFrame:StartMoving()
            copyFrame.isMoving = true
        end
    end)
    copyTopBar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and copyFrame.isMoving then
            copyFrame:StopMovingOrSizing()
            copyFrame.isMoving = false
        end
    end)
    copyTopBar:SetScript("OnHide", function(self)
        if copyFrame.isMoving then
            copyFrame:StopMovingOrSizing()
            copyFrame.isMoving = false
        end
    end)

    -- Edit box
    copyEditBox = CreateFrame("EditBox", nil, copyFrame, "InputBoxTemplate")
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetFontObject(ChatFontNormal)
    copyEditBox:SetWidth(370)
    copyEditBox:SetHeight(180)
    copyEditBox:SetPoint("TOP", copyFrame, "TOP", 0, -10)
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    copyEditBox:SetScript("OnEditFocusLost", function() copyFrame:Hide() end)
    copyEditBox:EnableMouse(true)
    copyEditBox:HighlightText(0,0)
    -- Remove background and border for a clean look
    if copyEditBox.Left then copyEditBox.Left:SetAlpha(0) end
    if copyEditBox.Right then copyEditBox.Right:SetAlpha(0) end
    if copyEditBox.Middle then copyEditBox.Middle:SetAlpha(0) end
    if copyEditBox.Top then copyEditBox.Top:SetAlpha(0) end
    if copyEditBox.Bottom then copyEditBox.Bottom:SetAlpha(0) end
    if copyEditBox.TopLeft then copyEditBox.TopLeft:SetAlpha(0) end
    if copyEditBox.TopRight then copyEditBox.TopRight:SetAlpha(0) end
    if copyEditBox.BottomLeft then copyEditBox.BottomLeft:SetAlpha(0) end
    if copyEditBox.BottomRight then copyEditBox.BottomRight:SetAlpha(0) end
    copyFrame.EditBox = copyEditBox

    -- Close button (top right)
    closeButton = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 12, 27)
    closeButton:SetWidth(29)
    closeButton:SetHeight(29)
    closeButton:SetScript("OnClick", function() copyFrame:Hide() end)

    -- Bottom close button
    bottomButton = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
    bottomButton:SetPoint("BOTTOM", 0, -23)
    bottomButton:SetWidth(80)
    bottomButton:SetHeight(22)
    bottomButton:SetText("Close")
    bottomButton:SetNormalFontObject("GameFontNormalSmall")
    bottomButton:SetScript("OnClick", function() copyFrame:Hide() end)
    bottomButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not copyFrame.isMoving then
            copyFrame:StartMoving()
            copyFrame.isMoving = true
        end
    end)
    bottomButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and copyFrame.isMoving then
            copyFrame:StopMovingOrSizing()
            copyFrame.isMoving = false
        end
    end)
    bottomButton:SetScript("OnHide", function(self)
        if copyFrame.isMoving then
            copyFrame:StopMovingOrSizing()
            copyFrame.isMoving = false
        end
    end)
end

-- Add button to chat frames
local function AddChatCopyButton(chatFrameNum)
    local chatFrame = _G["ChatFrame" .. chatFrameNum]
    if not chatFrame or chatFrame.copyButton then return end
    local btn = CreateFrame("Button", nil, chatFrame)
    btn:SetSize(18, 18)
    btn:SetPoint("BOTTOMRIGHT", -2, -3)
    btn:SetNormalTexture("Interface\\Icons\\inv_misc_paperbundle02a")
    btn:SetHighlightTexture("Interface\\Icons\\inv_misc_paperbundle02a")
    btn:Hide()
    btn:SetFrameLevel(7)
    btn:SetScript("OnClick", function()
        ChatCopy:OpenCopyFrame(chatFrameNum)
    end)
    chatFrame.copyButton = btn
    -- Track mouseover state for both chatFrame and btn
    local mouseOver = { chat = false, btn = false }
    local function updateButtonVisibility()
        if mouseOver.chat or mouseOver.btn then
            btn:Show()
        else
            btn:Hide()
        end
    end
    chatFrame:HookScript("OnEnter", function()
        mouseOver.chat = true
        updateButtonVisibility()
    end)
    chatFrame:HookScript("OnLeave", function()
        mouseOver.chat = false
        C_Timer.After(0.05, updateButtonVisibility) -- slight delay for smoothness
    end)
    btn:SetScript("OnEnter", function()
        mouseOver.btn = true
        updateButtonVisibility()
    end)
    btn:SetScript("OnLeave", function()
        mouseOver.btn = false
        C_Timer.After(0.05, updateButtonVisibility)
    end)
end

function ChatCopy:OpenCopyFrame(chatFrameNum)
    CreateCopyFrame()
    local chatFrame = _G["ChatFrame" .. chatFrameNum]
    if not chatFrame then return end
    local maxLines = chatFrame:GetNumMessages() or 0
    local lines = {}
    for i = math.max(1, maxLines - 500), maxLines do
        local msg = chatFrame:GetMessageInfo(i)
        if msg then table.insert(lines, msg) end
    end
    copyEditBox:SetText(table.concat(lines, "\n"))
    copyEditBox:HighlightText()
    copyEditBox:SetFocus()
    copyFrame:Show()
end

function ChatCopy:OnEnable()
    for i = 1, NUM_CHAT_WINDOWS do
        AddChatCopyButton(i)
    end
end

function ChatCopy:OnInitialize()
    -- Optionally add config here
end
