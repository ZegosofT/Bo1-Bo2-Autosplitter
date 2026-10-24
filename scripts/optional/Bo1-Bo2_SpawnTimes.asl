// =============================================================================
// Call of Duty: Black Ops 1 & 2 Zombies - Last Spawn Display (standalone script)
// - shows "X (y)": X = round number, y = spawn time
// - hidden when X > MAX_X, shown again when back on split 1
// - picks the Solo or Coop table from the selected comparison / category name
//
// v2 - anti-duplicate design:
//   * The script does NOT trust a stored reference to "its" component anymore.
//     Every few hundred ms (and on every change) it looks at the layout and
//     RECONCILES it: exactly 1 matching text component when it must be shown,
//     0 when it must be hidden. Extra copies are removed, a missing one is
//     created. It is idempotent, so it can never pile up duplicates.
//   * A component is "ours" when its Text1 looks like "12 (45.6)" / "7 (?)".
//     This also matches the component that arrives through Timer Sync from
//     the host's layout: it is ADOPTED instead of creating a second one.
//   * All layout edits are done on the LiveSplit UI thread (timer.Form),
//     never from the script thread (this was the source of race conditions).
//   * The Text.dll is looked up from the loaded assemblies / LiveSplit folder
//     instead of a relative path (the relative path broke depending on the
//     working directory).
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

    // Solo table. Key = next split number (X + 1); X = key - 1 is the displayed number.
    vars.spawnTimes = new Dictionary<int, string> {
        { 2, "10.5" },  { 3, "14.0" },  { 4, "22.8" },  { 5, "30.6" },  { 6, "40.3" },
        { 7, "42.9" },  { 8, "41.9" },  { 9, "40.5" },  { 10, "40.6" }, { 11, "43.2" },
        { 12, "42.9" }, { 13, "43.8" }, { 14, "45.6" }, { 15, "46.0" }, { 16, "47.3" },
        { 17, "48.3" }, { 18, "49.0" }, { 19, "49.4" }, { 20, "49.5" }, { 21, "50.2" },
        { 22, "49.6" }, { 23, "52.8" }, { 24, "52.5" }, { 25, "51.8" }, { 26, "55.3" },
        { 27, "54.0" }, { 28, "57.2" }, { 29, "55.8" }, { 30, "58.8" }
    };

    // 2-player (Coop) table, same convention: key = X + 1
    vars.spawnTimes2P = new Dictionary<int, string> {
        { 2, "12.3" },  { 3, "15.6" },  { 4, "25.9" },  { 5, "35.0" },  { 6, "44.2" },
        { 7, "48.0" },  { 8, "46.5" },  { 9, "46.4" },  { 10, "46.2" }, { 11, "53.3" },
        { 12, "55.0" }, { 13, "57.6" }, { 14, "1:01.0" }, { 15, "1:03.8" }, { 16, "1:06.2" },
        { 17, "1:09.0" }, { 18, "1:11.3" }, { 19, "1:12.9" }, { 20, "1:14.0" }, { 21, "1:16.0" }
    };

    // Current mode, detected from the selected comparison / category / game name
    // ("Coop" => 2P, otherwise Solo)
    vars.isCoop = false;
    vars.lastModeKey = null;

    // The component is hidden once X goes above this value
    vars.MAX_X = 20;

    // Number of spaces added to the left of the text
    vars.SPAWN_PAD = 0;

    // Font size (in points) of the spawn time text.
    vars.FONT_SIZE = 10f;

    // The layout is re-checked at least this often (ms), even if nothing changed.
    // This is what repairs the layout after a layout reload / Timer Sync refresh.
    vars.RECHECK_MS = 500;

    // true  = layout edits are marshaled to the LiveSplit UI thread (recommended)
    // false = edits done directly from the script thread (old behaviour);
    //         set to false if the component never shows up
    vars.USE_UI_THREAD = true;

    print("SpawnTimes v2.1 loaded");

    // Runtime state
    vars.busy = false;          // a UI-thread job is queued / running
    vars.lastWant = false;      // last requested visibility
    vars.lastText = null;       // last requested text
    vars.sw = System.Diagnostics.Stopwatch.StartNew();

    // "12 (45.6)", "7 (1:01.0)", "3 (?)"
    vars.rx = new System.Text.RegularExpressions.Regex(
        @"^\d{1,2} \((?:\?|(?:\d+:)?\d+(?:\.\d+)?)\)$");

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

    // ---- Is this layout component one of "our" spawn text components? ----
    vars.IsOurs = (Func<object, bool>)(lc =>
    {
        try
        {
            var getS = (Func<object, object>)vars.GetSettings;
            object s = getS(lc);
            if (s == null) return false;
            string t1 = s.GetType().GetProperty("Text1").GetValue(s, null) as string;
            if (t1 == null) return false;
            t1 = t1.Trim();
            if (t1 == "last spawn") return true; // legacy label of old versions
            return ((System.Text.RegularExpressions.Regex)vars.rx).IsMatch(t1);
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
    //   want == false : remove every spawn component
    //   want == true  : exactly one spawn component showing 'text'
    vars.Reconcile = (Action<bool, string>)((want, text) =>
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
            print("SpawnTimes: component created");
        }
        else
        {
            // Keep the LAST one (closest to the bottom; ours, or the one received
            // from the host), remove every other copy.
            var keep = matches[matches.Count - 1];
            if (matches.Count > 1) print("SpawnTimes: removing " + (matches.Count - 1) + " duplicate(s)");
            for (int i = 0; i < matches.Count - 1; i++) comps.Remove(matches[i]);
            s = getS(keep);

            // Always keep it at the very bottom of the layout
            if (comps.IndexOf(keep) != comps.Count - 1)
            {
                comps.Remove(keep);
                comps.Insert(comps.Count, keep);
            }
        }

        if (want && s != null)
        {
        var t = s.GetType();

        // Text1 (only written when different, to avoid useless redraws)
        string cur = t.GetProperty("Text1").GetValue(s, null) as string;
        if (cur != text) t.GetProperty("Text1").SetValue(s, text, null);

        // Text2 must not be empty, otherwise LiveSplit centers Text1
        string cur2 = t.GetProperty("Text2").GetValue(s, null) as string;
        if (string.IsNullOrEmpty(cur2)) t.GetProperty("Text2").SetValue(s, " ", null);

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
                if (size <= 0f) size = 9f;
                var newFont = new System.Drawing.Font(
                    "Calibri Light Regular", size, System.Drawing.FontStyle.Regular);

                t.GetProperty("Font1").SetValue(s, newFont, null);
                t.GetProperty("OverrideFont1").SetValue(s, true, null);
                t.GetProperty("Font2").SetValue(s, newFont, null);
                t.GetProperty("OverrideFont2").SetValue(s, true, null);
            }
            catch (Exception e) { print("SpawnTimes: font failed: " + e.Message); }
        }
        }
    });

    // ---- Queues a reconcile on the UI thread (one job at a time) ----
    vars.Queue = (Action<bool, string>)((want, text) =>
    {
        bool skip = false;
        if ((bool)vars.busy)
        {
            // watchdog: a job stuck for more than 3 s is abandoned
            if ((long)vars.sw.ElapsedMilliseconds < 3000) skip = true;
            else print("SpawnTimes: previous job stuck, resetting");
        }
        if (!skip)
        {
        vars.busy = true;
        vars.sw.Restart();
        vars.lastWant = want;
        vars.lastText = text;

        var ui = (Action<Action>)vars.Ui;
        ui((Action)(() =>
        {
            try { ((Action<bool, string>)vars.Reconcile)(want, text); }
            catch (Exception e) { print("SpawnTimes: reconcile error: " + e.ToString()); }
            finally { vars.busy = false; }
        }));
        }
    });
}

