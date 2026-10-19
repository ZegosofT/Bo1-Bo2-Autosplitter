// =============================================================================
// Call of Duty: Black Ops 1 + Black Ops 2 Zombies (Plutonium)
// One LiveSplit Auto Splitter (ASL) script for both games.
// Written for LiveSplit 1.8.37 and its "Scriptable Auto Splitter" component.
// =============================================================================
//
// WHAT IT DOES
//   Game Timer  : a LiveSplit Text component ("Game Timer") created by the script
//                 that tracks the game's internal active time counter.
//   Round Timer : a LiveSplit Text component ("Round") created automatically
//                 that measures the current round duration.
//   Splits      : one split per round.
//
// SUPPORTED PROCESSES
//   Plutonium : "plutonium-bootstrapper-win32.exe", BO1 and BO2.
//   Steam     : "BlackOps.exe", BO1 only.
//   BGamer    : "BGamerT5.exe", BO1 only.
// =============================================================================

state("plutonium-bootstrapper-win32")
{
    // --- BO1 ---
    int ticks1 : 0x1679870; // game time counter, +20 per second (1 tick = 50 ms)
    byte rc1 : 0x165695D;   // round change flag, toggles around each round transition
    // --- BO2 ---
    int ticks2 : 0x1DC155C;   // game time counter, +20 per second (1 tick = 50 ms)
    byte round2 : 0x1F3B710;  // current round number
}

state("BlackOps")
{
    int ticks1 : 0x1679870;
    byte rc1 : 0x165695D;
}

state("BGamerT5")
{
    int ticks1 : 0x1679870;
    byte rc1 : 0x165695D;
}

startup
{
    refreshRate = 20; // 50 ms ticks
    timer.CurrentTimingMethod = TimingMethod.GameTime;

    // ===== Game identifiers =====
    vars.GAME_UNKNOWN = 0;
    vars.GAME_BO1 = 1;
    vars.GAME_BO2 = 2;

    // ===== BO1 constants =====
    vars.FIRST_DELAY_MS = 7233.3;
    vars.NEXT_DELAY_MS = 0.0;

    // ===== BO2 constants =====
    vars.START_TICKS2 = 146;
    vars.INTERMISSION_TICKS2 = 250;
    vars.FIRST_ROUND_INTERMISSION_TICKS2 = 166;
    vars.TimerModel = new TimerModel { CurrentState = timer };

    // ===== Game detection state =====
    vars.detectedGame = vars.GAME_UNKNOWN;
    vars.prevTicks1 = -1;
    vars.prevTicks2 = -1;

    // ===== Time formatting =====
    vars.FormatMs = (Func<double, string>)(ms =>
    {
        if (ms < 0) ms = 0;
        int cs = (int)(ms / 10.0);
        int hundredths = cs % 100;
        int secs = (cs / 100) % 60;
        int mins = cs / 6000;
        return mins.ToString() + ":" + (secs < 10 ? "0" : "") + secs.ToString() + "." + (hundredths < 10 ? "0" : "") + hundredths.ToString();
    });

    vars.FormatTicks2 = (Func<int, string>)(t =>
    {
        var ts = TimeSpan.FromMilliseconds(t * 50);
        if (ts.TotalHours >= 1) return ts.ToString(@"h\:mm\:ss\.ff");
        if (ts.TotalMinutes >= 1) return ts.ToString(@"m\:ss\.ff");
        return ts.ToString(@"s\.ff");
    });

    // ===== "Text" components manager =====
    vars.textCache = new Dictionary<string, object>();

    vars.FindOrCreateText = (Func<string, object>)(id =>
    {
        object found = timer.Layout.Components
            .Where(x => x.GetType().Name == "TextComponent")
            .Select(x => x.GetType().GetProperty("Settings").GetValue(x, null))
            .FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);

        if (found == null)
        {
            var asm = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
            var comp = Activator.CreateInstance(asm.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent(
                "LiveSplit.Text.dll", comp as LiveSplit.UI.Components.IComponent));
            found = comp.GetType()
                .GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public)
                .GetValue(comp, null);
            found.GetType().GetProperty("Text1").SetValue(found, id, null);
        }
        return found;
    });

    vars.SetText = (Action<string, string>)((id, val) =>
    {
        var cache = (Dictionary<string, object>)vars.textCache;
        object setting;
        if (!cache.TryGetValue(id, out setting))
        {
            setting = vars.FindOrCreateText(id);
            cache[id] = setting;
        }
        setting.GetType().GetProperty("Text2").SetValue(setting, val, null);
    });

    vars.textFailed = false;
    vars.lastText = "";
    vars.lastGameText = "";

    // Force creation order immediately on startup (Game Timer -> Round)
    vars.FindOrCreateText("Game Timer");
    vars.FindOrCreateText("Round");
}

