-- MidnightUI Layout Helper System
-- Grid system, anchoring, and responsive scaling

local LayoutHelper = {}
_G.MidnightUI_LayoutHelper = LayoutHelper

-- Grid settings
LayoutHelper.gridSize = 8
LayoutHelper.margin = 16
LayoutHelper.padding = 8

-- Reference resolution for scaling
LayoutHelper.referenceWidth = 2133
LayoutHelper.referenceHeight = 1200

-- ============================================================================
-- GRID HELPERS
-- ============================================================================

-- Snap value to grid
function LayoutHelper:SnapToGrid(value)
    return math.floor((value / self.gridSize) + 0.5) * self.gridSize
end

-- Get grid units from pixels
function LayoutHelper:PixelsToGrid(pixels)
    return math.floor(pixels / self.gridSize)
end

-- Get pixels from grid units
function LayoutHelper:GridToPixels(units)
    return units * self.gridSize
end

-- ============================================================================
-- ANCHORING
-- ============================================================================

-- Standard anchor positions
LayoutHelper.anchors = {
    TOP_LEFT = {point = "TOPLEFT", x = 0, y = 0},
    TOP = {point = "TOP", x = 0, y = 0},
    TOP_RIGHT = {point = "TOPRIGHT", x = 0, y = 0},
    LEFT = {point = "LEFT", x = 0, y = 0},
    CENTER = {point = "CENTER", x = 0, y = 0},
    RIGHT = {point = "RIGHT", x = 0, y = 0},
    BOTTOM_LEFT = {point = "BOTTOMLEFT", x = 0, y = 0},
    BOTTOM = {point = "BOTTOM", x = 0, y = 0},
    BOTTOM_RIGHT = {point = "BOTTOMRIGHT", x = 0, y = 0},
}

-- Set frame anchor with margin
function LayoutHelper:SetAnchor(frame, anchorName, parent, offsetX, offsetY)
    parent = parent or UIParent
    local anchor = self.anchors[anchorName] or self.anchors.CENTER
    
    local x = (offsetX or 0) + anchor.x
    local y = (offsetY or 0) + anchor.y
    
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point, parent, anchor.point, x, y)
end

-- Anchor frame relative to another frame
function LayoutHelper:SetRelativeAnchor(frame, relativeTo, myPoint, theirPoint, offsetX, offsetY)
    frame:ClearAllPoints()
    frame:SetPoint(myPoint, relativeTo, theirPoint, offsetX or 0, offsetY or 0)
end

-- ============================================================================
-- SPACING & SIZING
-- ============================================================================

-- Apply padding to frame
function LayoutHelper:ApplyPadding(frame, padding)
    padding = padding or self.padding
    return padding, -padding, -padding, padding
end

-- Get standard margin
function LayoutHelper:GetMargin()
    return self.margin
end

-- Get standard padding
function LayoutHelper:GetPadding()
    return self.padding
end

-- ============================================================================
-- RESPONSIVE SCALING
-- ============================================================================

-- Get UI scale factor based on current resolution
function LayoutHelper:GetScaleFactor()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- Calculate scale based on width (most common constraint)
    local widthScale = screenWidth / self.referenceWidth
    local heightScale = screenHeight / self.referenceHeight
    
    -- Use the smaller scale to ensure everything fits
    return math.min(widthScale, heightScale)
end

-- Scale value based on current resolution
function LayoutHelper:ScaleValue(value)
    return value * self:GetScaleFactor()
end

-- Get scaled size
function LayoutHelper:GetScaledSize(width, height)
    local scale = self:GetScaleFactor()
    return width * scale, height * scale
end

-- ============================================================================
-- LAYOUT CONTAINERS
-- ============================================================================

-- Create a vertical layout container
function LayoutHelper:CreateVBox(parent, spacing)
    spacing = spacing or self.padding
    
    local container = {
        parent = parent,
        spacing = spacing,
        children = {},
        currentY = 0,
    }
    
    function container:Add(frame, height)
        table.insert(self.children, frame)
        frame:SetPoint("TOP", self.parent, "TOP", 0, -self.currentY)
        self.currentY = self.currentY + height + self.spacing
    end
    
    function container:GetHeight()
        return self.currentY
    end
    
    return container
end

-- Create a horizontal layout container
function LayoutHelper:CreateHBox(parent, spacing)
    spacing = spacing or self.padding
    
    local container = {
        parent = parent,
        spacing = spacing,
        children = {},
        currentX = 0,
    }
    
    function container:Add(frame, width)
        table.insert(self.children, frame)
        frame:SetPoint("LEFT", self.parent, "LEFT", self.currentX, 0)
        self.currentX = self.currentX + width + self.spacing
    end
    
    function container:GetWidth()
        return self.currentX
    end
    
    return container
end

-- ============================================================================
-- ALIGNMENT HELPERS
-- ============================================================================

-- Center frame horizontally in parent
function LayoutHelper:CenterHorizontally(frame, parent, offsetY)
    parent = parent or UIParent
    frame:ClearAllPoints()
    frame:SetPoint("TOP", parent, "TOP", 0, offsetY or 0)
end

-- Center frame vertically in parent
function LayoutHelper:CenterVertically(frame, parent, offsetX)
    parent = parent or UIParent
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", parent, "LEFT", offsetX or 0, 0)
end

-- Center frame completely in parent
function LayoutHelper:Center(frame, parent)
    parent = parent or UIParent
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
end

-- ============================================================================
-- SIZE HELPERS
-- ============================================================================

-- Set size with grid snapping
function LayoutHelper:SetSizeSnapped(frame, width, height)
    frame:SetSize(
        self:SnapToGrid(width),
        self:SnapToGrid(height)
    )
end

-- Fill parent with optional padding
function LayoutHelper:FillParent(frame, parent, padding)
    parent = parent or frame:GetParent()
    padding = padding or 0
    
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", padding, -padding)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -padding, padding)
end

return LayoutHelper
