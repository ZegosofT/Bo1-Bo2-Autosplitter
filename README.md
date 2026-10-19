# BO1 & BO2 Zombies Auto Splitter (Plutonium / Steam / BGamer)

A combined LiveSplit Auto Splitter (ASL) script for *Call of Duty: Black Ops* (BO1) and *Call of Duty: Black Ops II* (BO2) Zombies, designed for LiveSplit 1.8.37 and above.

---

## How to Install

### 1. Download LiveSplit
If you haven't already, download and install the latest version of LiveSplit from the official website: [Livesplit Website](https://livesplit.org/).

### 2. Add the Auto Splitter Script
1. Open **LiveSplit**.
2. Right-click LiveSplit and select **Edit Layout...**
3. Click the **`+`** icon, go to **Control**, and select **Scriptable Auto Splitter**.
4. Double-click the newly added **Scriptable Auto Splitter** component in your layout editor.
5. Under the script settings, click **Browse** and select your `Bo1-Bo2_Autosplitter.asl` file.
6. Ensure your timing method is set to **Game Time** (LiveSplit will prompt you to set this automatically if it isn't already).

### 3. Use the Speedrun Layout (Recommended)
To get the layout already fully configured for speedrunning (including the proper Text components for Round and Lobby timers):
1. Download the **`Bo1-Bo2_Layout.lsl`** file from this repository.
2. In LiveSplit, right-click and select **Open Layout...**
3. Choose the downloaded `Bo1-Bo2_Layout.lsl` file.

---

## Features

- **Automatic Game Detection:** Automatically detects whether you are playing BO1 or BO2 based on the active memory counters (with priority given to BO1 if both change simultaneously). The detection locks for the lifetime of the process.
- **Game Time Support:** The LiveSplit timer follows the game's internal time counter, automatically pausing during loading screens or game pauses.
- **Custom Round Timer:** Automatically creates and updates a LiveSplit **Text** component named `Round` displaying the current round's duration (freezing when the last zombie dies and restarting when the next round begins).
- **Lobby Timer:** A second LiveSplit **Text** component named `Lobby` tracking raw game time.
- **Automatic Splitting:** One split per round.
  - **BO1:** Triggers when the round timer restarts.
  - **BO2:** Triggers when the new round number appears on screen (accounting for round number display animation delays).
- **Manual Pause (F2):** Press **F2** to pause/resume the game timer and round timer manually during a run. The game counter keeps running, and the script automatically compensates for the paused ticks upon resume.

## Supported Processes & Environments

- **Plutonium:** `plutonium-bootstrapper-win32.exe` (Supports both BO1 and BO2)
- **Steam (BO1):** `BlackOps.exe`
- **BGamer (BO1):** `BGamerT5.exe`

## Text Components Configuration

If you are setting up your own layout instead of using the provided `.lsl` file, the script automatically creates and manages two LiveSplit Text components if they don't already exist:
- **`Round`**: Displays the active round timer.
- **`Lobby`**: Displays raw game time.

## Manual Pause Usage

- Press **F2** while a run is active to pause the timers. Press **F2** again to resume. 
- *Note:* LiveSplit resets or game restarts automatically clear the pause state.

## Known Limitations

- Memory offsets are specific to the tested game versions and process builds. Game updates that modify game binaries may require offset adjustments.
- The Steam and BGamer builds of BO1 do not support round-number memory addresses; therefore, the BO1 round timer relies on the round-change flag (`rc1`) cycle.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.