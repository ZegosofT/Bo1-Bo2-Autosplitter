// =============================================================================
// Call of Duty: Black Ops 1 & 2 Zombies - Jug Side Solo: Grenade Counter
// Standalone script (load it in its own "Scriptable Auto Splitter" component).
// - active ONLY when the compared run name contains both "Jug" and "Solo"
// - creates a text component from round 21 up to round 45: the round number on
//   the left and the total number of grenades needed on the right ("6 Nades")
// - removes the component outside of that range, or when the comparison is
//   not a Jug + Solo one
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

    // Position of the component in the layout (0 = very top)
    vars.INSERT_INDEX = 0;

    // Text shown after the grenade count (right side), e.g. "6 Nades"
    vars.SUFFIX = " Nades";

    vars.active = false;        // true when the comparison contains "jug" and "solo"
    vars.lastModeKey = null;
    vars.lastRound = -1;

    vars.spawnLC = null;
    vars.spawnSettings = null;

    // All right-side texts this script can display (used to find its own components in the layout)
    vars.known = new HashSet<string>();
    foreach (var kv in (Dictionary<int, int>)vars.grenades)
        ((HashSet<string>)vars.known).Add(kv.Value.ToString() + (string)vars.SUFFIX);
    ((HashSet<string>)vars.known).Add("?" + (string)vars.SUFFIX);

    // ---- Removes the component ----
    vars.RemoveComp = (Action)(() =>
    {
        // 1) remove through the direct reference
        if (vars.spawnLC != null)
        {
            try { timer.Layout.LayoutComponents.Remove(vars.spawnLC); }
            catch (Exception e) { print("JugGrenades: remove(ref) failed: " + e.Message); }
        }

        // 2) safety net: remove any text component showing one of our values
        try
        {
            var known = (HashSet<string>)vars.known;
            var stale = timer.Layout.LayoutComponents.Where(x => {
                var comp = x.GetType().GetProperty("Component").GetValue(x, null);
                if (comp == null || comp.GetType().Name != "TextComponent") return false;
                var s = comp.GetType().GetProperty("Settings").GetValue(comp, null);
                var t2 = s.GetType().GetProperty("Text2").GetValue(s, null) as string;
                return t2 != null && known.Contains(t2.Trim());
            }).ToList();
            foreach (var lc in stale)
                timer.Layout.LayoutComponents.Remove(lc);
        }
        catch (Exception e) { print("JugGrenades: remove(scan) failed: " + e.Message); }

        vars.spawnLC = null;
        vars.spawnSettings = null;
        vars.lastRound = -1;
    });

    // ---- Creates the component if it does not exist ----
    vars.EnsureComp = (Func<object>)(() =>
    {
        if (vars.spawnSettings == null)
        {
            var asm = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
            var comp = Activator.CreateInstance(asm.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            var lc = new LiveSplit.UI.Components.LayoutComponent(
                "LiveSplit.Text.dll", comp as LiveSplit.UI.Components.IComponent);

            int idx = (int)vars.INSERT_INDEX;
            if (idx < 0 || idx > timer.Layout.LayoutComponents.Count)
                idx = timer.Layout.LayoutComponents.Count;
            timer.Layout.LayoutComponents.Insert(idx, lc);

            vars.spawnLC = lc;
            vars.spawnSettings = comp.GetType()
                .GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public)
                .GetValue(comp, null);
        }
        return vars.spawnSettings;
    });

    // ---- Displays the round on the left and the grenade count on the right ----
    vars.SetComp = (Action<string, string>)((left, right) =>
    {
        object s = vars.EnsureComp();
        s.GetType().GetProperty("Text1").SetValue(s, new string(' ', (int)vars.PAD) + left, null);
        s.GetType().GetProperty("Text2").SetValue(s, right, null);
        try
        {
            // Also disable "Center Text" if this LiveSplit version has the option
            var cp = s.GetType().GetProperty("CenterText");
            if (cp != null) cp.SetValue(s, false, null);
        }
        catch (Exception) { }
    });

    // ---- Cleanup of old components left in the layout (previous session / crash) ----
    try
    {
        var known = (HashSet<string>)vars.known;
        var stale = timer.Layout.LayoutComponents.Where(x => {
            var comp = x.GetType().GetProperty("Component").GetValue(x, null);
            if (comp == null || comp.GetType().Name != "TextComponent") return false;
            var s = comp.GetType().GetProperty("Settings").GetValue(comp, null);
            var t2 = s.GetType().GetProperty("Text2").GetValue(s, null) as string;
            return t2 != null && known.Contains(t2.Trim());
        }).ToList();
        foreach (var lc in stale)
            timer.Layout.LayoutComponents.Remove(lc);
    }
    catch (Exception) { }
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
            if (isActive != (bool)vars.active)
            {
                vars.active = isActive;
                vars.lastRound = -1; // force a refresh
            }
        }

        // Round = current split index + 1 (1st split = round 1)
        int round = timer.CurrentSplitIndex + 1;
        if (round < 1) round = 1;

        bool shouldShow = (bool)vars.active
                       && round >= (int)vars.MIN_ROUND
                       && round <= (int)vars.MAX_ROUND;

        if (!shouldShow)
        {
            // Outside the range (or not a Jug + Solo comparison): no component
            if (vars.spawnSettings != null || (int)vars.lastRound != -2)
            {
                vars.RemoveComp();
                vars.lastRound = -2; // marker: already removed
            }
        }
        else if (round != (int)vars.lastRound || vars.spawnSettings == null)
        {
            vars.lastRound = round;
            var dict = (Dictionary<int, int>)vars.grenades;
            int total;
            string right = (dict.TryGetValue(round, out total) ? total.ToString() : "?")
                           + (string)vars.SUFFIX;
            vars.SetComp(round.ToString(), right);
        }
    }
    catch (Exception e) { print("JugGrenades: update error: " + e.ToString()); }
}

shutdown
{
    // Remove the component when the script is unloaded
    try { vars.RemoveComp(); } catch (Exception) { }
}
