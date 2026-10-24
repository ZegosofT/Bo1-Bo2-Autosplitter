// =============================================================================
// Call of Duty: Black Ops 1 & 2 Zombies - Jug Side Solo: Grenade Counter
// Standalone script (load it in its own "Scriptable Auto Splitter" component).
// - active ONLY when the compared run name contains both "Jug" and "Solo"
// - shows a text component from round 21 up to round 45: the round number on
//   the left and the total number of grenades needed on the right ("6 Nades")
// - removed outside of that range, or when the comparison is not Jug + Solo
//
// v2 - same anti-duplicate design as Bo1-Bo2_SpawnTimes.asl:
//   * The script does NOT trust a stored reference to "its" component. Every
//     few hundred ms (and on every change) it RECONCILES the layout: exactly
//     1 matching text component when it must be shown, 0 when it must be
//     hidden. Extra copies are removed, a missing one is created.
//   * A component is "ours" when its right-side text (Text2) looks like
//     "6 Nades" / "? Nades". This also matches the component received through
//     Timer Sync from the host's layout: it is ADOPTED, not duplicated.
//   * The component is always kept at the very BOTTOM of the layout.
//   * All layout edits are done on the LiveSplit UI thread.
//   * Layout edits use statically typed lists (Remove() fails on dynamic lists).
// =============================================================================

