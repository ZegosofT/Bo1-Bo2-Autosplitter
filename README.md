# BO1 & BO2 Zombies Auto Splitter (Plutonium / Steam / BGamer)

A combined LiveSplit Auto Splitter (ASL) script for *Call of Duty: Black Ops* (BO1) and *Call of Duty: Black Ops II* (BO2) Zombies, designed for LiveSplit 1.8.37 and above.

<p align="center">
  <a href="https://www.youtube.com/watch?v=__2ye51dt4s" target="_blank">
    <img src="https://img.youtube.com/vi/__2ye51dt4s/maxresdefault.jpg" alt="Video Tutorial" width="600" style="border-radius: 8px;">
  </a>
  <br>
  <strong>🎬 <a href="https://www.youtube.com/watch?v=__2ye51dt4s" target="_blank">Watch the Video Setup Tutorial on YouTube</a></strong>
</p>

<p align="center">
  <a href="https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/bo1-bo2_Autosplitter.asl">
    <img src="https://img.shields.io/badge/Download-Main_ASL-blue?style=for-the-badge&logo=github" alt="Download Main ASL">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl">
    <img src="https://img.shields.io/badge/Download-SpawnTimes_ASL-purple?style=for-the-badge&logo=github" alt="Download SpawnTimes ASL">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_Layout.lsl">
    <img src="https://img.shields.io/badge/Download-Layout_.lsl-green?style=for-the-badge&logo=github" alt="Download Layout">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_FirstRoom_Splits.lss">
    <img src="https://img.shields.io/badge/Download-Splits_.lss-orange?style=for-the-badge&logo=github" alt="Download Splits">
  </a>
</p>

---

## How to Install

### 1. Download LiveSplit
If you haven't already, download and install the latest version of LiveSplit from the official website: [LiveSplit Website](https://livesplit.org/).

### 2. Add the Auto Splitter Script
1. Open **LiveSplit**.
2. Right-click LiveSplit and select **Edit Layout...**
3. Click the **`+`** icon, go to **Control**, and select **Scriptable Auto Splitter**.
4. Double-click the newly added **Scriptable Auto Splitter** component in your layout editor.
5. Under the script settings, click **Browse** and select your script file (you can download [bo1-bo2_Autosplitter.asl](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/bo1-bo2_Autosplitter.asl) directly from the release).

*Note: Once added, the script will automatically create two text components in your layout: **Game Timer** and **Round**. You can remove the default LiveSplit **Timer** component, as the script provides its own.*

### 3. Use the Speedrun Layout (Recommended)
To get the layout already fully configured for speedrunning:
1. Download the layout file directly: [Bo1-Bo2_Layout.lsl](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_Layout.lsl).
2. In LiveSplit, right-click and select **Open Layout...**
3. Choose the downloaded `Bo1-Bo2_Layout.lsl` file.

### 4. Import the First Room Splits
To load the standardized round splits for First Room runs:
1. Download the splits file directly from the release: [Bo1-Bo2_FirstRoom_Splits.lss](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_FirstRoom_Splits.lss).
2. In LiveSplit, right-click and select **Open Splits...** -> **From File...**
3. Select your downloaded `Bo1-Bo2_FirstRoom_Splits.lss` file.

### 5. Co-op / Non-Host Setup: TimerSync (Optional Tool)
Since the auto splitter reads game memory locally, it only runs on the **host's** machine during co-op games. If you are playing co-op as a non-host player and want your LiveSplit timer to automatically stay synchronized with the host, you can install [LiveSplit.TimerSync by oJumpy](https://github.com/oJumpy/LiveSplit.TimerSync).
*(Place the downloaded `.dll` file directly inside your LiveSplit `Components` folder).*

---

## 🧩 Optional Scripts & Add-ons

We provide standalone ASL scripts to enhance your LiveSplit display without interfering with main splits[cite: 5]:

* **[⏱️ Spawn Times Display (`Bo1-Bo2_SpawnTimes.asl`)](./docs/optional-scripts/last-spawn-times.md)**: Zero-setup script that automatically injects a text component at the top of your layout showing expected zombie spawn times `X (y)` for rounds 1 to 20 based on your current split index and game mode (Solo / Coop)[cite: 5].

---

## Important Note for Black Ops 1
Immediately after loading any map for the first time, you **must** do a **Fast Restart** or **Restart Level** (`fast_restart` command or in-game restart). 
- *Why?* The Black Ops engine often skips its initial memory write to the round-change HUD flag during a fresh map load, which would prevent the first round splits from triggering properly. 
- Restarting forces proper memory initialization and standardizes player control timing at ~3.4s.

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

## Credits

- [oJumpy](https://github.com/oJumpy) for developing [LiveSplit.TimerSync](https://github.com/oJumpy/LiveSplit.TimerSync), making co-op timer synchronization seamless for non-host players.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.