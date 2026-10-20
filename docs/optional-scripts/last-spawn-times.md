# ⏱️ Last Spawn Display (`Bo1-Bo2_SpawnTimes.asl`)

A secondary, standalone LiveSplit Auto Splitter (ASL) script that dynamically displays the expected **last zombie spawn time** for the current round (Rounds 1 to 20) at the very top of your LiveSplit layout[cite: 5].

<p align="center">
  <img src="../../assets/images/Bo1-Bo2_SpawnTimes.png" alt="Bo1-Bo2 Spawn Times Preview" width="300" style="border-radius: 8px;">
</p>

---

## 📥 Download

* **Script File:** [Bo1-Bo2_SpawnTimes.asl](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl)[cite: 3]

---

## ✨ Features & How It Works

- **Zero-Setup Auto-Injection:** You do **not** need to manually add or configure any text component in LiveSplit[cite: 5]. The script creates and inserts its own text component at the **very top** of your layout automatically[cite: 5].
- **Split Index Tracking:** Uses your current LiveSplit split index ($X = \text{CurrentSplitIndex} + 1$) to determine the active round[cite: 5].
- **Formatted Display `X (y)`:** Displays the current round $X$ alongside its calculated spawn time $y$ (e.g., `1 (10.5)` for Round 1 in Solo, `1 (12.3)` in 2P Coop)[cite: 5].
- **Auto Solo / Coop Detection:** Reads your selected LiveSplit comparison, category, or game name to automatically switch between Solo and 2-Player Coop spawn tables (detects `"Coop"`)[cite: 5].
- **Automatic Cleanup:** Automatically deletes the text component from your layout once you pass Round 20 ($X > 20$) and recreates it cleanly at Round 1 upon resetting[cite: 5].

---

## 🛠️ Installation

1. Download [`Bo1-Bo2_SpawnTimes.asl`](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl)[cite: 3].
2. In LiveSplit, right-click $\rightarrow$ **Edit Layout...**[cite: 3]
3. Click **`+`** $\rightarrow$ **Control** $\rightarrow$ **Scriptable Auto Splitter** (add a second instance alongside your main autosplitter)[cite: 3].
4. Double-click it, click **Browse**, and select `Bo1-Bo2_SpawnTimes.asl`[cite: 3].
5. Click **OK**. The spawn time text line will appear at the top of your layout automatically![cite: 5]

---

[⬅️ Back to Main Documentation](../../README.md)