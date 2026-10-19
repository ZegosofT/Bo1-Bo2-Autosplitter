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
- **Game Timer**: Displays the active game time for your run. It automatically pauses during loading screens, when the game's built-in pause menu is opened, or when you trigger a [manual pause](#2-understanding-pauses-in-game-pause-vs-manual-pause).
- **Round**: Displays the custom timer for the current round. It freezes when the last zombie dies, restarts when the next round begins, and also respects both the game's built-in pause and the [manual pause](#2-understanding-pauses-in-game-pause-vs-manual-pause).

---

## How It Works (For Players)

### 1. Game Detection Logic
The script supports both BO1 and BO2 (especially via Plutonium, which runs both games under the same process). 
- At startup, the script watches the time counters of both games.
- The first counter that starts progressing determines which game you are playing. 
- Once detected, the choice is locked for the entire duration of the game session until you close the game process.

### 2. Understanding Pauses (In-Game Pause vs. Manual Pause)
It is important to understand the difference between the game's native pause and the script's manual pause feature:
- **In-Game Pause (Game Menu):** Pausing the game natively via the pause menu freezes the game's internal clock. This will naturally pause all timers (**Lobby**, **Game Timer**, and **Round**) universally.
- **Manual Pause (Default: F2 Key):** Pressing the assigned key during a run acts as a speedrun utility. It will freeze the **Game Timer** and the **Round** timer *while keeping the underlying game running*. The script automatically compensates for the paused ticks once you press the key again to resume. *(Note: The Lobby timer remains completely raw and ignores this pause).*
- LiveSplit resets or game restarts automatically clear any active manual pause state.

### 3. Customizing the Manual Pause Key
By default, the manual pause is bound to the **F2** key. If you wish to change it to another key:
1. Open your `Bo1-Bo2_Autosplitter.asl` file with any text editor (like Notepad).
2. Look for this line near the top (inside the `startup` section):
   ```csharp
   vars.PAUSE_VK = 0x71; // F2