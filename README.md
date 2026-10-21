# SavedLockouts

A lightweight World of Warcraft 3.3.5 addon designed to track, aggregate, and display raid and dungeon lockouts across all characters on your account.

**Author:** Copper  
**Client Version:** World of Warcraft 3.3.5 (Interface: 30300)  

---

## Panel Breakdown

### 1. Main Overview Panel
The primary dashboard provides a single-window summary of every character saved in the database and their current lockout states.
* **Character Matrix:** Displays a clean list of alts alongside active 10-man and 25-man raid lockouts.
* **Status Indicators:** Uses color-coded text to immediately distinguish between available instances, active lockouts, and expiring timers.
* **Expiration Timers:** Displays exact remaining real-world time before instance resets occur.
* **Completion Summary:** Shows boss progression ratios (e.g., 12/12 ICC, 4/4 RS, 5/5 ToGC) at a glance without needing to log onto each alt.

### 2. Character Detail Panel
A granular view focusing on an individual character's active lockouts and instance history.
* **Boss Defeat Breakdown:** Lists every boss within a specific saved instance and identifies which remain alive or killed.
* **Instance ID Tracker:** Displays the unique server Instance ID for active raids, allowing you to easily match raid IDs across alt groups or guild runs.
* **Difficulty & Mode Indicators:** Clearly separates Normal and Heroic lockout variations across 10-player and 25-player sizes.

### 3. Options & Configuration Panel
In-game settings menu to customize tracking behavior and maintain stored character data.
* **Instance Filters:** Toggle tracking on or off for specific raids (Icecrown Citadel, Ruby Sanctum, Trial of the Grand Crusader, Vault of Archavon, Onyxia's Lair) or 5-man Heroic dungeons.
* **Database Management:** Remove outdated or deleted characters from the tracking database with a single click.
* **UI Customization:** Frame scale adjustments, background opacity toggles, and keybind assignments for fast window access.

---

## Slash Commands

* `/sl` or `/savedlockouts` — Toggle the Main Overview Panel.
* `/sl config` — Open the Options & Configuration Panel.
* `/sl reset` — Reset window positions to default.

---

## Changelog

### v1.0.0
* **Initial Release:** Complete core tracking engine for World of Warcraft 3.3.5.
* **Features Implemented:**
  * Multi-character lockout data caching across relogs and character swaps.
  * Support for 10-man, 25-man, Normal, and Heroic raid lockouts.
  * Main Overview Panel with cross-character status matrix.
  * Character Detail Panel with specific boss kill logs and Instance IDs.
  * Options panel for filtering tracked instances and purging alt data.
  * Slash command integration (`/sl`).
