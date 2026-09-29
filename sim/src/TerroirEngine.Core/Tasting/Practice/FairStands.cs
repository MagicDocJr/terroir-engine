using System.Text.Json;
using TerroirEngine.Data;

namespace TerroirEngine.Tasting.Practice;

/// <summary>A Wine Fair host: an invented producer (game simplification) who pours their own Wines.</summary>
public sealed record Host(string Name, string Producer, string Greeting);

/// <summary>One theme at the Wine Fair and the Flight it pours (tasting-practice design §5).</summary>
public sealed class Stand
{
    public string Id = "", Title = "", Blurb = "", RegionId = "", Variety = "";
    public Host Host = new("", "", "");
    public int Tier;
    public List<PourSpec> Pours = new();
    /// <summary>What the player sees above each glass before the reveal: the vintage, or "?" when the stand hides it.</summary>
    public List<string> Shown = new();
    public List<string> Quiz = new();
    public bool Locked;
    /// <summary>When Locked: the vintage whose harvest opens this stand on the game's Timeline (ADR 0002).</summary>
    public int? UnlockYear;
}

/// <summary>Loads data/fair_stands.json and resolves each stand's Flight. Inside a game (maxVintage = the last vintage already
/// harvested on its Timeline) a stand that would pour a later vintage is locked, never poured (ADR 0002).</summary>
public static class FairStands
{
    private const int MinRecordYears = 5;   // a cool/warm pick needs a few years of record to mean anything

    public static IReadOnlyList<Stand> All(GameData data, int? maxVintage = null)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(data.DataRoot, "fair_stands.json")));
        var list = new List<Stand>();
        foreach (var e in doc.RootElement.GetProperty("stands").EnumerateArray())
        {
            string S(string k) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString()! : "";
            string? N(string k) => S(k) is { Length: > 0 } s ? s : null;
            var plot = data.Plot(S("plot"));
            var h = e.GetProperty("host");
            var st = new Stand
            {
                Id = S("id"), Title = S("title"), Blurb = S("blurb"), RegionId = plot.Region.Id, Variety = S("variety"),
                Tier = e.TryGetProperty("tier", out var t) ? t.GetInt32() : 0,
                Host = new Host(h.GetProperty("name").GetString()!, h.GetProperty("producer").GetString()!, h.GetProperty("greeting").GetString()!),
                Quiz = e.TryGetProperty("quiz", out var q) ? q.EnumerateArray().Select(x => x.GetString()!).ToList() : new(),
            };
            PourSpec Spec(int vintage, string? style) => new(plot.Id, vintage, N("block"), N("variety"), style ?? N("style"), Producer: st.Host.Producer);
            int last = VintageFacts.LastRecordYear(data, st.RegionId);
            int limit = Math.Min(last, maxVintage ?? last);
            if (S("pick") == "cool-warm")
            {
                var record = VintageFacts.Record(data, st.RegionId).Where(f => f.Year <= limit).ToList();
                if (record.Count < MinRecordYears) { st.Locked = true; st.UnlockYear = VintageFacts.FirstRecordYear + MinRecordYears - 1; }
                else
                {
                    int cool = record.MinBy(f => f.Gdd)!.Year, warm = record.MaxBy(f => f.Gdd)!.Year;
                    st.Pours = new() { Spec(cool, null), Spec(warm, null) };
                    st.Shown = new() { cool.ToString(), warm.ToString() };
                    st.Blurb = st.Blurb.Replace("{cool}", cool.ToString()).Replace("{warm}", warm.ToString());
                }
                if (st.Locked) st.Blurb = st.Blurb.Replace("{cool}", "the coolest").Replace("{warm}", "the warmest");
            }
            else if (e.TryGetProperty("styles", out var styles))
            {
                int v = e.GetProperty("vintage").GetInt32();
                st.Pours = styles.EnumerateArray().Select(x => Spec(v, x.GetString())).ToList();
                st.Shown = st.Pours.Select(_ => v.ToString()).ToList();
            }
            else
            {
                st.Pours = e.GetProperty("vintages").EnumerateArray().Select(x => Spec(x.GetInt32(), null)).ToList();
                st.Shown = st.Pours.Select(p => p.Vintage.ToString()).ToList();
            }
            if (st.Pours.Count > 0 && st.Pours.Max(p => p.Vintage) > limit)
            {
                st.Locked = true; st.UnlockYear = st.Pours.Max(p => p.Vintage);
            }
            if (st.Locked)
            {
                // the theme itself would be future knowledge ("The 2016 frost" in a 2010 game): show only when it opens
                st.Title = "A stand for later"; st.Blurb = $"Opens after the {st.UnlockYear} harvest.";
                st.Host = st.Host with { Greeting = "Come back after the harvest." };
                st.Pours = new(); st.Shown = new(); st.Quiz = new();
            }
            list.Add(st);
        }
        return list;
    }

    /// <summary>Pours a stand's Flight in order, one scripted Estate per glass. Throws for a locked stand.</summary>
    public static List<PouredWine> Pour(GameData data, Stand stand, int seed)
    {
        if (stand.Locked) throw new InvalidOperationException($"stand {stand.Id} is locked until the {stand.UnlockYear} harvest");
        return stand.Pours.Select((p, i) => TastingLab.Pour(data, p, seed * 31 + i)).ToList();
    }
}
