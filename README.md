# AbstractUI

![WoW Version](https://img.shields.io/badge/WoW-12.0%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**AbstractUI** is a complete, modular, and modern User Interface replacement for World of Warcraft. 

Built for **WoW 12.0+** (Midnight expansion), it prioritizes readability, performance, and a sleek aesthetic. It removes the clutter of the default Blizzard UI while retaining feature-rich functionality through a suite of integrated modules.

## ✨ Features

AbstractUI is divided into lightweight, independent modules. You can enable or disable each module individually.

---

## 📋 Module Overview

### 🌑 Skins Module
Transform your entire interface with consistent theming across all UI elements.

**Features:**
* **Multiple Pre-defined Themes:** AbstractTransparent (default), AbstractGlass, AbstractGreen, and class-specific themes
* Customizable frame backgrounds and borders with independent transparency controls
* Applies consistent theming to action bars, tooltips, minimap, unit frames, and info bars
* Color customization with RGB + alpha controls
* LibSharedMedia-3.0 integration for custom textures

---

### 📊 Data Broker Bar Module
A powerful, fully customizable bar system for displaying critical game information at a glance.

**Core Features:**
* Support for **unlimited custom bars** with independent positioning
* LibDataBroker-1.1 compatible for third-party data plugins
* Per-bar configuration: position, size, transparency, fonts, textures, and colors
* Three alignment sections per bar: Left, Center, Right
* Click-through mode option

**Built-in Data Brokers:**

| Broker | Description | Features |
|--------|-------------|----------|
| **System Info** | FPS, Latency, Memory | Color-coded alerts (green/yellow/red), click for details |
| **Volume Mixer** | Master sound control | Click to mute/unmute, mousewheel to adjust, visual indicator |
| **Gold Tracker** | Currency display | Shows total gold, click for character breakdown, WoW Token prices |
| **Clock** | Time display | 12/24hr format, daily/weekly reset timers, server/local time toggle |
| **Bag Space** | Inventory tracking | Free/total slots, bag type icons, color-coded warnings |
| **Durability** | Equipment condition | Percentage display, low durability alerts, click for repair window |
| **Friends** | Social tracking | Online friend count, click for detailed friend list with class colors |
| **Guild** | Guild roster | Online guild member count, click for roster with ranks and notes |
| **Location** | Zone information | Current zone name, coordinates (X, Y), instance difficulty |
| **Difficulty** | Instance settings | Shows current difficulty mode, click to change |
| **WoW Token** | Market prices | Current token price, trends, click for auction house link |
| **Item Level** | Character stats | Average equipped item level |

**Interactive Features:**
* Expandable friend and guild rosters with detailed information
* Class coloring for character names
* Zone level and coordinates
* Memory usage per addon breakdown
* Reset timer countdowns

---

### ⚔️ Action Bars Module
Clean, modern action bars that remove Blizzard's default clutter while maintaining full functionality.

**Features:**
* Removes default artwork (Gryphons, Dragons, decorative elements)
* Applies skin theming to all action buttons
* Supports all default action bars (Main, Bottom, Right 1-2, Pet, Stance)
* Customizable button sizes and spacing
* Fade-out when not in use (configurable)
* Hotkey and macro text display options
* Combat state awareness

---

### 🗺️ Maps Module
Enhanced minimap with modern aesthetics and improved functionality.

**Features:**
* **Rectangular/Square minimap** replacing the default circular design
* Clean borders matching current skin
* Auto-zoom functionality
* Coordinate display (X, Y)
* Cleaned-up tracking icons
* Customizable size and position
* Zone text overlay
* Clock integration
* Mail/LFG notifications

---

### ❤️ Unit Frames Module
Advanced, fully customizable unit frames for all unit types with a powerful tag-based text system.

#### Supported Frame Types:
* **Player Frame** - Your character with health, power, and info bars
* **Target Frame** - Current target with hostility coloring
* **Target of Target** - Your target's target
* **Pet Frame** - For Hunters, Warlocks, Death Knights, and other pet classes
* **Focus Frame** - Track your focus target
* **Boss Frames** - Unified system for all 5 boss encounters

#### Core Frame Features:

**Tag System:**
Advanced text formatting with dynamic tags:
* `[curhp]` - Current health value
* `[maxhp]` - Maximum health value
* `[perhp]` - Health percentage
* `[curpp]` - Current power (mana/rage/energy)
* `[maxpp]` - Maximum power
* `[perpp]` - Power percentage
* `[name]` - Unit name
* `[level]` - Unit level
* `[class]` - Class name
* `[classification]` - Elite/Rare status

**Customization Options:**
* **Independent transparency:** Separate alpha controls for bars and backgrounds
* **Color options:** Class coloring, power type coloring, custom RGB colors
* **Hostility coloring:** Green (friendly), Yellow (neutral), Red (enemy)
* **Bar positioning:** Attach bars to health, power, or info sections
* **Fonts & textures:** Full LibSharedMedia-3.0 support
* **Size & scale:** Width, height, and scale adjustments per frame
* **Portrait display:** 2D/3D portraits (where applicable)
* **Cast bars:** Position, size, color, and text customization

---

### ⏱️ Cooldown Manager Module
* Built-in digital timers on ability icons
* Clear, readable cooldown display
* Customizable font and positioning
* Can attach Resource Bars to Cooldown Manager

---

### Resource Bars and Cast Bar Modules
- Primary Power Bar (Mana, Energy, Rage, etc.)
- Secondary Power Bar (Holy Power, Chi, Runes, etc.)
- Both bars support smart attachment to Cooldown Manager
- Cast Bar with optional Spell icon
- Visual indicator for non-interruptible casts

---

### 🎯 Movable Module
Intuitive frame positioning system for complete UI customization.

**Features:**
* **Toggle Move Mode** to unlock frames
* **Visual highlights** showing movable frames with colored borders
* **Drag-and-drop positioning** for all frames
* **Nudge arrows** for pixel-perfect positioning
* **Reset to default** position functionality
* **Lock/unlock** individual frames
* **Preview mode** showing frame boundaries
* Works with all unit frames, info bars, and minimap

---

### 💬 Chat Module
Enhanced chat frame with improved readability and modern styling.

**Features:**
* Restyled chat frames matching current skin
* Improved text contrast
* Customizable chat frame borders
* Integrated button styling
* Copy chat functionality
* URL detection and copying
* Font and size customization

---

### 🛠️ Tweaks Module
Comprehensive quality-of-life improvements and automation features to streamline gameplay.

**Features:**

| Feature | Default | Description |
|---------|---------|-------------|
| **Fast Loot** | ✓ ON | Enforces fast auto-loot on login |
| **Hide Gryphons** | ✓ ON | Removes decorative gryphon/dragon artwork |
| **Hide Bag Bar** | ✓ ON | Removes the default bag bar for cleaner UI |
| **Auto-Repair** | ✓ ON | Automatically repairs all items at vendors with cost reporting |
| **Auto-Repair (Guild)** | OFF | Use guild bank funds for repairs (falls back to personal gold) |
| **Auto-Sell Junk** | ✓ ON | Automatically sells grey (poor quality) items at merchants |
| **Auto-Insert Keystone** | ✓ ON | Automatically places Mythic Keystones into font when near pedestal |
| **Auto-Delete Confirmation** | ✓ ON | Auto-fills "DELETE" text when deleting items |
| **Reveal Map** | ✓ ON | Attempts to reveal unexplored areas on world map |
| **Auto Screenshot** | OFF | Takes automatic screenshots when earning achievements |
| **Skip Cutscenes** | OFF | Automatically skips cinematics and movies (great for alts) |
| **Talent Import Overwrite** | ✓ ON | Adds checkbox to import dialog to overwrite loadouts |

**Automation Details:**
* **Vendor Automation:** Works at any merchant with repair/sell capabilities
* **Keystone Support:** Shadowlands/Dragonflight (ID: 180653) and BFA (ID: 158923)
* **Delete Confirmation:** Works for all item types (regular, good, quest items)
* **Smart Talent Import:** Prevents duplicate loadout creation

---

### 🎨 UI Buttons Module
Consistent styling for interface buttons and menus.

**Features:**
* Styled menu buttons (Character, Spellbook, Talents, Collections, etc.)
* Themed bag buttons
* Micromenu button styling
* Consistent hover effects
* Matches active skin
* Proper scaling and positioning

---

### ⚙️ Setup Module
First-time setup wizard for quick configuration.

**Features:**
* Initial setup wizard on first load
* Profile creation and management
* Quick preset selection
* Module enable/disable configuration
* Skin selection
* Frame positioning presets
* Reset to defaults option

---

## 📦 Dependencies

This addon includes the following libraries in the `libs` folder:
* **Ace3** (AceAddon, AceConfig, AceDB, AceEvent, AceHook, AceConsole, AceSerializer)
* **LibSharedMedia-3.0** (Fonts, Textures, Statusbars)
* **LibDataBroker-1.1** (Data display integration)
* **LibCompress** (Data compression utilities)
* **CallbackHandler-1.0** (Event handling)

## 🚀 Installation

1.  Download the latest release.
2.  Extract the **AbstractUI** folder.
3.  Place the folder into your WoW AddOns directory:
    * `World of Warcraft\_retail_\Interface\AddOns\`
4.  Launch World of Warcraft.
5.  Type `/aui` to open the configuration panel.

## ⚙️ Configuration

Access the full configuration menu via:
* Type `/aui` in chat

### Quick Commands
* `/aui` - Open main settings
* Toggle Move Mode via the Movable module settings to reposition frames

## 📂 Directory Structure

## 🎮 WoW 12.0+ API Changes

AbstractUI is built for the **Midnight expansion (12.0+)** and uses the latest WoW APIs:
* `UnitHealthPercent()` and `UnitPowerPercent()` for efficient resource tracking
* Secure frame system for combat-safe unit frames
* State drivers for dynamic visibility control
* Enhanced event handling for smooth updates

## ⚠️ Known Limitations

* **Party/Raid Frames:** Due to major changes in WoW 12.0's secure frame API, AbstractUI does not support custom party/raid frames. We recommend using dedicated addons like Grid2, VuhDo, or ElvUI for raid frame needs.
* **Combat Restrictions:** Some frame movements and visibility changes are restricted during combat per Blizzard's secure frame policies.

## 🤝 Contributing

AbstractUI welcomes contributions! If you'd like to:
* Report a bug
* Suggest a feature
* Submit code improvements

Please feel free to open an issue or pull request on the project repository.

## 📝 License

This project is licensed under the GNU General Public License - see the [LICENSE.txt](LICENSE.txt) file for details.

## 🙏 Credits

* **Author:** Vengeance
* **Libraries:** Ace3, LibSharedMedia-3.0, LibDataBroker-1.1, LibCompress
* **Community:** Thanks to all users providing feedback and bug reports

## 📞 Support

For support, questions, or feature requests:
* Type `/aui` in-game to access settings
* Check the in-game Tag Help window in unit frame options for text formatting
* Review module tooltips in the options panel for detailed feature descriptions

---

*AbstractUI - A cleaner, modern interface for World of Warcraft: Midnight and beyond.*
