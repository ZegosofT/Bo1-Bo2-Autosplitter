// =============================================================================
// Call of Duty: Black Ops 1 + Black Ops 2 Zombies (Plutonium)
// One LiveSplit Auto Splitter (ASL) script for both games.
// Written for LiveSplit 1.8.37 and its "Scriptable Auto Splitter" component.
// =============================================================================
//
// WHAT IT DOES
//   Game Timer  : the LiveSplit timer follows the game's own time counter
//                 (Game Time), so it pauses when the game is paused and resets
//                 when the game restarts.
//   Round Timer : a separate "Round" line (a LiveSplit Text component that the
//                 script creates automatically) that measures the current round.
//                 It freezes when the last zombie of a round dies and restarts
//                 when the next round begins.
//   Splits      : one split per round, so the run can be compared with other
//                 runs. BO1: taken when the round timer restarts (the new round
//                 starts). BO2: taken when the new round number appears on screen.
//
// SUPPORTED PROCESSES
//   Plutonium : "plutonium-bootstrapper-win32.exe", BO1 and BO2.
//   Steam     : "BlackOps.exe", BO1 only.
//   BGamer    : "BGamerT5.exe", BO1 only.
//
// HOW THE GAME IS DETECTED
//   Plutonium runs both games inside the same process, so its state() block
//   holds the memory addresses of both games. At startup the script runs the BO2
//   logic by default. As soon as the Game Timer counter of one game changes,
//   that game is selected ("detectedGame") and the choice stays fixed until the
//   process closes. Only the Game Timer counters are used for this. Closing the
//   process runs init again, which clears the detection.
//   The Steam and BGamer builds only run BO1 and have no BO2 addresses, so there
//   is nothing to detect: the game is known as soon as the process is found.
//
// LOBBY TIMER AND MANUAL PAUSE (F2)
//   Lobby timer : a second text line ("Lobby") that follows the same counter as the
//                 Game Timer and is never paused by F2.
//   F2          : global key (GetAsyncKeyState), only taken into account while the
//                 LiveSplit timer is running. It pauses/resumes the Game Timer and
//                 the Round Timer. The game counter keeps running during the pause,
//                 so on resume the paused ticks are simply subtracted. A game
//                 restart or a LiveSplit reset clears the pause.
//
// STRUCTURE
//   The BO1 and BO2 logic are independent. Every variable that belongs to one
//   game ends with 1 (BO1) or 2 (BO2), and update() branches on detectedGame.
//
// MEMORY ADDRESSES
//   All addresses are offsets relative to the main module of the process they
//   are read from (the form Cheat Engine shows as module+offset):
//     BO1 Game Timer : <BO1 process>.exe + 0x1679870
//     BO1 round flag : <BO1 process>.exe + 0x165695D
//     BO2 Game Timer : plutonium-bootstrapper-win32.exe + 0x1DC155C
//     BO2 round      : plutonium-bootstrapper-win32.exe + 0x1F3B710
//   <BO1 process> is plutonium-bootstrapper-win32, BlackOps or BGamerT5. They are
//   specific to the game versions they were found on, and have to be checked
//   again after an update that changes the game binaries.
// =============================================================================

state("plutonium-bootstrapper-win32")
{
    // --- BO1 ---
    int ticks1 : 0x1679870; // game time counter, +20 per second (1 tick = 50 ms)
    byte rc1 : 0x165695D;   // round change flag, toggles around each round transition
    // round1 (0x120BC394, current round number) removed: unreliable/unavailable on
    // the Steam and BGamer builds. The round timer no longer depends on it.
    // --- BO2 ---
    int ticks2 : 0x1DC155C;   // game time counter, +20 per second (1 tick = 50 ms)
    byte round2 : 0x1F3B710;  // current round number
}

// Steam build of BO1 (BO1 only: there are no BO2 addresses for this process).
state("BlackOps")
{
    int ticks1 : 0x1679870; // game time counter, +20 per second (1 tick = 50 ms)
    byte rc1 : 0x165695D;   // round change flag, toggles around each round transition
}

