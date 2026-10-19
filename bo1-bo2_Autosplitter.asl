// =============================================================================
// Call of Duty: Black Ops 1 + Black Ops 2 Zombies (Plutonium)
// One LiveSplit Auto Splitter (ASL) script for both games.
// Written for LiveSplit 1.8.37 and its "Scriptable Auto Splitter" component.
// =============================================================================

state("plutonium-bootstrapper-win32")
{
    // --- BO1 ---
    int ticks1 : 0x1679870;
    byte rc1 : 0x165695D;
    // --- BO2 ---
    int ticks2 : 0x1DC155C;
    byte round2 : 0x1F3B710;
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
    refreshRate = 20;
    timer.CurrentTimingMethod = TimingMethod.GameTime;

    vars.GAME_UNKNOWN = 0;
    vars.GAME_BO1 = 1;
    vars.GAME_BO2 = 2;

    vars.FIRST_DELAY_MS = 7233.3;
    vars.NEXT_DELAY_MS = 0.0;

    vars.START_TICKS2 = 146;
    vars.INTERMISSION_TICKS2 = 250;
    vars.FIRST_ROUND_INTERMISSION_TICKS2 = 166;
    vars.TimerModel = new TimerModel { CurrentState = timer };

    vars.detectedGame = vars.GAME_UNKNOWN;
    vars.prevTicks1 = -1;
    vars.prevTicks2 = -1;

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

    // ===== "Text" components manager with forced order and white text color =====
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

        // Force white color override for the right text (value)
        try
        {
            var propOverride = found.GetType().GetProperty("OverrideTextColor");
            if (propOverride != null) propOverride.SetValue(found, true, null);

            var propColor = found.GetType().GetProperty("TextColor");
            if (propColor != null) propColor.SetValue(found, Color.White, null);

            var propOverrideRight = found.GetType().GetProperty("OverrideTimeColor"); // selon les versions LiveSplit.Text
            // On gère aussi l'override global / right text color s'il existe :
            var propOverrideValueColor = found.GetType().GetProperty("OverrideWithDefaultColor");
            // Pour être sûr, on applique la couleur blanche via les propriétés standard du TextComponent :
            var setCustomColor = found.GetType().GetMethod("SetCustomColor", new Type[] { typeof(bool), typeof(Color) });
            // Sinon, l'API .NET classique des settings TextComponent gère souvent 'OverrideTextColor' et 'TextColor'.
        }
        catch (Exception) { }

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
    vars.lastLobbyText = "";

    vars.PAUSE_VK = 0x71; // F2
    vars.paused = false;
    vars.pauseStart = 0;
    vars.pauseAcc = 0;
    vars.pauseKeyDown = false;

    vars.PausedAt = (Func<int, int>)(raw =>
        (int)vars.pauseAcc + ((bool)vars.paused ? Math.Max(0, raw - (int)vars.pauseStart) : 0));

    vars.GetKey = null;
    try
    {
        var asmB = AppDomain.CurrentDomain.DefineDynamicAssembly(
            new AssemblyName("LsPauseKey"), System.Reflection.Emit.AssemblyBuilderAccess.Run);
        var modB = asmB.DefineDynamicModule("LsPauseKey");
        var typB = modB.DefineType("Native", TypeAttributes.Public | TypeAttributes.Class);
        var mB = typB.DefinePInvokeMethod("GetAsyncKeyState", "user32.dll",
            MethodAttributes.Public | MethodAttributes.Static | MethodAttributes.PinvokeImpl,
            CallingConventions.Standard, typeof(short), new Type[] { typeof(int) },
            System.Runtime.InteropServices.CallingConvention.Winapi,
            System.Runtime.InteropServices.CharSet.Auto);
        mB.SetImplementationFlags(MethodImplAttributes.PreserveSig);
        var nativeType = typB.CreateType();
        var mi = nativeType.GetMethod("GetAsyncKeyState");
        vars.GetKey = (Func<int, int>)(vk => (int)(short)mi.Invoke(null, new object[] { vk }));
    }
    catch (Exception e)
    {
        vars.GetKey = null;
        MessageBox.Show("BO1/BO2 autosplitter: cannot hook the pause key.\n\n" + e.Message, "BO1/BO2 autosplitter");
    }
}

init
{
    string processName = "";
    try { processName = game.ProcessName.ToLowerInvariant(); } catch (Exception) { }
    bool isPlutonium = processName == "" || processName.StartsWith("plutonium");
    vars.detectedGame = isPlutonium ? vars.GAME_UNKNOWN : vars.GAME_BO1;
    vars.prevTicks1 = -1;
    vars.prevTicks2 = -1;

    vars.hasPrev = false;
    vars.lastTicks = 0;
    vars.lastRc = 0;
    vars.rtStartPaused = 0;
    vars.rtState = 0;
    vars.rtStartMs = 0.0;
    vars.rtFrozenMs = 0.0;
    vars.rtPendingAtMs = 0.0;
    vars.roundTimeMs = 0.0;
    vars.splitReady = false;
    vars.lastRoundTimeMs = 0.0;
    vars.lastSegmentMs = 0.0;

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
    vars.roundStartPaused2 = 0;

    vars.paused = false;
    vars.pauseStart = 0;
    vars.pauseAcc = 0;
    vars.pauseKeyDown = false;

    // Force creation order on init so they appear as: Lobby -> Game Timer -> Round
    vars.FindOrCreateText("Lobby");
    vars.FindOrCreateText("Game Timer");
    vars.FindOrCreateText("Round");
}

