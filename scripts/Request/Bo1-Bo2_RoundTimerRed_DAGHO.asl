// =============================================================================
// Call of Duty: Black Ops 1 & 2 Zombies - Round Timer turns RED after the spawn time
//
// Standalone script, to be added as a second "Scriptable Auto Splitter" component
// next to the main autosplitter and Bo1-Bo2_SpawnTimes.asl.
//
// How it works (it only READS the layout, it does not touch the game):
//   * Round timer  = value (Text2) of the text component whose label (Text1) is "Round"
//                    (created by the main autosplitter).
//   * Spawn time   = the "X (y)" text component created by Bo1-Bo2_SpawnTimes.asl
//                    (so Solo / Coop tables and round numbers always match it,
//                    and it also works with the component received via Timer Sync).
//   * RED          : the round timer is RUNNING and has reached the spawn time.
//   * NORMAL again : as soon as the round timer stops (last zombie killed, the main
//                    autosplitter freezes the timer), or when there is no spawn time
//                    (round above MAX_X, "?" value, spawn script not loaded).
//   * The original color of the Round value is restored afterwards
//     (if you had a custom "Time Color" on it, it comes back).
//
// Layout edits are made on the LiveSplit UI thread (same technique as SpawnTimes).
// NOTE: no value-less return statement inside lambdas (the ASL compiler rewrites
// it and the script then fails to compile).
// =============================================================================

state("plutonium-bootstrapper-win32")
{
    int ticks1 : 0x1679870;
    byte rc1 : 0x165695D;
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

    // The round timer is considered STOPPED when its text has not changed for
    // this long (ms). The game updates it every 50 ms, so 250 ms = 5 ticks.
    // Lower = color goes back to normal faster after the last kill, but a game
    // freeze/lag spike of that length will also reset the color momentarily.
    vars.FREEZE_MS = 250;

    // The layout is re-scanned / the color re-checked at least this often (ms)
    vars.RECHECK_MS = 500;

    // true  = layout edits are marshaled to the LiveSplit UI thread (recommended)
    // false = edits done directly from the script thread
    vars.USE_UI_THREAD = true;

    // The "red" used for the Round value
    vars.RED = System.Drawing.Color.Red;

    print("RoundTimerRed v1.0 loaded");

    // ---- runtime state ----
    vars.sw = System.Diagnostics.Stopwatch.StartNew();   // monotonic clock
    vars.sinceSync = System.Diagnostics.Stopwatch.StartNew();
    vars.busy = false;
    vars.lastRed = false;
    vars.lastT = -2.0;          // last parsed round timer value (seconds)
    vars.lastChangeMs = 0L;     // when it last changed
    vars.roundS = null;         // cached settings object of the "Round" text component
    vars.spawnS = null;         // cached settings object of the "X (y)" component
    vars.haveOrig = false;
    vars.origOverride = false;
    vars.origColor = System.Drawing.Color.White;

    // "12 (45.6)", "7 (1:01.0)", "3 (?)"
    vars.rx = new System.Text.RegularExpressions.Regex(
        @"^\d{1,2} \((\?|(?:\d+:)?\d+(?:\.\d+)?)\)$");

    // ---- Runs an action on the LiveSplit UI thread (non-blocking) ----
    vars.Ui = (Action<Action>)(a =>
    {
        System.Windows.Forms.Form f = null;
        try
        {
            var pi = timer.GetType().GetProperty("Form");
            if (pi != null) f = pi.GetValue(timer, null) as System.Windows.Forms.Form;
        }
        catch (Exception) { }

        if (!(bool)vars.USE_UI_THREAD || f == null || f.IsDisposed
            || !f.IsHandleCreated || !f.InvokeRequired)
        {
            a();
        }
        else
        {
            f.BeginInvoke(a);
        }
    });

    // ---- Reads a string property (Text1 / Text2) of a settings object ----
    vars.GetStr = (Func<object, string, string>)((obj, prop) =>
    {
        try
        {
            if (obj == null) return null;
            return obj.GetType().GetProperty(prop).GetValue(obj, null) as string;
        }
        catch (Exception) { return null; }
    });

    // ---- "12.34", "1:02.50", "1:10:12.00" -> seconds, or -1 if invalid ----
    vars.ParseTime = (Func<string, double>)(txt =>
    {
        if (string.IsNullOrEmpty(txt)) return -1.0;
        string[] parts = txt.Trim().Split(':');
        double total = 0.0;
        foreach (string part in parts)
        {
            double v;
            if (!double.TryParse(part, System.Globalization.NumberStyles.Float,
                                 System.Globalization.CultureInfo.InvariantCulture, out v))
                return -1.0;
            total = total * 60.0 + v;
        }
        return total;
    });

    // ---- "5 (30.6)" -> 30.6 ; "3 (?)" or anything else -> -1 ----
    vars.ParseSpawn = (Func<string, double>)(txt =>
    {
        if (string.IsNullOrEmpty(txt)) return -1.0;
        var m = ((System.Text.RegularExpressions.Regex)vars.rx).Match(txt.Trim());
        if (!m.Success) return -1.0;
        string inner = m.Groups[1].Value;
        if (inner == "?") return -1.0;
        return ((Func<string, double>)vars.ParseTime)(inner);
    });

    // ---- UI THREAD ONLY: re-scan the layout, cache the 2 settings objects and
    //      apply / restore the red color on the Round value ----
    vars.Sync = (Action<bool>)(red =>
    {
        // 'timer' is dynamic: convert to a statically typed variable first
        System.Collections.Generic.IEnumerable<object> comps = timer.Layout.Components;
        var getStr = (Func<object, string, string>)vars.GetStr;
        var rx = (System.Text.RegularExpressions.Regex)vars.rx;

        object round = null;
        object spawn = null;

        foreach (object c in comps)
        {
            if (c != null && c.GetType().Name == "TextComponent")
            {
                object st = c.GetType().GetProperty("Settings").GetValue(c, null);
                string t1 = getStr(st, "Text1");
                if (t1 != null)
                {
                    t1 = t1.Trim();
                    if (t1 == "Round") { if (round == null) round = st; }
                    else if (rx.IsMatch(t1)) { spawn = st; }
                }
            }
        }

        vars.roundS = round;
        vars.spawnS = spawn;

        if (round != null)
        {
            var t = round.GetType();
            var pO = t.GetProperty("OverrideTimeColor");
            var pC = t.GetProperty("TimeColor");
            if (pO != null && pC != null)
            {
                bool curO = (bool)pO.GetValue(round, null);
                System.Drawing.Color curC = (System.Drawing.Color)pC.GetValue(round, null);
                System.Drawing.Color redC = (System.Drawing.Color)vars.RED;
                bool isRed = curO && curC.ToArgb() == redC.ToArgb();

                if (red)
                {
                    if (!isRed)
                    {
                        // remember the user's own settings before painting red
                        vars.origOverride = curO;
                        vars.origColor = curC;
                        vars.haveOrig = true;
                        pC.SetValue(round, redC, null);
                        pO.SetValue(round, true, null);
                    }
                }
                else if (isRed)
                {
                    if ((bool)vars.haveOrig)
                    {
                        pC.SetValue(round, (System.Drawing.Color)vars.origColor, null);
                        pO.SetValue(round, (bool)vars.origOverride, null);
                    }
                    else
                    {
                        pO.SetValue(round, false, null);
                    }
                }
            }
        }
    });

    // ---- Queues a Sync on the UI thread (one job at a time, with a watchdog) ----
    vars.Queue = (Action<bool>)(red =>
    {
        bool skip = false;
        if ((bool)vars.busy)
        {
            if ((long)vars.sinceSync.ElapsedMilliseconds < 3000) skip = true;
            else print("RoundTimerRed: previous job stuck, resetting");
        }

        if (!skip)
        {
            vars.busy = true;
            vars.sinceSync.Restart();
            vars.lastRed = red;

            var ui = (Action<Action>)vars.Ui;
            ui((Action)(() =>
            {
                try { ((Action<bool>)vars.Sync)(red); }
                catch (Exception e) { print("RoundTimerRed: sync error: " + e.ToString()); }
                finally { vars.busy = false; }
            }));
        }
    });
}

