// =============================================================================
// Call of Duty: Black Ops 1 & 2 Zombies - Last Spawn Display (standalone script)
// - creates its own text component (at the very top of the layout)
// - shows "X (y)": X = round number, y = spawn time
// - removes the component when X > 20, recreates it when back on split 1
// - picks the Solo or Coop table from the selected comparison / category name
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

    // The component is removed once X goes above this value
    vars.MAX_X = 20;

    // Number of spaces added to the left of the text
    vars.SPAWN_PAD = 0;

    // Font size (in points) of the spawn time text. Set to 0 to keep the layout's font.
    // It is re-applied every time the text is updated, so it also survives the
    // component being recreated (reset, fast_restart, ...).
    vars.FONT_SIZE = 16f;

    vars.spawnLC = null;
    vars.spawnSettings = null;
    vars.lastX = -1;
    vars.lastText = "";

    // All texts this script can display (used to find its own components in the layout)
    vars.known = new HashSet<string>();
    foreach (var kv in (Dictionary<int, string>)vars.spawnTimes)
        ((HashSet<string>)vars.known).Add((kv.Key - 1).ToString() + " (" + kv.Value + ")");
    foreach (var kv in (Dictionary<int, string>)vars.spawnTimes2P)
        ((HashSet<string>)vars.known).Add((kv.Key - 1).ToString() + " (" + kv.Value + ")");
    for (int i = 1; i <= 30; i++)
        ((HashSet<string>)vars.known).Add(i.ToString() + " (?)");

    // ---- Removes the component ----
    vars.RemoveSpawn = (Action)(() =>
    {
        // 1) remove through the direct reference
        if (vars.spawnLC != null)
        {
            try { timer.Layout.LayoutComponents.Remove(vars.spawnLC); }
            catch (Exception e) { print("SpawnTimes: remove(ref) failed: " + e.Message); }
        }

        // 2) safety net: remove any text component showing one of our values
        try
        {
            var known = (HashSet<string>)vars.known;
            var stale = timer.Layout.LayoutComponents.Where(x => {
                var comp = x.GetType().GetProperty("Component").GetValue(x, null);
                if (comp == null || comp.GetType().Name != "TextComponent") return false;
                var s = comp.GetType().GetProperty("Settings").GetValue(comp, null);
                var t1 = s.GetType().GetProperty("Text1").GetValue(s, null) as string;
                return t1 != null && known.Contains(t1.Trim());
            }).ToList();
            foreach (var lc in stale)
                timer.Layout.LayoutComponents.Remove(lc);
        }
        catch (Exception e) { print("SpawnTimes: remove(scan) failed: " + e.Message); }

        vars.spawnLC = null;
        vars.spawnSettings = null;
        vars.lastText = "";
    });

    // ---- Creates the component (at the very top) if it does not exist ----
    vars.EnsureSpawn = (Func<object>)(() =>
    {
        if (vars.spawnSettings == null)
        {
            var asm = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
            var comp = Activator.CreateInstance(asm.GetType("LiveSplit.UI.Components.TextComponent"), timer);
            var lc = new LiveSplit.UI.Components.LayoutComponent(
                "LiveSplit.Text.dll", comp as LiveSplit.UI.Components.IComponent);
            timer.Layout.LayoutComponents.Insert(0, lc);
            vars.spawnLC = lc;
            vars.spawnSettings = comp.GetType()
                .GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public)
                .GetValue(comp, null);
        }
        return vars.spawnSettings;
    });

    // ---- Displays a text (value only, left-aligned) ----
    vars.SetSpawn = (Action<string>)(val =>
    {
        object s = vars.EnsureSpawn();
        s.GetType().GetProperty("Text1").SetValue(s, new string(' ', (int)vars.SPAWN_PAD) + val, null);
        // Text2 must not be empty, otherwise LiveSplit centers Text1
        s.GetType().GetProperty("Text2").SetValue(s, " ", null);
        try
        {
            // Also disable "Center Text" if this LiveSplit version has the option
            var cp = s.GetType().GetProperty("CenterText");
            if (cp != null) cp.SetValue(s, false, null);
        }
        catch (Exception) { }

        // Font size: build a copy of the current font with the configured size
        // (done through reflection so no extra assembly reference is needed)
        try
        {
            float size = Convert.ToSingle(vars.FONT_SIZE);
            if (size > 0f)
            {
                object oldFont = s.GetType().GetProperty("Font1").GetValue(s, null);
                if (oldFont != null)
                {
                    object family = oldFont.GetType().GetProperty("FontFamily").GetValue(oldFont, null);
                    object style = oldFont.GetType().GetProperty("Style").GetValue(oldFont, null);
                    object newFont = Activator.CreateInstance(oldFont.GetType(), new object[] { family, size, style });
                    s.GetType().GetProperty("Font1").SetValue(s, newFont, null);
                    s.GetType().GetProperty("OverrideFont1").SetValue(s, true, null);
                }
            }
        }
        catch (Exception e) { print("SpawnTimes: font failed: " + e.Message); }
    });

    // ---- Cleanup of old "X (y)" components left in the layout ----
    try
    {
        var known = (HashSet<string>)vars.known;
        known.Add("last spawn");

        var stale = timer.Layout.LayoutComponents.Where(x => {
            var comp = x.GetType().GetProperty("Component").GetValue(x, null);
            if (comp == null || comp.GetType().Name != "TextComponent") return false;
            var s = comp.GetType().GetProperty("Settings").GetValue(comp, null);
            var t1 = s.GetType().GetProperty("Text1").GetValue(s, null) as string;
            return t1 != null && known.Contains(t1.Trim());
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
            if (coop != (bool)vars.isCoop)
            {
                vars.isCoop = coop;
                vars.lastX = -1; // force a redraw with the right table
            }
        }

        // X = current split index + 1 (1st split = round 1)
        int x = timer.CurrentSplitIndex + 1;
        if (x < 1) x = 1;

        if (x > (int)vars.MAX_X)
        {
            // Past the limit: remove the component
            // (when arriving on this split, and as long as a reference still exists)
            if (x != (int)vars.lastX || vars.spawnSettings != null)
                vars.RemoveSpawn();
            vars.lastX = x;
        }
        else if (x != (int)vars.lastX || vars.spawnSettings == null)
        {
            vars.lastX = x;
            var dict = (bool)vars.isCoop
                ? (Dictionary<int, string>)vars.spawnTimes2P
                : (Dictionary<int, string>)vars.spawnTimes;
            string y;
            if (!dict.TryGetValue(x + 1, out y)) y = "?"; // no value for this round
            string txt = x.ToString() + " (" + y + ")";
            vars.SetSpawn(txt);
            vars.lastText = txt;
        }
    }
    catch (Exception e) { print("SpawnTimes: update error: " + e.ToString()); }
}

shutdown
{
    // Remove the component when the script is unloaded
    try { vars.RemoveSpawn(); } catch (Exception) { }
}
