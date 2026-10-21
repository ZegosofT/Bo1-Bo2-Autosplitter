# Last Spawn Display (`Bo1-Bo2_SpawnTimes.asl`)

A secondary, standalone LiveSplit Auto Splitter (ASL) script that dynamically displays the expected **last zombie spawn time** for the current round (Rounds 1 to 20) at the very top of your LiveSplit layout.

<p align="center">
  <img src="../../assets/images/Bo1-Bo2_SpawnTimes.png" alt="Bo1-Bo2 Spawn Times Preview" width="180" style="border-radius: 6px;">
</p>

---

## Installation

1. Download [`Bo1-Bo2_SpawnTimes.asl`](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl).
2. In LiveSplit, right-click -> **Edit Layout...**
3. Click **`+`** -> **Control** -> **Scriptable Auto Splitter** (add a second instance alongside your main autosplitter).
4. Double-click it, click **Browse**, and select `Bo1-Bo2_SpawnTimes.asl`.
5. Click **OK**. The spawn time text line will appear at the top of your layout automatically!

---

## Features & How It Works

- **Zero-Setup Auto-Injection:** You do **not** need to manually add or configure any text component in LiveSplit. The script creates and inserts its own text component at the **very top** of your layout automatically.
- **Split Index Tracking:** Uses your current LiveSplit split index ($X = \text{CurrentSplitIndex} + 1$) to determine the active round.
- **Formatted Display `X (y)`:** Displays the current round $X$ alongside its calculated spawn time $y$ (e.g., `1 (10.5)` for Round 1 in Solo, `1 (12.3)` in 2P Coop).
- **Auto Solo / Coop Detection:** Reads your selected LiveSplit comparison (**Compare Against**), then the category name, then the game name. The first one that contains `"Solo"` or `"Coop"` (case-insensitive) decides which spawn table is used. If none of them contains either word, the Solo table is used. Changing the comparison switches the table immediately, without reloading the script.
- **Automatic Cleanup:** Automatically deletes the text component from your layout once you pass Round 20 ($X > 20$) and recreates it cleanly at Round 1 upon resetting.

---

## Configuration Options

You can edit the script parameters at the top of the `startup` block:

```csharp
vars.MAX_X = 20;          // The component is removed once the round goes above this value
vars.SPAWN_PAD = 0;       // Number of spaces added to the left of the text for split alignment
vars.FONT_SIZE = 9f;      // Font size in points (0f keeps the layout font)
```

`vars.FONT_SIZE` is re-applied every time the text is updated, so it is kept even when the component is recreated (reset, fast restart, ...). If the text looks clipped, lower the value.

The spawn times are stored in `vars.spawnTimes` (Solo) and `vars.spawnTimes2P` (Coop). In both tables, the key is the next split number (`X + 1`) and the displayed number is `key - 1`. If a round has no entry in the table, `X (?)` is displayed.

---

## Troubleshooting & Limitations

- **Greyed-out Start / Split / Reset Checkboxes:** This is expected. The script is purely a display companion and contains no execution blocks for timer actions.
- **Component Not Displaying:** Verify that your game process (`plutonium-bootstrapper-win32`, `BlackOps`, or `BGamerT5`) is running, and that your split file starts at Round 1 (split index 0).
- **Wrong Spawn Table:** Check that the name of your selected comparison contains `"Solo"` or `"Coop"`.
- **Limitations:** Alignment spaces (`SPAWN_PAD`) are approximate depending on the font size. Split skipping or reordering will shift the active round index.

---

[Back to Main Documentation](../../README.md)