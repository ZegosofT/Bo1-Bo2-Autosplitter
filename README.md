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

*Note: Once added, the script will automatically create three text components in your layout: **Lobby**, **Game Timer**, and **Round**.*

### 3. Use the Speedrun Layout (Recommended)
To get the layout already fully configured for speedrunning:
1. Download the **`Bo1-Bo2_Layout.lsl`** file from this repository.
2. In LiveSplit, right-click and select **Open Layout...**
3. Choose the downloaded `Bo1-Bo2_Layout.lsl` file.

---

## Overview of Components

When you use the autosplitter, three distinct lines appear in your layout:
- **Lobby**: Displays the raw game time based on the game's internal clock. It keeps running continuously and is **never** impacted by the manual F2 pause (though it naturally pauses if you use the game's built-in pause menu).
- **Game Timer**: Displays the active game time for your run. It automatically pauses when the game's built-in pause menu is opened, or when you trigger a [manual F2 pause](#2-understanding-pauses-in-game-pause-vs-manual-f2-pause).
- **Round**: Displays the custom timer for the current round. It freezes when the last zombie dies, restarts when the next round begins, and also respects both the game's built-in pause and the [manual F2 pause](#2-understanding-pauses-in-game-pause-vs-manual-f2-pause).

---

## How It Works (For Players)

### 1. Game Detection Logic
The script supports both BO1 and BO2 (especially via Plutonium, which runs both games under the same process). 
- At startup, the script watches the time counters of both games.
- The first counter that starts progressing determines which game you are playing. 
- Once detected, the choice is locked for the entire duration of the game session until you close the game process.

### 2. Understanding Pauses (In-Game Pause vs. Manual F2 Pause)
It is important to understand the difference between the game's native pause and the script's manual pause feature:
- **In-Game Pause (Game Menu):** Pausing the game natively via the pause menu freezes the game's internal clock. This will naturally pause all timers (**Lobby**, **Game Timer**, and **Round**) universally.
- **Manual Pause (F2 Key):** Pressing **F2** during a run acts as a speedrun utility. It will freeze the **Game Timer** and the **Round** timer *while keeping the underlying game running*. The script automatically compensates for the paused ticks once you press **F2** again to resume. *(Note: The Lobby timer remains completely raw and ignores the F2 pause).*
- LiveSplit resets or game restarts automatically clear any active F2 pause state.

### 3. Memory Addresses & Game Mechanics

#### Black Ops 1 (BO1)
- **Game Time Counter (`ticks1`):** Reads the internal game timer (progressing at 50 ms per tick) to track time and handle automatic resets when starting a new map.
- **Round Change Flag (`rc1`):** Monitors the toggle state used to detect round transitions and trigger automatic round splits.

#### Black Ops 2 (BO2)
- **Game Time Counter (`ticks2`):** Tracks the internal timeline of the match, aligned with the HUD game timer starting point.
- **Round Number (`round2`):** Reads the current round value to manage round-based splits, intermissions, and animation delays when the round number updates on screen.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.