init
{
    string processName = "";
    try { processName = game.ProcessName.ToLowerInvariant(); } catch (Exception) { }
    bool isPlutonium = processName == "" || processName.StartsWith("plutonium");
    vars.detectedGame = isPlutonium ? vars.GAME_UNKNOWN : vars.GAME_BO1;
    vars.prevTicks1 = -1;
    vars.prevTicks2 = -1;

    // ===== BO1 state =====
    vars.hasPrev = false;
    vars.lastTicks = 0;
    vars.lastRc = 0;
    vars.rtState = 0;
    vars.rtStartMs = 0.0;
    vars.rtFrozenMs = 0.0;
    vars.rtPendingAtMs = 0.0;
    vars.roundTimeMs = 0.0;
    vars.splitReady = false;
    vars.lastRoundTimeMs = 0.0;
    vars.lastSegmentMs = 0.0;

    // ===== BO2 state =====
    vars.firstUpdate2 = true;
    vars.awaitingStart2 = true;
    vars.phase2 = 0;
    vars.roundStart2 = 0;
    vars.flipTicks2 = 0;
    vars.frozen2 = 0;
    vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
    vars.pendingSplit2 = false;
    vars.splitAtTicks2 = 0;
    vars.lastSplitRound2 = 1;
    vars.alignPending2 = false;
    vars.alignTarget2 = 0;
}

