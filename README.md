# SavedLockouts

A lightweight World of Warcraft 3.3.5 addon designed to track, aggregate, and display raid and dungeon lockouts across all characters on your account.

**Author:** Copper  
**Client Version:** World of Warcraft 3.3.5 (Interface: 30300)  

---

## Installation

1. Download the latest `.zip` release file from the **Releases** tab on GitHub.
2. Extract the contents of the `.zip` archive on your computer.
3. Drag or copy the extracted `SavedLockouts` folder directly into your World of Warcraft directory under `Interface\AddOns\`:
   ```text
   World of Warcraft\Interface\AddOns\
   ```
   *Example path:* `C:\Program Files\World of Warcraft\Interface\AddOns\SavedLockouts\`
4. Verify that `SavedLockouts.toc` is located directly inside the `SavedLockouts` directory and not nested in a duplicate subfolder (e.g., avoid `Interface\AddOns\SavedLockouts\SavedLockouts\`).
5. Launch World of Warcraft. At the character select screen, click the **AddOns** button in the lower-left corner and ensure `SavedLockouts` is enabled on all your characters.

---

## Panel Breakdown

### 1. Main Overview Panel
The primary dashboard provides a single-window summary of every character saved in the database and their current lockout states.
- **Character Matrix:** Displays a clean list of alts alongside active 10-man and 25-man raid lockouts.
- **Status Indicators:** Uses color-coded text to immediately distinguish between available instances, active lockouts, and expiring timers.
- **Expiration Timers:** Displays exact remaining real-world time before instance resets occur.
- **Completion Summary:** Shows boss progression ratios (e.g., 12/12 ICC, 4/4 RS, 5/5 ToGC) at a glance without needing to log onto each alt.

### 2. Character Detail Panel
A granular view focusing on an individual character's active lockouts and instance history.
- **Boss Defeat Breakdown:** Lists every boss within a specific saved instance and identifies which remain alive or killed.
- **Instance ID Tracker:** Displays the unique server Instance ID for active raids, allowing you to easily match raid IDs across alt groups or guild runs.
- **Difficulty & Mode Indicators:** Clearly separates Normal and Heroic lockout variations across 10-player and 25-player sizes.

### 3. Options & Configuration Panel
In-game settings menu to customize tracking behavior and maintain stored character data.
- **Instance Filters:** Toggle tracking on or off for specific raids (Icecrown Citadel, Ruby Sanctum, Trial of the Grand Crusader, Vault of Archavon, Onyxia's Lair) or 5-man Heroic dungeons.
- **Database Management:** Remove outdated or deleted characters from the tracking database with a single click.
- **UI Customization:** Frame scale adjustments, background opacity toggles, and keybind assignments for fast window access.

---

## Slash Commands

- `/sl` or `/savedlockouts` — Toggle the Main Overview Panel.
- `/sl config` — Open the Options & Configuration Panel.
- `/sl reset` — Reset window positions to default.

---

## Changelog

### v1.2.0
- **Core Updates:**
  * Expanded lockout tracking engine to cover 5-man Heroic daily dungeon resets alongside 10/25 raid lockouts.
  * Added hover tooltips over instances in the Main Overview Panel for rapid boss status checks.
  * Added expiration threshold color coding for lockouts resetting within 24 hours.
- **UI & Performance:**
  * Applied class-color formatting to character names across tracking windows.
  * Added scale and opacity configuration options in the settings panel.
  * Fixed an issue where instance lockout states failed to refresh automatically without a UI reload (`/reload`).
  * Optimized SavedVariables table cleanup on logout to purge orphaned data.

### v1.1.0
- **Feature Additions:**
  * Added Character Detail Panel to view individual boss kills and server Instance IDs.
  * Added boss progression summary counters (e.g., `12/12 ICC`, `4/4 RS`, `5/5 ToGC`).
  * Added automated database purge utilities to clean up deleted or inactive alt profiles.
- **Fixes:**
  * Resolved `nil` comparison error when opening the interface on a character with zero active lockouts.
  * Fixed 10-man vs. 25-man Heroic difficulty ID parsing in `GetSavedInstanceInfo` for the 3.3.5 client API.

### v1.0.0
- **Initial Release:**
  * Initial release of SavedLockouts for World of Warcraft 3.3.5 (Interface: 30300) by Copper.
  * Multi-character lockout tracking engine with SavedVariables persistence.
  * Support for core 3.3.5 raids: Icecrown Citadel, Ruby Sanctum, Trial of the Grand Crusader, Vault of Archavon, and Onyxia's Lair.
  * Main Overview Panel featuring cross-character lockout matrix and expiration timers.
  * Slash command integration (`/sl`).