// Same state blocks as the main script (needed so the script attaches to the game)
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

    // Round -> total number of grenades needed at that round
    vars.grenades = new Dictionary<int, int> {
        { 21, 3 },  { 22, 4 },  { 23, 5 },
        { 24, 6 },  { 25, 7 },  { 26, 8 },  { 27, 10 }, { 28, 12 },
        { 29, 14 }, { 30, 15 }, { 31, 17 }, { 32, 19 }, { 33, 22 },
        { 34, 24 }, { 35, 27 }, { 36, 31 }, { 37, 34 }, { 38, 37 },
        { 39, 43 }, { 40, 47 }, { 41, 53 }, { 42, 56 }, { 43, 64 },
        { 44, 71 }, { 45, 77 }
    };

    // The component only exists between these rounds (inclusive)
    vars.MIN_ROUND = 21;
    vars.MAX_ROUND = 45;

    // Number of spaces added to the left of the text
    vars.PAD = 0;

    // Text shown after the grenade count (right side), e.g. "6 Nades"
    vars.SUFFIX = " Nades";

    // Font size (in points) of the component
    vars.FONT_SIZE = 12f;

    // Keep the component at the very bottom of the layout (true) or leave it
    // wherever it is once created (false)
    vars.KEEP_AT_BOTTOM = true;

    // The layout is re-checked at least this often (ms), even if nothing changed.
    // This is what repairs the layout after a layout reload / Timer Sync refresh.
    vars.RECHECK_MS = 500;

    // true  = layout edits are marshaled to the LiveSplit UI thread (recommended)
    // false = edits done directly from the script thread
    vars.USE_UI_THREAD = true;

    print("JugGrenades v2.0 loaded");

    vars.active = false;        // true when the comparison contains "jug" and "solo"
    vars.lastModeKey = null;

    // Runtime state
    vars.busy = false;          // a UI-thread job is queued / running
    vars.lastWant = false;      // last requested visibility
    vars.lastLeft = null;       // last requested left text
    vars.lastRight = null;      // last requested right text
    vars.sw = System.Diagnostics.Stopwatch.StartNew();

    // Right-side text of our component: "6 Nades", "77 Nades", "? Nades"
    vars.rx = new System.Text.RegularExpressions.Regex(
        @"^(?:\d+|\?)\s*" +
        System.Text.RegularExpressions.Regex.Escape(((string)vars.SUFFIX).Trim()) + "$");

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

    // ---- Returns the TextComponent settings of a layout component, or null ----
    vars.GetSettings = (Func<object, object>)(lc =>
    {
        try
        {
            var comp = lc.GetType().GetProperty("Component").GetValue(lc, null);
            if (comp == null || comp.GetType().Name != "TextComponent") return null;
            return comp.GetType().GetProperty("Settings").GetValue(comp, null);
        }
        catch (Exception) { return null; }
    });

    // ---- Is this layout component one of "our" grenade text components? ----
    vars.IsOurs = (Func<object, bool>)(lc =>
    {
        try
        {
            var getS = (Func<object, object>)vars.GetSettings;
            object s = getS(lc);
            if (s == null) return false;
            string t2 = s.GetType().GetProperty("Text2").GetValue(s, null) as string;
            if (t2 == null) return false;
            return ((System.Text.RegularExpressions.Regex)vars.rx).IsMatch(t2.Trim());
        }
        catch (Exception) { return false; }
    });

    // ---- Finds the LiveSplit.Text assembly (already loaded, else from LiveSplit folder) ----
    vars.GetTextAsm = (Func<Assembly>)(() =>
    {
        foreach (var a in AppDomain.CurrentDomain.GetAssemblies())
        {
            if (a.GetName().Name == "LiveSplit.Text") return a;
        }
        string p = System.IO.Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory, "Components", "LiveSplit.Text.dll");
        return Assembly.LoadFrom(p);
    });

    // ---- RECONCILE: make the layout match the wanted state. UI THREAD ONLY. ----
    //   want == false : remove every grenade component
    //   want == true  : exactly one grenade component showing left / right
    vars.Reconcile = (Action<bool, string, string>)((want, left, right) =>
    {
        // IMPORTANT: 'timer' is dynamic in ASL. Calling Remove() on a dynamic IList<T>
        // fails ("does not contain a definition for 'Remove'"), so the list is
        // converted to a statically typed variable first.
        System.Collections.Generic.IList<LiveSplit.UI.Components.ILayoutComponent> comps =
            timer.Layout.LayoutComponents;
        var isOurs = (Func<object, bool>)vars.IsOurs;
        var getS = (Func<object, object>)vars.GetSettings;

        var matches = comps.Where(c => isOurs(c)).ToList();

        object s = null;
        bool created = false;

        if (!want)
        {
            foreach (var m in matches) comps.Remove(m);
        }
        else if (matches.Count == 0)
        {
            var asm = ((Func<Assembly>)vars.GetTextAsm)();
            var comp = Activator.CreateInstance(
                asm.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            var lc = new LiveSplit.UI.Components.LayoutComponent(
                "LiveSplit.Text.dll", comp as LiveSplit.UI.Components.IComponent);
            comps.Insert(comps.Count, lc); // at the very bottom of the layout
            s = getS(lc);
            created = true;
            print("JugGrenades: component created");
        }
        else
        {
            // Keep the LAST one (closest to the bottom; ours, or the one received
            // from the host), remove every other copy.
            var keep = matches[matches.Count - 1];
            if (matches.Count > 1) print("JugGrenades: removing " + (matches.Count - 1) + " duplicate(s)");
            for (int i = 0; i < matches.Count - 1; i++) comps.Remove(matches[i]);
            s = getS(keep);

            // Always keep it at the very bottom of the layout
            if ((bool)vars.KEEP_AT_BOTTOM && comps.IndexOf(keep) != comps.Count - 1)
            {
                comps.Remove(keep);
                comps.Insert(comps.Count, keep);
            }
        }

        if (want && s != null)
        {
            var t = s.GetType();

            // Texts (only written when different, to avoid useless redraws)
            string cur1 = t.GetProperty("Text1").GetValue(s, null) as string;
            if (cur1 != left) t.GetProperty("Text1").SetValue(s, left, null);

            string cur2 = t.GetProperty("Text2").GetValue(s, null) as string;
            if (cur2 != right) t.GetProperty("Text2").SetValue(s, right, null);

            if (created)
            {
                try
                {
                    var cp = t.GetProperty("CenterText");
                    if (cp != null) cp.SetValue(s, false, null);
                }
                catch (Exception) { }

                try
                {
                    float size = Convert.ToSingle(vars.FONT_SIZE);
                    if (size <= 0f) size = 12f;
                    var newFont = new System.Drawing.Font(
                        "Calibri Light Regular", size, System.Drawing.FontStyle.Regular);

                    t.GetProperty("Font1").SetValue(s, newFont, null);
                    t.GetProperty("OverrideFont1").SetValue(s, true, null);
                    t.GetProperty("Font2").SetValue(s, newFont, null);
                    t.GetProperty("OverrideFont2").SetValue(s, true, null);
                }
                catch (Exception e) { print("JugGrenades: font failed: " + e.Message); }
            }
        }
    });

    // ---- Queues a reconcile on the UI thread (one job at a time) ----
    vars.Queue = (Action<bool, string, string>)((want, left, right) =>
    {
        bool skip = false;
        if ((bool)vars.busy)
        {
            // watchdog: a job stuck for more than 3 s is abandoned
            if ((long)vars.sw.ElapsedMilliseconds < 3000) skip = true;
            else print("JugGrenades: previous job stuck, resetting");
        }

        if (!skip)
        {
            vars.busy = true;
            vars.sw.Restart();
            vars.lastWant = want;
            vars.lastLeft = left;
            vars.lastRight = right;

            var ui = (Action<Action>)vars.Ui;
            ui((Action)(() =>
            {
                try { ((Action<bool, string, string>)vars.Reconcile)(want, left, right); }
                catch (Exception e) { print("JugGrenades: reconcile error: " + e.ToString()); }
                finally { vars.busy = false; }
            }));
        }
    });
}

