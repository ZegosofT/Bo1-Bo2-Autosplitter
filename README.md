# BO1 & BO2 Zombies Auto Splitter (Plutonium / Steam / BGamer)

A combined LiveSplit Auto Splitter (ASL) script for *Call of Duty: Black Ops* (BO1) and *Call of Duty: Black Ops II* (BO2) Zombies, designed for LiveSplit 1.8.37 and above.

---

## How to Install

### 1. Download LiveSplit
If you haven't already, download and install the latest version of LiveSplit from the official website: [LiveSplit Website](https://livesplit.org/).

### 2. Add the Auto Splitter Script
1. Open **LiveSplit**.
2. Right-click LiveSplit and select **Edit Layout...**
3. Click the **`+`** icon, go to **Control**, and select **Scriptable Auto Splitter**.
4. Double-click the newly added **Scriptable Auto Splitter** component in your layout editor.
5. Under the script settings, click **Browse** and select your `Bo1-Bo2_Autosplitter.asl` file.

*Note: Once added, the script will automatically create two text components in your layout: **Game Timer** and **Round**.*

### 3. Use the Speedrun Layout (Recommended)
To get the layout already fully configured for speedrunning:
1. Download the **`Bo1-Bo2_Layout.lsl`** file from this repository.
2. In LiveSplit, right-click and select **Open Layout...**
3. Choose the downloaded `Bo1-Bo2_Layout.lsl` file.

---

## Overview of Components

When you use the autosplitter, two distinct lines appear in your layout:
- **Game Timer**: Displays the active game time for your run, pausing automatically during loading screens or native in-game pauses.
- **Round**: Displays the custom timer for the current round (freezes when the last zombie dies and restarts when the next round begins).

---

## How It Works (For Players)

### 1. Game Detection Logic
The script supports both BO1 and BO2 (especially via Plutonium, which runs both games under the same process). 
- At startup, the script watches the time counters of both games.
- The first counter that starts progressing determines which game you are playing. 
- Once detected, the choice is locked for the entire duration of the game session until you close the game process.

### 2. In-Game Pause Logic
Pausing the game natively via the game's pause menu freezes the internal game clock. This naturally pauses all timers (**Game Timer** and **Round**) universally.

### 3. Memory Addresses & Game Mechanics

#### Black Ops 1 (BO1)
- **Game Time Counter (`ticks1`):** Reads the internal game timer (progressing at 50 ms per tick) to track time and handle automatic resets when starting a new map.
- **Round Change Flag (`rc1`):** Monitors the toggle state used to detect round transitions and trigger automatic round splits.

#### Black Ops 2 (BO2)
- **Game Time Counter (`ticks2`):** Tracks the internal timeline of the match, aligned with the HUD game timer starting point.
- **Round Number (`round2`):** Reads the current round value to manage round-based splits, intermissions, and animation delays when the round number updates on screen.

---

## Known Limitations

- Memory offsets are specific to tested game versions and process builds (such as specific Plutonium updates). Game patches modifying game binaries may require offset adjustments.
- The Steam and BGamer builds of BO1 do not support direct round-number memory addresses; therefore, the BO1 round timer relies on the round-change flag cycle instead.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.