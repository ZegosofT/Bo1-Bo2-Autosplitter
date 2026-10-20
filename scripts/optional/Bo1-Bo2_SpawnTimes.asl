# ⏱️ Last Spawn Display (`Bo1-Bo2_SpawnTimes.asl`)

A secondary, standalone LiveSplit Auto Splitter (ASL) script that dynamically displays the expected **last zombie spawn time** for the current round (Rounds 1 to 20) at the very top of your LiveSplit layout.

<p align="center">
  <img src="../../assets/images/Bo1-Bo2_SpawnTimes.png" alt="Bo1-Bo2 Spawn Times Preview" width="300" style="border-radius: 8px;">
</p>

---

## 📥 Download

* **Script File:** [Bo1-Bo2_SpawnTimes.asl](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl)

---

## ✨ How It Works

- **Split Index Based Tracking:** The script uses LiveSplit's current split index ($X = \text{CurrentSplitIndex} + 1$) to determine the active round.
- **Format `X (y)`:** Displays the current round $X$ along with its corresponding spawn time $y$ from the lookup table (retrieved using key $X + 1$)[cite: 5].
  - *Example (Solo):* Split 1 $\rightarrow$ `1 (10.5)`, Split 2 $\rightarrow$ `2 (14.0)`[cite: 5].
- **Automatic Solo vs. Coop Detection:** Automatically switches between Solo and 2-Player (Coop) spawn time tables by reading your selected LiveSplit comparison, category, or game name (detects `"Coop"`)[cite: 5].
- **Auto-Inject & Auto-Remove:** 
  - Automatically creates and inserts its own text component at the **very top** of your layout[cite: 5].
  - Automatically removes the component once you pass Round 20 ($X > 20$)[cite: 5].
  - Cleanly restores and recreates the component at Round 1 whenever the run resets[cite: 5].

---

## 🛠️ Installation & Setup

1. **Download the script:** Download [`Bo1-Bo2_SpawnTimes.asl`](https://github.com/ZegosofT/Bo1-Bo2-Autosplitter/releases/download/v0.9.0/Bo1-Bo2_SpawnTimes.asl) from the official release[cite: 3].
2. **Add Scriptable Auto Splitter in LiveSplit:**
   - Right-click LiveSplit $\rightarrow$ **Edit Layout...**[cite: 3]
   - Click **`+`** $\rightarrow$ **Control** $\rightarrow$ **Scriptable Auto Splitter** (add a second instance alongside your main autosplitter)[cite: 3].
   - Double-click it, click **Browse**, and select `Bo1-Bo2_SpawnTimes.asl`[cite: 3].
3. **No Layout Configuration Needed!** The script handles text component creation, positioning, alignment, and deletion dynamically in code[cite: 5].

---

[⬅️ Back to Main Documentation](../../README.md)