update
{
    // ----- Game detection -----
    if ((int)vars.detectedGame == (int)vars.GAME_UNKNOWN)
    {
        int t1 = Convert.ToInt32((object)current.ticks1);
        int t2 = Convert.ToInt32((object)current.ticks2);
        int p1 = (int)vars.prevTicks1;
        int p2 = (int)vars.prevTicks2;

        bool bo1Changed = (p1 >= 0 && t1 != p1);
        bool bo2Changed = (p2 >= 0 && t2 != p2);

        vars.prevTicks1 = t1;
        vars.prevTicks2 = t2;

        if (bo1Changed)
            vars.detectedGame = vars.GAME_BO1;
        else if (bo2Changed)
            vars.detectedGame = vars.GAME_BO2;
    }

    bool runBO1 = ((int)vars.detectedGame == (int)vars.GAME_BO1);

    // ----- BO1 -----
    if (runBO1)
    {
        int ticksNow = Convert.ToInt32((object)current.ticks1);
        int rcNow = (Convert.ToInt32((object)current.rc1) != 0) ? 1 : 0;
        double nowMs = ticksNow * 50.0;

        vars.splitReady = false;

        int st = vars.rtState;
        double startMs = vars.rtStartMs;
        double frozenMs = vars.rtFrozenMs;
        double pendingAt = vars.rtPendingAtMs;

        bool restart = false;
        bool flipUp = false;
        bool flipDown = false;

        if (vars.hasPrev)
        {
            if (ticksNow < vars.lastTicks) restart = true;
            if (rcNow == 1 && vars.lastRc == 0) flipUp = true;
            if (rcNow == 0 && vars.lastRc == 1) flipDown = true;
        }
        vars.hasPrev = true;
        vars.lastTicks = ticksNow;
        vars.lastRc = rcNow;

        if (restart)
        {
            st = 1;
            startMs = 0.0;
            frozenMs = 0.0;
            pendingAt = 0.0;
        }
        else
        {
            switch (st)
            {
                case 0:
                    if (flipUp) st = 5;
                    break;
                case 1:
                    if (flipUp) st = 2;
                    break;
                case 2:
                    if (flipDown)
                    {
                        pendingAt = nowMs + vars.FIRST_DELAY_MS;
                        st = 3;
                    }
                    break;
                case 3:
                case 8:
                    if (flipUp) st = 5;
                    break;
                case 4:
                    if (flipUp)
                    {
                        frozenMs = nowMs - startMs;
                        st = 5;
                    }
                    break;
                case 5:
                    if (flipDown) st = 6;
                    break;
                case 6:
                    if (flipUp) st = 7;
                    break;
                case 7:
                    if (flipDown)
                    {
                        pendingAt = nowMs + vars.NEXT_DELAY_MS;
                        st = 8;
                    }
                    break;
            }
        }

        if (st == 3 || st == 8)
        {
            if (nowMs >= pendingAt)
            {
                if (st == 8)
                {
                    vars.splitReady = true;
                    vars.lastRoundTimeMs = frozenMs;
                    vars.lastSegmentMs = pendingAt - startMs;
                }
                startMs = pendingAt;
                frozenMs = 0.0;
                st = 4;
            }
        }

        double rms = (st == 4) ? (nowMs - startMs) : frozenMs;
        if (rms < 0) rms = 0;

        vars.rtState = st;
        vars.rtStartMs = startMs;
        vars.rtFrozenMs = frozenMs;
        vars.rtPendingAtMs = pendingAt;
        vars.roundTimeMs = rms;

        string txt = vars.FormatMs(rms);

        if (!vars.textFailed)
        {
            try
            {
                if (txt != (string)vars.lastText)
                {
                    vars.lastText = txt;
                    vars.SetText("Round", txt);
                }
            }
            catch (Exception e)
            {
                vars.textFailed = true;
                MessageBox.Show("BO1 autosplitter: cannot update the Round text line.\n\n" + e.ToString(), "BO1/BO2 autosplitter");
            }
        }
    }

    // ----- BO2 -----
    else
    {
        if (vars.firstUpdate2)
        {
            vars.firstUpdate2 = false;
            vars.awaitingStart2 = current.ticks2 < (int)vars.START_TICKS2;
        }

        if (current.ticks2 < old.ticks2)
        {
            vars.phase2 = 0;
            vars.frozen2 = 0;
            vars.awaitingStart2 = true;
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
            vars.pendingSplit2 = false;
            vars.splitAtTicks2 = 0;
            vars.lastSplitRound2 = 1;
            vars.alignPending2 = false;
        }

        if (vars.awaitingStart2 && current.round2 > 0 && current.round2 != old.round2)
        {
            vars.awaitingStart2 = false;
            vars.lastSplitRound2 = current.round2;
            if (current.round2 >= 2)
            {
                vars.alignPending2 = true;
                vars.alignTarget2 = current.round2 - 1;
            }
            vars.phase2 = 2;
            vars.frozen2 = 0;
            vars.flipTicks2 = current.ticks2;
            vars.nextIntermissionTicks2 = vars.FIRST_ROUND_INTERMISSION_TICKS2;
        }

        if (old.ticks2 < (int)vars.START_TICKS2 && current.ticks2 >= (int)vars.START_TICKS2
            && vars.awaitingStart2 && current.round2 > 0)
        {
            vars.awaitingStart2 = false;
            vars.lastSplitRound2 = current.round2;
            if (current.round2 >= 2)
            {
                vars.alignPending2 = true;
                vars.alignTarget2 = current.round2 - 1;
            }
            vars.phase2 = 2;
            vars.frozen2 = 0;
            vars.flipTicks2 = current.ticks2;
            vars.nextIntermissionTicks2 = vars.FIRST_ROUND_INTERMISSION_TICKS2;
        }

        if (vars.alignPending2 && timer.CurrentPhase == TimerPhase.Running)
        {
            int guard = 0;
            while (timer.CurrentSplitIndex < (int)vars.alignTarget2
                   && timer.CurrentSplitIndex < timer.Run.Count - 1 && guard < 300)
            {
                vars.TimerModel.SkipSplit();
                guard++;
            }
            vars.alignPending2 = false;
        }

        if (!vars.awaitingStart2 && current.round2 > old.round2 && old.round2 > 0)
        {
            if (vars.phase2 == 1)
                vars.frozen2 = (int)current.ticks2 - (int)vars.roundStart2;
            else if (vars.phase2 == 0)
                vars.frozen2 = 0;
            vars.phase2 = 2;
            vars.flipTicks2 = current.ticks2;
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;

            if (current.round2 >= 2 && current.round2 > vars.lastSplitRound2)
            {
                int animTicks = 180;
                if (current.round2 >= 100) animTicks = 80;
                else if (current.round2 >= 80) animTicks = 100;
                else if (current.round2 >= 60) animTicks = 120;
                else if (current.round2 >= 40) animTicks = 140;
                else if (current.round2 >= 20) animTicks = 160;

                vars.pendingSplit2 = true;
                vars.splitAtTicks2 = current.ticks2 + animTicks;
            }
        }

        if (vars.phase2 == 2 && current.ticks2 - vars.flipTicks2 >= (int)vars.nextIntermissionTicks2)
        {
            vars.phase2 = 1;
            vars.roundStart2 = (int)vars.flipTicks2 + (int)vars.nextIntermissionTicks2;
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
        }

        int shown2 = 0;
        if (vars.phase2 == 1) shown2 = (int)current.ticks2 - (int)vars.roundStart2;
        else if (vars.phase2 == 2) shown2 = vars.frozen2;
        if (shown2 < 0) shown2 = 0;

        string text2 = vars.FormatTicks2(shown2);
        if (text2 != vars.lastText && !vars.textFailed)
        {
            vars.lastText = text2;
            try
            {
                vars.SetText("Round", text2);
            }
            catch (Exception e)
            {
                vars.textFailed = true;
                MessageBox.Show("BO2 autosplitter: cannot update the Round text line.\n\n" + e.Message, "BO1/BO2 autosplitter");
            }
        }
    }

    // ----- Game Timer -----
    if (!vars.textFailed)
    {
        try
        {
            string gameTxt;
            if (runBO1)
            {
                int raw1 = Convert.ToInt32((object)current.ticks1);
                gameTxt = vars.FormatMs((raw1 > 0 ? raw1 : 0) * 50.0);
            }
            else
            {
                int raw2 = Convert.ToInt32((object)current.ticks2);
                int g2 = raw2 - (int)vars.START_TICKS2;
                gameTxt = vars.FormatTicks2(g2 > 0 ? g2 : 0);
            }

            if (gameTxt != (string)vars.lastGameText)
            {
                vars.lastGameText = gameTxt;
                vars.SetText("Game Timer", gameTxt);
            }
        }
        catch (Exception e)
        {
            vars.textFailed = true;
            MessageBox.Show("Autosplitter: cannot update the Game Timer text line.\n\n" + e.Message, "BO1/BO2 autosplitter");
        }
    }
}