update
{
    try
    {
        // Mode detection from the selected comparison ("Compare Against"),
        // then the category name, then the game name: the first one that
        // contains "Solo" or "Coop" decides which run we are on. The counter is
        // active only if that same name also contains "Jug".
        string cmp = "", cat = "", gm = "";
        try { cmp = timer.CurrentComparison ?? ""; } catch (Exception) { }
        try { cat = timer.Run.CategoryName ?? ""; } catch (Exception) { }
        try { gm = timer.Run.GameName ?? ""; } catch (Exception) { }
        string key = cmp + "|" + cat + "|" + gm;
        if (key != (string)vars.lastModeKey)
        {
            vars.lastModeKey = key;
            bool isActive = false;
            foreach (string s in new string[] { cmp, cat, gm })
            {
                bool hasCoop = s.IndexOf("coop", StringComparison.OrdinalIgnoreCase) >= 0;
                bool hasSolo = s.IndexOf("solo", StringComparison.OrdinalIgnoreCase) >= 0;
                bool hasJug  = s.IndexOf("jug",  StringComparison.OrdinalIgnoreCase) >= 0;
                if (hasCoop || hasSolo) { isActive = hasSolo && !hasCoop && hasJug; break; }
            }
            vars.active = isActive;
        }

        // Round = current split index + 1 (1st split = round 1)
        int round = timer.CurrentSplitIndex + 1;
        if (round < 1) round = 1;

        bool want = (bool)vars.active
                 && round >= (int)vars.MIN_ROUND
                 && round <= (int)vars.MAX_ROUND;

        string left = null;
        string right = null;
        if (want)
        {
            var dict = (Dictionary<int, int>)vars.grenades;
            int total;
            string count = dict.TryGetValue(round, out total) ? total.ToString() : "?";
            left = new string(' ', (int)vars.PAD) + round.ToString();
            right = count + (string)vars.SUFFIX;
        }

        bool changed = want != (bool)vars.lastWant
                    || left != (string)vars.lastLeft
                    || right != (string)vars.lastRight;
        bool due = (long)vars.sw.ElapsedMilliseconds >= (int)vars.RECHECK_MS;

        if (changed || due)
            ((Action<bool, string, string>)vars.Queue)(want, left, right);
    }
    catch (Exception e) { print("JugGrenades: update error: " + e.ToString()); }
}

shutdown
{
    // Remove the component when the script is unloaded (asynchronously, so we
    // never block/deadlock against the UI thread while LiveSplit is closing)
    try
    {
        var ui = (Action<Action>)vars.Ui;
        ui((Action)(() =>
        {
            try { ((Action<bool, string, string>)vars.Reconcile)(false, null, null); }
            catch (Exception) { }
        }));
    }
    catch (Exception) { }
}
