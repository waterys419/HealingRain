# Healing Rain

Raid frames for healers in **WoW: Forever** (client folder `_forever_`), with editable click healing, mouse-wheel and hover keys.

![Healing Rain raid frames (40-player demo)](screenshots/raid-frames.png)

- Solo: shows just your own square.
- Party / raid: shows everyone (up to 40), class-colored, with health and mana.
- Optional Target window.
- Click, wheel and hover-key healing you set up yourself.

## Install

1. Download this repo (green **Code** button → **Download ZIP**).
2. Unzip it and rename the folder to `HealingRain`.
3. Put it in `World of Warcraft/_forever_/Interface/AddOns/`.
4. Restart the game, or type `/reload`.

## Commands

Every command works with any of these four names: `/hr`, `/hh`, `/healingrain`, `/healhelper`.
For example, `/hh demo` and `/hr demo` do the same thing.

| Command | What it does |
|---|---|
| `/hr config` | Open the settings window (looks, clicks, wheel, hover keys) |
| `/hr demo` | Preview a full 40-player raid with your saved look |
| `/hr live` | Leave the demo and show your real group again |
| `/hr show` / `/hr hide` | Show or hide the frames |
| `/hr target` | Turn the Target window on or off |
| `/hr refresh` | Rebuild the roster |
| `/hr clicks` | List your click and wheel heals in chat |
| `/hr help` | List all commands in chat |

**Move the frame:** hold **Alt** and left-drag any square (out of combat). Your position is saved.

Layout changes wait until you leave combat. `/hr config`, `/hr clicks` and `/hr help` work in combat.

## Customize (`/hr config`)

### Name style
Click the **Name style** button to cycle through:

| Style | Example |
|---|---|
| Full name | Water Storm |
| Initials | W. S. |
| First name + last initial | Water S. |
| First 3 letters of each | Wat Sto |
| First name | Water |
| Last name | Storm |

### Health text

| Style | Example |
|---|---|
| Percent | 75% |
| Health | 750 |
| Health / maximum | 750 / 1000 |
| Health + percent | 750 (75%) |
| None | (no text) |

### Size
- **Bar width:** 60 to 240
- **Bar height:** 32 to 100

### Target window
Show or hide a separate Target square. It has its own frame and moves on its own with Alt + drag.

### Click healing
Type a spell name for any mouse button, with or without **Shift**, **Alt** or **Ctrl**:
left click, right click, wheel click, side button 1 and side button 2. That's 20 slots.

### Mouse wheel
Set a spell for wheel up and wheel down, with or without Shift, Alt or Ctrl.

### Hover keys
Up to 4 keyboard keys. Press the key while your mouse is over a square to cast that spell on that player.

### Defaults (priest)

| Action | Spell |
|---|---|
| Shift + left click | Flash Heal |
| Alt + left click | Lesser Heal |
| Right click | Dispel Magic |
| Wheel click | Power Word: Fortitude |
| Wheel up | Lesser Heal |
| Wheel down | Flash Heal |

Click **Save** in the settings window to keep your changes.

Author: Audrey (Waterys419)
