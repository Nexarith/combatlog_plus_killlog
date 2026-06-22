# combatlog_plus_killlog

<img width="1254" height="1254" alt="combatlog_plus_killlog_cover" src="https://github.com/user-attachments/assets/c07be739-240f-49b9-961a-3fde504b8e68" />

A PvP system modpack for Minetest/Luanti that combines combat tracking, kill feed logging, combat tagging, and anti-combat-logging protection.

---

## Overview

`combatlog_plus_killlog` is designed for PvP-heavy servers. It tracks player combat interactions, records kills with context, displays a live kill feed HUD, and enforces penalties for combat logging (leaving during active combat).

It also provides a searchable 24-hour kill log UI for players.

---

## Features

### ⚔️ Kill Log System
- Live kill feed HUD (top recent kills)
- Weapon tracking for each kill
- Death type detection:
  - PvP kills
  - Suicide
  - Lava deaths
  - Void deaths
  - Fall damage
  - Combat log deaths
  - Assist kills
- 24-hour searchable kill history UI
- `/kill_log` command to open UI

---

### Combat Tracking System
- PvP combat timer system (default: 30 seconds)
- “Combat” HUD indicator while in fight
- Shared combat state for both attacker and victim
- Automatic combat refresh on hit

---

### Anti-Combat Logging
- Detects when a player leaves during combat
- Forces inventory drop on logout
- Records combat log penalty in kill feed
- Optional armor support for `3d_armor`
- Wipes inventory on rejoin if combat-logged

---

### HUD Systems
- Kill feed overlay (max 6 entries shown)
- Combat status indicator with countdown timer
- Real-time updates for all players

---

## Commands

### `/kill_log`
Opens the 24-hour kill history interface.

---

## Dependencies

### Required
- Minetest / Luanti 5.0+

### Optional
- `3d_armor` (armor support for inventory drop system)

---

## How It Works

- When players hit each other, combat is triggered
- Combat lasts for a short time after last hit
- If a player dies, the system tries to determine:
  - Who hit last
  - What weapon was used
  - What caused death (lava, void, fall, PvP, etc.)

If a player leaves mid-combat:
- Their inventory is dropped
- A combat log penalty is recorded
- The attacker may be credited if tracked

---

## Server Use

This modpack is intended for:
- PvP servers
- FFA arenas
- Survival PvP worlds
- Hardcore multiplayer environments

---

## Notes

- Uses global tables for cross-mod compatibility (`_G.last_hitter`, `_G.add_kill`)
- Designed to be lightweight but server-authoritative
- Not intended for single-player gameplay balance

---

## Author
Nexarith

---

## Version
1.0.0