// BGamer build of BO1 (BO1 only: there are no BO2 addresses for this process).
state("BGamerT5")
{
    int ticks1 : 0x1679870; // game time counter, +20 per second (1 tick = 50 ms)
    byte rc1 : 0x165695D;   // round change flag, toggles around each round transition
}

startup
{
    refreshRate = 20; // the counters only move every 50 ms
    timer.CurrentTimingMethod = TimingMethod.GameTime;

    // ===== Game identifiers =====
    // Values stored in vars.detectedGame.
    vars.GAME_UNKNOWN = 0; // process attached, game not identified yet (BO2 logic runs by default)
    vars.GAME_BO1 = 1;     // BO1 identified, locked until the process closes
    vars.GAME_BO2 = 2;     // BO2 identified, locked until the process closes

    // ===== BO1 constants =====
    // Delay before the round timer starts on the first round: 6833.3 + 400 ms.
    vars.FIRST_DELAY_MS = 7233.3;
    // Delay for the following rounds: 0 = the round timer restarts immediately.
    vars.NEXT_DELAY_MS = 0.0;

    // ===== BO2 constants =====
    vars.START_TICKS2 = 146;                    // counter value when the HUD game timer shows 0:00
    vars.INTERMISSION_TICKS2 = 250;             // 12.5 s between the last zombie dying and the next round
    vars.FIRST_ROUND_INTERMISSION_TICKS2 = 166; // 8.3 s wait before the very first round (the game waits 8.25 s)
    vars.TimerModel = new TimerModel { CurrentState = timer }; // provides SkipSplit() for BO2

    // ===== Game detection state =====
    vars.detectedGame = vars.GAME_UNKNOWN;
    vars.prevTicks1 = -1; // previous value of each counter, -1 = not read yet
    vars.prevTicks2 = -1;

    // ===== Time formatting =====
    // BO1: always m:ss.cc
    vars.FormatMs = (Func<double, string>)(ms =>
    {
        if (ms < 0) ms = 0;
        int cs = (int)(ms / 10.0);
        int hundredths = cs % 100;
        int secs = (cs / 100) % 60;
        int mins = cs / 6000;
        return mins.ToString() + ":" + (secs < 10 ? "0" : "") + secs.ToString() + "." + (hundredths < 10 ? "0" : "") + hundredths.ToString();
    });
    // BO2: h:mm:ss.ff, m:ss.ff or s.ff depending on the duration.
    vars.FormatTicks2 = (Func<int, string>)(t =>
    {
        var ts = TimeSpan.FromMilliseconds(t * 50);
        if (ts.TotalHours >= 1) return ts.ToString(@"h\:mm\:ss\.ff");
        if (ts.TotalMinutes >= 1) return ts.ToString(@"m\:ss\.ff");
        return ts.ToString(@"s\.ff");
    });

    // ===== "Round" text line =====
    // Cache by line name: a line is looked up (or created) only once, never again.
    vars.textCache = new Dictionary<string, object>();

    // Finds the LiveSplit Text component whose left text is `id`.
    // If there is none, creates it and adds it to the layout.
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

    // Sets the right text of the line called `id`.
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

    vars.textFailed = false; // set if the Text component cannot be updated: stops further attempts
    vars.lastText = "";      // last text sent to the "Round" line, to avoid redundant updates
    vars.lastGameText = "";

    // ===== Manual pause (F2) =====
    vars.PAUSE_VK = 0x71;        // F2 (0x70 = F1, 0x72 = F3, ...)
    vars.paused = false;
    vars.pauseStart = 0;         // raw tick at which the current manual pause began
    vars.pauseAcc = 0;           // ticks of all finished manual pauses
    vars.pauseKeyDown = false;
    vars.lastLobbyText = "";

    // Paused ticks accumulated up to raw tick `raw` (includes the pause in progress).
    vars.PausedAt = (Func<int, int>)(raw =>
        (int)vars.pauseAcc + ((bool)vars.paused ? Math.Max(0, raw - (int)vars.pauseStart) : 0));

    // An ASL script cannot declare [DllImport], so GetAsyncKeyState is built at runtime.
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
    // Runs on every new connection to the process.
    // The Steam and BGamer builds only run BO1 (and have no BO2 addresses), so the
    // game is known right away. Plutonium can host either game: it starts
    // unidentified (the BO2 logic runs by default) and the Game Timer counters
    // decide, see update(). If the process name cannot be read, Plutonium
    // behaviour is used.
    string processName = "";
    try { processName = game.ProcessName.ToLowerInvariant(); } catch (Exception) { }
    bool isPlutonium = processName == "" || processName.StartsWith("plutonium");
    vars.detectedGame = isPlutonium ? vars.GAME_UNKNOWN : vars.GAME_BO1;
    vars.prevTicks1 = -1;
    vars.prevTicks2 = -1;

    // ===== BO1 state =====
    vars.hasPrev = false; // false until the first update has stored the "previous" values
    vars.lastTicks = 0;
    vars.lastRc = 0;
    vars.rtStartPaused = 0;   // paused ticks counted at the moment the current round timer started
    // Round timer state machine (rc = the round change flag):
    //   0 not synchronised (the next rise of rc is treated as the end of a round)
    //   1 after a restart: waiting for rc to rise (ignored)
    //   2 waiting for rc to fall: schedules the first-round delay
    //   3 first-round delay running
    //   4 round in progress (the round timer counts)
    //   5 round over, display frozen
    //   6 first fall of rc after the round ended (ignored)
    //   7 waiting for rc to rise and fall again: schedules the next-round delay
    //   8 next-round delay running
    vars.rtState = 0;
    vars.rtStartMs = 0.0;     // game time (ms) at which the current round timer started
    vars.rtFrozenMs = 0.0;    // round time shown while the display is frozen
    vars.rtPendingAtMs = 0.0; // game time (ms) at which the scheduled start happens
    vars.roundTimeMs = 0.0;   // value currently shown by the round timer
    vars.splitReady = false;  // true for one update when a split must be taken
    vars.lastRoundTimeMs = 0.0;
    vars.lastSegmentMs = 0.0;

    // ===== BO2 state =====
    vars.firstUpdate2 = true;
    vars.awaitingStart2 = true; // waiting for the game to begin (round value becomes non-zero)
    vars.phase2 = 0;            // 0 idle, 1 round in progress, 2 frozen (intermission)
    vars.roundStart2 = 0;       // tick at which the current round timer started
    vars.flipTicks2 = 0;        // tick at which the round number last changed
    vars.frozen2 = 0;           // round time (ticks) shown while frozen
    vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
    vars.pendingSplit2 = false; // a split is scheduled for when the new round number appears
    vars.splitAtTicks2 = 0;     // tick at which that split is taken
    vars.lastSplitRound2 = 1;   // last round a split was taken for
    vars.alignPending2 = false; // the unused split rows still have to be skipped
    vars.alignTarget2 = 0;      // split index to reach by skipping rows
    vars.roundStartPaused2 = 0; // paused ticks counted at the moment the current round timer started

    // ===== Manual pause =====
    vars.paused = false;
    vars.pauseStart = 0;
    vars.pauseAcc = 0;
    vars.pauseKeyDown = false;
}