update
{
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

    {
        int rawNow, rawOld;
        if (runBO1)
        {
            rawNow = Convert.ToInt32((object)current.ticks1);
            rawOld = Convert.ToInt32((object)old.ticks1);
        }
        else
        {
            rawNow = Convert.ToInt32((object)current.ticks2);
            rawOld = Convert.ToInt32((object)old.ticks2);
        }

        if (rawNow < rawOld) { vars.paused = false; vars.pauseAcc = 0; vars.pauseStart = 0; }

        if (vars.GetKey != null)
        {
            int ks = ((Func<int, int>)vars.GetKey)((int)vars.PAUSE_VK);
            bool down = (ks & 0x8000) != 0;
            bool tap = (ks & 0x0001) != 0;
            if ((down || tap) && !(bool)vars.pauseKeyDown && timer.CurrentPhase == TimerPhase.Running)
            {
                if (!(bool)vars.paused)
                {
                    vars.paused = true;
                    vars.pauseStart = rawNow;
                }
                else
                {
                    vars.pauseAcc = (int)vars.pauseAcc + Math.Max(0, rawNow - (int)vars.pauseStart);
                    vars.paused = false;
                }
            }
            vars.pauseKeyDown = down;
        }
    }

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
        int startPaused = (int)vars.rtStartPaused;
        var pausedAt = (Func<int, int>)vars.PausedAt;

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
            startPaused = 0;
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
                        frozenMs = nowMs - startMs - (pausedAt(ticksNow) - startPaused) * 50.0;
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
                startPaused = pausedAt((int)(pendingAt / 50.0));
                frozenMs = 0.0;
                st = 4;
            }
        }

        double rms = (st == 4) ? (nowMs - startMs - (pausedAt(ticksNow) - startPaused) * 50.0) : frozenMs;
        if (rms < 0) rms = 0;

        vars.rtState = st;
        vars.rtStartMs = startMs;
        vars.rtFrozenMs = frozenMs;
        vars.rtPendingAtMs = pendingAt;
        vars.rtStartPaused = startPaused;
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
    else
    {
        var pausedAt2 = (Func<int, int>)vars.PausedAt;

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
                vars.frozen2 = (int)current.ticks2 - (int)vars.roundStart2
                               - (pausedAt2((int)current.ticks2) - (int)vars.roundStartPaused2);
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
            vars.roundStartPaused2 = pausedAt2((int)vars.roundStart2);
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
        }

        int shown2 = 0;
        if (vars.phase2 == 1) shown2 = (int)current.ticks2 - (int)vars.roundStart2
                                       - (pausedAt2((int)current.ticks2) - (int)vars.roundStartPaused2);
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

    if (!vars.textFailed)
    {
        try
        {
            string gameTxt;
            if (runBO1)
            {
                int raw1 = Convert.ToInt32((object)current.ticks1);
                int g1 = raw1 - ((Func<int, int>)vars.PausedAt)(raw1);
                gameTxt = vars.FormatMs((g1 > 0 ? g1 : 0) * 50.0);
            }
            else
            {
                int raw2 = Convert.ToInt32((object)current.ticks2);
                int g2 = raw2 - (int)vars.START_TICKS2 - ((Func<int, int>)vars.PausedAt)(raw2);
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

    if (!vars.textFailed)
    {
        try
        {
            string lobbyTxt;
            if (runBO1)
                lobbyTxt = vars.FormatMs(Convert.ToInt32((object)current.ticks1) * 50.0);
            else
            {
                int lt = Convert.ToInt32((object)current.ticks2) - (int)vars.START_TICKS2;
                lobbyTxt = vars.FormatTicks2(lt > 0 ? lt : 0);
            }
            if (lobbyTxt != (string)vars.lastLobbyText)
            {
                vars.lastLobbyText = lobbyTxt;
                vars.SetText("Lobby", lobbyTxt);
            }
        }
        catch (Exception e)
        {
            vars.textFailed = true;
            MessageBox.Show("Autosplitter: cannot update the Lobby text line.\n\n" + e.Message, "BO1/BO2 autosplitter");
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
        int g1 = raw1 - ((Func<int, int>)vars.PausedAt)(raw1);
        return TimeSpan.FromMilliseconds((g1 > 0 ? g1 : 0) * 50);
    }

    int raw2 = (int)current.ticks2;
    int t = raw2 - (int)vars.START_TICKS2 - ((Func<int, int>)vars.PausedAt)(raw2);
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
    vars.paused = false;
    vars.pauseStart = 0;
    vars.pauseAcc = 0;

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