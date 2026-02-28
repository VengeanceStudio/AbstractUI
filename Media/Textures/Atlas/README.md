# MidnightUI Texture Atlas

This directory contains the texture atlas files used by the MidnightUI framework.

## Atlas Files

### Common.tga
- Size: 512x512
- Contains shared UI elements like borders, basic shapes, and utility textures
- Used by all themes

### MidnightGlass.tga
- Size: 1024x1024
- Contains textures for the Midnight Dark Glass theme
- Dark, translucent glass aesthetic with subtle gradients

### NeonSciFi.tga
- Size: 1024x1024
- Contains textures for the Neon Sci-Fi theme
- Bright neon accents with holographic effects

## Creating Atlases

1. Create textures at the specified sizes
2. Arrange components according to the coordinate definitions in Framework/Atlas.lua
3. Save as .tga files (TGA format required by WoW)
4. Use powers of 2 for texture dimensions (512, 1024, 2048)

## Atlas Regions

See Framework/Atlas.lua for the complete region coordinate mappings for each atlas.