update
{
    try
    {
        // Solo / Coop mode from the selected comparison ("Compare Against"),
        // then the category name, then the game name: the first one that
        // contains "Solo" or "Coop" decides.
        string cmp = "", cat = "", gm = "";
        try { cmp = timer.CurrentComparison ?? ""; } catch (Exception) { }
        try { cat = timer.Run.CategoryName ?? ""; } catch (Exception) { }
        try { gm = timer.Run.GameName ?? ""; } catch (Exception) { }
        string key = cmp + "|" + cat + "|" + gm;
        if (key != (string)vars.lastModeKey)
        {
            vars.lastModeKey = key;
            bool coop = false;
            foreach (string s in new string[] { cmp, cat, gm })
            {
                bool hasCoop = s.IndexOf("coop", StringComparison.OrdinalIgnoreCase) >= 0;
                bool hasSolo = s.IndexOf("solo", StringComparison.OrdinalIgnoreCase) >= 0;
                if (hasCoop || hasSolo) { coop = hasCoop; break; }
            }
            vars.isCoop = coop;
        }

        // X = current split index + 1 (1st split = round 1)
        int x = timer.CurrentSplitIndex + 1;
        if (x < 1) x = 1;

        bool want = x <= (int)vars.MAX_X;
        string text = null;
        if (want)
        {
            var dict = (bool)vars.isCoop
                ? (Dictionary<int, string>)vars.spawnTimes2P
                : (Dictionary<int, string>)vars.spawnTimes;
            string y;
            if (!dict.TryGetValue(x + 1, out y)) y = "?"; // no value for this round
            text = new string(' ', (int)vars.SPAWN_PAD) + x.ToString() + " (" + y + ")";
        }

        bool changed = want != (bool)vars.lastWant || text != (string)vars.lastText;
        bool due = (long)vars.sw.ElapsedMilliseconds >= (int)vars.RECHECK_MS;

        if (changed || due)
            ((Action<bool, string>)vars.Queue)(want, text);
    }
    catch (Exception e) { print("SpawnTimes: update error: " + e.ToString()); }
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
            try { ((Action<bool, string>)vars.Reconcile)(false, null); }
            catch (Exception) { }
        }));
    }
    catch (Exception) { }
}