update
{
    // ----- Game detection -----
    // While no game has been identified, BO2 stays active by default. Both
    // counters are watched at the same time; the first one to change selects
    // the game for the whole lifetime of this process.
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

        // BO1 wins if both counters change during the same update.
        if (bo1Changed)
            vars.detectedGame = vars.GAME_BO1;
        else if (bo2Changed)
            vars.detectedGame = vars.GAME_BO2;
    }

    // An unidentified game runs the BO2 logic, even before a game has started.
    bool runBO1 = ((int)vars.detectedGame == (int)vars.GAME_BO1);

    // ----- Manual pause (F2) -----
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

        // The counter dropped (restart): forget any manual pause.
        if (rawNow < rawOld) { vars.paused = false; vars.pauseAcc = 0; vars.pauseStart = 0; }

        if (vars.GetKey != null)
        {
            // Always polled (even when the timer is not running) so that bit 0
            // ("pressed since last call") never carries old presses into a run.
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
        int startPaused = (int)vars.rtStartPaused;
        var pausedAt = (Func<int, int>)vars.PausedAt;

        bool restart = false;
        bool flipUp = false;   // rc went from 0 to non-zero
        bool flipDown = false; // rc went from non-zero to 0

        if (vars.hasPrev)
        {
            // The Game Timer counter dropping is the only restart signal now: it
            // runs continuously in the main menu and only drops when a map is
            // actually launched (loading resets it, together with rc).
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
                    // rc rose again while waiting: a round ended, drop the scheduled start.
                    if (flipUp) st = 5;
                    break;
                case 4:
                    // The last zombie died: freeze the displayed round time.
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

        // A scheduled start is due. There is no round-number check left to
        // confirm it: the rc cycle (and, for the very first start, the Game
        // Timer restart that preceded it) is now the only condition.
        if (st == 3 || st == 8)
        {
            if (nowMs >= pendingAt)
            {
                if (st == 8)
                {
                    // A new round starts: take the split now.
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

        // The timer counts while a round is in progress, otherwise it shows the frozen time.
        double rms = (st == 4) ? (nowMs - startMs - (pausedAt(ticksNow) - startPaused) * 50.0) : frozenMs;
        if (rms < 0) rms = 0;

        vars.rtState = st;
        vars.rtStartMs = startMs;
        vars.rtFrozenMs = frozenMs;
        vars.rtPendingAtMs = pendingAt;
        vars.rtStartPaused = startPaused;
        vars.roundTimeMs = rms;

        string txt = vars.FormatMs(rms);

        // A problem with the Text component must never break the Game Timer.
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

    // ----- BO2 (also used while the game is not identified yet) -----
    else
    {
        var pausedAt2 = (Func<int, int>)vars.PausedAt;

        if (vars.firstUpdate2)
        {
            // Attached to a game that is already running: do not mistake its next
            // round change for the start of a game.
            vars.firstUpdate2 = false;
            vars.awaitingStart2 = current.ticks2 < (int)vars.START_TICKS2;
        }

        // The counter dropped: new game or fast_restart, forget everything.
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

        // The round value becomes non-zero for the first time: the game begins
        // (it may start at a round higher than 1). The first round has its own,
        // shorter intermission.
        if (vars.awaitingStart2 && current.round2 > 0 && current.round2 != old.round2)
        {
            vars.awaitingStart2 = false;
            vars.lastSplitRound2 = current.round2;
            if (current.round2 >= 2)
            {
                // The first split will be for the round after the starting one:
                // the rows of the rounds that were never played must be skipped.
                vars.alignPending2 = true;
                vars.alignTarget2 = current.round2 - 1;
            }
            vars.phase2 = 2;
            vars.frozen2 = 0;
            vars.flipTicks2 = current.ticks2;
            vars.nextIntermissionTicks2 = vars.FIRST_ROUND_INTERMISSION_TICKS2;
        }

        // Safety net: the HUD game timer starts and the round value is already
        // non-zero although no change was seen (for example after a fast_restart
        // that did not reset the value). Start counting from the timer start.
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

        // Skip the unused split rows. This is done once the run is active, because
        // the round value can change before or after LiveSplit starts the timer.
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

        // The round number went up: the last zombie just died.
        // (A decrease, such as a restart going back to round 1, is ignored.)
        if (!vars.awaitingStart2 && current.round2 > old.round2 && old.round2 > 0)
        {
            if (vars.phase2 == 1)
                vars.frozen2 = (int)current.ticks2 - (int)vars.roundStart2
                               - (pausedAt2((int)current.ticks2) - (int)vars.roundStartPaused2); // freeze the round time
            else if (vars.phase2 == 0)
                vars.frozen2 = 0; // attached mid-game: the duration of this round is unknown
            vars.phase2 = 2;
            vars.flipTicks2 = current.ticks2;
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;

            // Schedule the split for the moment the new round number appears on screen:
            // the round change plus the length of the number animation, which gets
            // shorter as the round number gets higher.
            if (current.round2 >= 2 && current.round2 > vars.lastSplitRound2)
            {
                int animTicks = 180;                                // rounds below 20: 9 s
                if (current.round2 >= 100) animTicks = 80;          // 4 s
                else if (current.round2 >= 80) animTicks = 100;     // 5 s
                else if (current.round2 >= 60) animTicks = 120;     // 6 s
                else if (current.round2 >= 40) animTicks = 140;     // 7 s
                else if (current.round2 >= 20) animTicks = 160;     // 8 s

                vars.pendingSplit2 = true;
                vars.splitAtTicks2 = current.ticks2 + animTicks;
            }
        }

        // The intermission is over: the next round starts, restart the round timer from 0.
        // The first round uses its own shorter wait; later rounds use 12.5 s.
        if (vars.phase2 == 2 && current.ticks2 - vars.flipTicks2 >= (int)vars.nextIntermissionTicks2)
        {
            vars.phase2 = 1;
            vars.roundStart2 = (int)vars.flipTicks2 + (int)vars.nextIntermissionTicks2;
            vars.roundStartPaused2 = pausedAt2((int)vars.roundStart2);
            vars.nextIntermissionTicks2 = vars.INTERMISSION_TICKS2;
        }

        // Everything is derived from the counter, so pausing the game also pauses this timer.
        int shown2 = 0;
        if (vars.phase2 == 1) shown2 = (int)current.ticks2 - (int)vars.roundStart2
                                       - (pausedAt2((int)current.ticks2) - (int)vars.roundStartPaused2);
        else if (vars.phase2 == 2) shown2 = vars.frozen2;
        if (shown2 < 0) shown2 = 0;

        // A problem with the Text component must never break the Game Timer.
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

    // ----- Lobby timer: same counter as the Game Timer, never paused by F2 -----
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

// LiveSplit uses the Game Time returned by gameTime.
isLoading
{
    return true;
}

gameTime
{
    // Both games: the counter minus the ticks spent in manual pause (F2).
    if ((int)vars.detectedGame == (int)vars.GAME_BO1)
    {
        int raw1 = (int)current.ticks1;
        int g1 = raw1 - ((Func<int, int>)vars.PausedAt)(raw1);
        return TimeSpan.FromMilliseconds((g1 > 0 ? g1 : 0) * 50);
    }

    // BO2, or game not identified yet.
    int raw2 = (int)current.ticks2;
    int t = raw2 - (int)vars.START_TICKS2 - ((Func<int, int>)vars.PausedAt)(raw2);
    return TimeSpan.FromMilliseconds((t > 0 ? t : 0) * 50);
}

start
{
    // BO1: the game starts when the counter becomes positive.
    if ((int)vars.detectedGame == (int)vars.GAME_BO1) return current.ticks1 > 0;

    // BO2, or game not identified yet: the game starts when the counter reaches the HUD timer's 0:00.
    return old.ticks2 < (int)vars.START_TICKS2 && current.ticks2 >= (int)vars.START_TICKS2;
}

split
{
    // BO1: update() raises splitReady at the moment a new round starts.
    if ((int)vars.detectedGame == (int)vars.GAME_BO1) return vars.splitReady;

    // BO2, or game not identified yet: the scheduled split is due.
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
    // The counter goes back down when the game restarts.
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