isLoading
{
    return true;
}

gameTime
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1)
    {
        int raw1 = (int)current.ticks1;
        return TimeSpan.FromMilliseconds((raw1 > 0 ? raw1 : 0) * 50);
    }

    int raw2 = (int)current.ticks2;
    int t = raw2 - (int)vars.START_TICKS2;
    return TimeSpan.FromMilliseconds((t > 0 ? t : 0) * 50);
}

start
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1) return current.ticks1 > 0;
    return old.ticks2 < (int)vars.START_TICKS2 && current.ticks2 >= (int)vars.START_TICKS2;
}

split
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1) return vars.splitReady;
    return vars.pendingSplit2 && current.ticks2 >= (int)vars.splitAtTicks2;
}

onSplit
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1)
    {
        vars.splitReady = false;
    }
    else
    {
        vars.pendingSplit2 = false;
        vars.lastSplitRound2 = current.round2;
    }
}

reset
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1) return current.ticks1 < old.ticks1;
    return current.ticks2 < old.ticks2;
}

onReset
{
    if ((int)vars.detectedGame == (int)vars.GAME_BO1)
    {
        vars.splitReady = false;
        vars.lastRoundTimeMs = 0.0;
        vars.lastSegmentMs = 0.0;
    }
    else
    {
        vars.pendingSplit2 = false;
        vars.splitAtTicks2 = 0;
        vars.lastSplitRound2 = 1;
        vars.alignPending2 = false;
    }
}