update
{
    try
    {
        var getStr = (Func<object, string, string>)vars.GetStr;
        var parseTime = (Func<string, double>)vars.ParseTime;
        var parseSpawn = (Func<string, double>)vars.ParseSpawn;

        // Round timer value (seconds) and spawn time (seconds), from the cached layout objects
        object roundS = (object)vars.roundS;
        object spawnS = (object)vars.spawnS;
        string roundTxt = getStr(roundS, "Text2");
        string spawnTxt = getStr(spawnS, "Text1");
        double t = parseTime(roundTxt);
        double sp = parseSpawn(spawnTxt);

        // Is the round timer still moving?
        long now = (long)vars.sw.ElapsedMilliseconds;
        if (t != (double)vars.lastT)
        {
            vars.lastT = t;
            vars.lastChangeMs = now;
        }
        bool running = (now - (long)vars.lastChangeMs) <= (int)vars.FREEZE_MS;

        bool red = running && t >= 0.0 && sp > 0.0 && t >= sp;

        bool changed = red != (bool)vars.lastRed;
        bool due = (long)vars.sinceSync.ElapsedMilliseconds >= (int)vars.RECHECK_MS;

        // Also covers the very first run (caches are still empty)
        if (changed || due) ((Action<bool>)vars.Queue)(red);
    }
    catch (Exception e) { print("RoundTimerRed: update error: " + e.ToString()); }
}

shutdown
{
    // Put the original color back when the script is unloaded
    try
    {
        var ui = (Action<Action>)vars.Ui;
        ui((Action)(() =>
        {
            try { ((Action<bool>)vars.Sync)(false); }
            catch (Exception) { }
        }));
    }
    catch (Exception) { }
}
