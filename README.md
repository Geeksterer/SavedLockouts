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

### 3. Options & Configuration Panel
In-game settings menu to customize tracking behavior and maintain stored character data.
- **Database Management:** Remove outdated or deleted characters from the tracking database with a single click.
- **Ignore List:** ignore characters and specs you don't want listed in the main window. Good if you have bank alts that never raid.
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
    * Added expiration threshold color coding for lockouts resetting within 24 hours.
- **UI & Performance:**
  * Applied class-color formatting to character names across tracking windows.
  * Fixed an issue where instance lockout states failed to refresh automatically without a UI reload (`/reload`).
  * Optimized SavedVariables table cleanup on logout to purge orphaned data.

### v1.1.0
- **Feature Additions:**
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
