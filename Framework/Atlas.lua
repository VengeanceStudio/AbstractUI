-- MidnightUI Texture Atlas System
-- Manages texture coordinates and atlas loading for efficient UI rendering

local Atlas = {}
_G.MidnightUI_Atlas = Atlas

-- Atlas definitions - texture coordinates for each component in the atlas
Atlas.atlases = {}
Atlas.loadedTextures = {}

-- ============================================================================
-- ATLAS REGISTRATION
-- ============================================================================

function Atlas:RegisterAtlas(name, texturePath, width, height, regions)
    self.atlases[name] = {
        path = texturePath,
        width = width,
        height = height,
        regions = regions or {}
    }
end

-- ============================================================================
-- COORDINATE HELPERS
-- ============================================================================

-- Convert pixel coordinates to texture coordinates (0-1 range)
function Atlas:PixelToTexCoord(atlas, x, y, w, h)
    local atlasData = self.atlases[atlas]
    if not atlasData then return 0, 0, 1, 1 end
    
    local left = x / atlasData.width
    local right = (x + w) / atlasData.width
    local top = y / atlasData.height
    local bottom = (y + h) / atlasData.height
    
    return left, right, top, bottom
end

-- Get texture coordinates for a named region
function Atlas:GetRegion(atlas, regionName)
    local atlasData = self.atlases[atlas]
    if not atlasData or not atlasData.regions[regionName] then
        return 0, 0, 1, 1
    end
    
    local region = atlasData.regions[regionName]
    return self:PixelToTexCoord(atlas, region.x, region.y, region.w, region.h)
end

-- ============================================================================
-- TEXTURE APPLICATION
-- ============================================================================

-- Apply atlas region to a texture object
function Atlas:SetTexture(textureObj, atlas, regionName)
    local atlasData = self.atlases[atlas]
    if not atlasData or not textureObj then return false end
    
    textureObj:SetTexture(atlasData.path)
    
    if regionName then
        local left, right, top, bottom = self:GetRegion(atlas, regionName)
        textureObj:SetTexCoord(left, right, top, bottom)
    end
    
    return true
end

-- Apply atlas region with color tint
function Atlas:SetTextureWithColor(textureObj, atlas, regionName, r, g, b, a)
    if self:SetTexture(textureObj, atlas, regionName) then
        textureObj:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
        return true
    end
    return false
end

-- ============================================================================
-- PRELOAD TEXTURES
-- ============================================================================

function Atlas:PreloadAtlas(atlas)
    local atlasData = self.atlases[atlas]
    if not atlasData then return false end
    
    if not self.loadedTextures[atlas] then
        -- Create a hidden frame to preload the texture
        local preloader = CreateFrame("Frame")
        local tex = preloader:CreateTexture()
        tex:SetTexture(atlasData.path)
        self.loadedTextures[atlas] = true
    end
    
    return true
end

-- ============================================================================
-- COMMON ATLAS DEFINITIONS
-- ============================================================================

-- Register common atlas (shared UI elements)
Atlas:RegisterAtlas("Common", "Interface\\AddOns\\MidnightUI\\Media\\Textures\\Atlas\\Common", 512, 512, {
    -- These will be defined once actual texture files are created
    ["white"] = {x = 0, y = 0, w = 32, h = 32},
    ["border-simple"] = {x = 32, y = 0, w = 64, h = 64},
})

-- Midnight Glass atlas
Atlas:RegisterAtlas("MidnightGlass", "Interface\\AddOns\\MidnightUI\\Media\\Textures\\Atlas\\MidnightGlass", 1024, 1024, {
    -- Button states
    ["button-normal"] = {x = 0, y = 0, w = 256, h = 64},
    ["button-hover"] = {x = 0, y = 64, w = 256, h = 64},
    ["button-pressed"] = {x = 0, y = 128, w = 256, h = 64},
    ["button-disabled"] = {x = 0, y = 192, w = 256, h = 64},
    
    -- Panel backgrounds
    ["panel-bg"] = {x = 256, y = 0, w = 256, h = 256},
    ["panel-border"] = {x = 512, y = 0, w = 256, h = 256},
    
    -- Tab states
    ["tab-inactive"] = {x = 0, y = 256, w = 128, h = 48},
    ["tab-active"] = {x = 128, y = 256, w = 128, h = 48},
    
    -- Scrollbar
    ["scrollbar-track"] = {x = 768, y = 0, w = 32, h = 256},
    ["scrollbar-thumb"] = {x = 800, y = 0, w = 32, h = 64},
    
    -- Tooltip
    ["tooltip-bg"] = {x = 0, y = 304, w = 256, h = 128},
})

-- Neon SciFi atlas
Atlas:RegisterAtlas("NeonSciFi", "Interface\\AddOns\\MidnightUI\\Media\\Textures\\Atlas\\NeonSciFi", 1024, 1024, {
    -- Button states
    ["button-normal"] = {x = 0, y = 0, w = 256, h = 64},
    ["button-hover"] = {x = 0, y = 64, w = 256, h = 64},
    ["button-pressed"] = {x = 0, y = 128, w = 256, h = 64},
    ["button-disabled"] = {x = 0, y = 192, w = 256, h = 64},
    
    -- Panel backgrounds with neon glow
    ["panel-bg"] = {x = 256, y = 0, w = 256, h = 256},
    ["panel-border-glow"] = {x = 512, y = 0, w = 256, h = 256},
    
    -- Tab states with neon accents
    ["tab-inactive"] = {x = 0, y = 256, w = 128, h = 48},
    ["tab-active"] = {x = 128, y = 256, w = 128, h = 48},
    
    -- Scrollbar with glow effect
    ["scrollbar-track"] = {x = 768, y = 0, w = 32, h = 256},
    ["scrollbar-thumb"] = {x = 800, y = 0, w = 32, h = 64},
    ["scrollbar-glow"] = {x = 832, y = 0, w = 32, h = 64},
    
    -- Tooltip with holographic effect
    ["tooltip-bg"] = {x = 0, y = 304, w = 256, h = 128},
    ["tooltip-glow"] = {x = 256, y = 304, w = 256, h = 128},
})

return Atlas
