# SavedLockouts v1.2

A lightweight World of Warcraft 3.3.5a addon designed to track, manage, and export character raid and heroic dungeon lockouts across your entire account.

**Author:** Copper  
**Client Version:** World of Warcraft 3.3.5 (Interface: 30300)  

---

## Installation

1. Download the latest `.zip` release file from the green **Code** dropdown on GitHub.
2. Extract the contents of the `.zip` archive on your computer.
3. Drag or copy the extracted `SavedLockouts` folder directly into your World of Warcraft directory under `Interface\AddOns\`:
   ```text
   World of Warcraft\Interface\AddOns\
   ```
   *Example path:* `C:\Program Files\World of Warcraft\Interface\AddOns\SavedLockouts\`
4. Verify that `SavedLockouts.toc` is located directly inside the `SavedLockouts` directory and not nested in a duplicate subfolder (e.g., avoid `Interface\AddOns\SavedLockouts\SavedLockouts\`).
5. Launch World of Warcraft. At the character select screen, click the **AddOns** button in the lower-left corner and ensure `SavedLockouts` is enabled on all your characters.

---

## Features

### Clean UI & Dashboard
* **Main Instances Panel**: View all active character lockouts on your current realm at a glance, organized with class-colored names, talent specs, and factions.
* **Dual View Modes**: Easily toggle between **Raids** and **Heroic 5-Mans** using the dedicated top-bar tabs.
* **Minimap Button**: 
  * **Left-Click**: Open the main instances panel.
  * **Right-Click**: Open the configuration panel.
  * Drag to reposition around the minimap freely.
* **Slash Commands**: Quick access via `/lockouts`, `/sl`, or `/sl config` (also supports `options` or `opt`).
* **Full ESC Support**: Pressing the Escape key cleanly closes any open addon window.

### Config Panel & Ignore Lists
* **Config Panel**: A centralized hub to access your ignore lists, data resets, help guides, and main panel toggle.
* **Character & Spec Ignoring**: 
  * Hide entire characters from being reported.
  * Selectively ignore specific talent specs (Spec 1 or Spec 2) while keeping the character visible.
  * Automatically handles duplicate talent tree names (e.g., dual protection specs) via strict slot-index tracking.
  * Ignores and preferences persist safely even when lockouts expire or reset.
* **Data Reset Protection**: Securely wipe all saved realm data using a Blizzard confirmation popup (`OK` / `CANCEL`).

### Flexible Data Export (Standard & Discord)
* **Export Window**: Instantly generate clean, copy-pasteable summaries of your account lockouts.
* **Discord Output Mode**: Check the **"Discord Output"** box to automatically format your export using Discord-compatible Markdown (`#` headers, `###` character titles, and clean bullet points) with zero leading hyphens or indentation glitches.
* **Dynamic Versioning**: Automatically pulls the current version from your `.toc` file metadata.
