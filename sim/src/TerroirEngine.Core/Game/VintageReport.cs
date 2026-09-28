using System.Text.Json.Nodes;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;

namespace TerroirEngine.Game;

/// <summary>The year in review for one Vintage: its weather against the 1991–2020 normal and what it meant for the grapes,
/// the key events, each Block's result, the wines, the money, and suggestions for next time.
/// Thresholds for the wording (hot/cool, wet/dry) are game presentation choices, not science claims.</summary>
public static class VintageReport
{
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights)> NormalCache = new();   // shared by parallel callers (tests)
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, double[]> WeeklyNormalCache = new();   // shared by parallel callers (tests)

    private record YearStats(double Wi, double Gst, double RainSeason, double RainAutumn, int HeatDays, int FrostNights);

    /// <summary>April–October statistics for a year. For a Vintage report it never looks past yesterday (the current Vintage is partial);
    /// the 1991–2020 normal always uses complete years, whatever the game date.</summary>
    private static YearStats Stats(GameSession g, int year, DateOnly? budburst, bool upToYesterday = true)
    {
        var clim = g.Blocks[0].Climate;
        double wi = 0, tsum = 0, rain = 0, rainAut = 0; int n = 0, heat = 0, frost = 0;
        var bb = budburst ?? new DateOnly(year, 4, 15);
        var end = new DateOnly(year, 10, 31);
        if (upToYesterday && end >= g.Date) end = g.Date.AddDays(-1);
        for (var d = new DateOnly(year, 4, 1); d <= end; d = d.AddDays(1))
        {
            var w = clim.Adjust(g.Weather.Get(d));
            wi += Math.Max(0, w.Tmean - 10); tsum += w.Tmean; n++;
            rain += w.Precip;
            if (d.Month >= 9) rainAut += w.Precip;
            if (w.Tmax >= 35) heat++;
            if (d >= bb && d <= new DateOnly(year, 5, 20) && w.Tmin <= -1) frost++;
        }
        return new YearStats(wi, n > 0 ? tsum / n : 0, rain, rainAut, heat, frost);
    }

    private static (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights) Normal(GameSession g)
    {
        if (NormalCache.TryGetValue(g.Plot.Id, out var c)) return c;
        var list = new List<YearStats>();
        for (int y = 1991; y <= 2020; y++)
            if (g.Weather.Archive.Has(new DateOnly(y, 1, 1))) list.Add(Stats(g, y, new DateOnly(y, 4, 20), upToYesterday: false));
        c = (list.Average(s => s.Wi), list.Average(s => s.Gst), list.Average(s => s.RainSeason), list.Average(s => s.RainAutumn), list.Average(s => s.HeatDays), list.Average(s => s.FrostNights));
        NormalCache[g.Plot.Id] = c;
        return c;
    }

    /// <summary>1991–2020 mean temperature per week of the year (Block A microclimate).</summary>
    private static double[] WeeklyNormal(GameSession g)
    {
        if (WeeklyNormalCache.TryGetValue(g.Plot.Id, out var wn)) return wn;
        var clim = g.Blocks[0].Climate;
        var sum = new double[53]; var cnt = new int[53];
        for (int y = 1991; y <= 2020; y++)
        {
            if (!g.Weather.Archive.Has(new DateOnly(y, 1, 1))) continue;
            for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(1)) { int wk = Math.Min(52, (d.DayOfYear - 1) / 7); sum[wk] += clim.Adjust(g.Weather.Archive.Get(d)).Tmean; cnt[wk]++; }
        }
        for (int i = 0; i < 53; i++) sum[i] = cnt[i] > 0 ? sum[i] / cnt[i] : 0;
        WeeklyNormalCache[g.Plot.Id] = sum;
        return sum;
    }

    private static List<SeasonRecord> Records(GameSession g, int vintage) =>
        g.Blocks.Select(b => g.Season(b, vintage)).Where(r => r != null).Select(r => r!).ToList();

    public static JsonObject Build(GameSession g, int vintage)
    {
        var recs = Records(g, vintage);
        var y = Stats(g, vintage, recs.Select(r => r.Budburst).Where(d => d != null).Min());
        var n = Normal(g);
        double heatAnom = y.Wi / Math.Max(1, n.wi) - 1, rainAnom = y.RainSeason / Math.Max(1, n.rainSeason) - 1, autAnom = y.RainAutumn / Math.Max(1, n.rainAutumn) - 1;
        string heatWord = heatAnom > 0.12 ? "hot" : heatAnom > 0.04 ? "warm" : heatAnom < -0.12 ? "cold" : heatAnom < -0.04 ? "cool" : "average-warmth";
        string rainWord = rainAnom > 0.3 ? "wet" : rainAnom > 0.1 ? "rather wet" : rainAnom < -0.3 ? "dry" : rainAnom < -0.1 ? "rather dry" : "normal-rainfall";
        string verdict = $"A {heatWord}, {rainWord} year";
        double worstFrost = recs.Count > 0 ? recs.Max(r => r.FrostShootLoss) : 0;

        var meant = new List<string>();
        if (heatAnom > 0.04) meant.Add($"More heat than normal ({heatAnom * 100:+0;-0} %) made sugar rise fast while the grapes burned off malic acid: ripe, fuller wines, but acidity was the thing to protect. Picking a little earlier keeps freshness.");
        else if (heatAnom < -0.04) meant.Add($"Less heat than normal ({heatAnom * 100:+0;-0} %) meant slow ripening: lighter, fresher wines with high acidity. Waiting for ripeness had to be weighed against autumn rot.");
        else meant.Add("Heat was close to normal: a balanced season for ripening.");
        if (y.FrostNights > 0) meant.Add($"{y.FrostNights} frost night(s) after budburst" + (worstFrost > 0.05 ? $" killed up to {worstFrost * 100:0} % of the young shoots in the worst Block." : ", but damage stayed small."));
        if (y.HeatDays > 0) meant.Add($"{y.HeatDays} day(s) reached 35 °C: sunburn risk on exposed bunches and a pause in ripening on the hottest days.");
        if (autAnom > 0.3) meant.Add($"A wet autumn ({autAnom * 100:+0} % rain in Sept–Oct) raised the grey-rot pressure at harvest; sorting and timing mattered.");
        else if (autAnom < -0.3) meant.Add("A dry autumn let the grapes hang healthily: harvest timing was your choice, not the weather's.");
        if (rainAnom < -0.3) meant.Add("Little rain over the season: shallow soils and young vines felt water stress, which concentrates flavour but can stall ripening.");

        var blocks = new JsonArray();
        foreach (var b in g.Blocks)
        {
            var r = g.Season(b, vintage);
            string lotId = $"{vintage % 100:00}-{b.Data.Id}";
            g.Provenance.TryGetValue(lotId, out var p);
            var wine = g.Wines.FirstOrDefault(w => w.Components.Any(c => c.LotId == lotId));
            blocks.Add(new JsonObject
            {
                ["id"] = b.Data.Id, ["variety"] = p?.Variety ?? b.Variety.Name, ["budburst"] = D(r?.Budburst), ["flowering"] = D(r?.Flowering), ["veraison"] = D(r?.Veraison), ["harvest"] = D(r?.HarvestDate),
                ["oe"] = p == null ? null : Math.Round(p.HarvestOe), ["ta"] = p == null ? null : Math.Round(p.HarvestTa, 1), ["ph"] = p == null ? null : Math.Round(p.HarvestPh, 2),
                ["yieldHl"] = p == null ? null : Math.Round(p.YieldHlHa), ["rot"] = p == null ? null : Math.Round(p.GreyRotPct, 1), ["frost"] = Math.Round((r?.FrostShootLoss ?? 0) * 100),
                ["wine"] = wine?.Name, ["quality"] = wine?.Sheet?.Quality,
            });
        }

        var vintageWines = g.WinesOf(vintage);
        var wines = new JsonArray();
        foreach (var w in vintageWines.OrderByDescending(w => w.Revenue))
            wines.Add(new JsonObject { ["name"] = w.Name, ["label"] = w.Legal?.Label, ["category"] = w.Legal?.Category, ["quality"] = w.Sheet?.Quality, ["bottles"] = w.Bottles, ["price"] = w.PricePerBottle, ["revenue"] = Math.Round(w.Revenue) });

        // money: the costs of the calendar year plus bottling done later, against the sales of this Vintage's wines
        // bottling is attributed by wine, not by ledger date: the calendar year also holds the previous Vintage's bottling
        var cats = g.Ledger.ByCategory(new DateOnly(vintage, 1, 1), new DateOnly(vintage, 12, 31));
        cats.Remove("Bottling");
        double bottling = vintageWines.Sum(w => w.BottlingCost);
        if (bottling > 0) cats["Bottling"] = -Math.Round(bottling);
        double revenue = vintageWines.Sum(w => w.Revenue);
        double costs = cats.Where(kv => kv.Value < 0).Sum(kv => -kv.Value);
        var topCosts = new JsonArray();
        foreach (var kv in cats.Where(kv => kv.Value < 0).OrderBy(kv => kv.Value).Take(5)) topCosts.Add(new JsonObject { ["category"] = kv.Key, ["amount"] = Math.Round(-kv.Value) });

        // suggestions: look at what happened and point at the lever that addresses it (teaching, not scoring)
        var next = new List<string>();
        var ps = g.Provenance.Values.Where(p => p.Vintage == vintage).ToList();
        if (ps.Any(p => p.GreyRotPct > 5)) next.Add("Some fruit came in with more than 5 % grey rot. Try a higher spray tier, morning-side leaf removal to dry the bunches, rigorous sorting, or picking before forecast rain.");
        if (worstFrost > 0.1) next.Add("Frost cost you crop. Watch the frost warnings after budburst and raise frost protection on the nights they forecast.");
        if (ps.Any(p => p.HarvestTa < 5.5) && heatAnom > 0) next.Add("Acidity ended up low in the heat. Pick earlier, or (where legal) let the Cellar master acidify.");
        if (ps.Any(p => p.HarvestTa > 9.5) && g.Region.Id != "mosel") next.Add("Acidity was high: the grapes may have needed more hang time or more fruit exposure.");
        if (vintageWines.Any(w => w.Sheet?.Quality is "Poor" or "Acceptable")) next.Add("For your weaker wines, open the Tasting sheet and look at which quality criteria failed: intensity and length usually come from lower yields (Low bud load, green harvest) and riper fruit.");
        if (vintageWines.Any(w => w.Legal?.Declassified == true)) next.Add("A wine was declassified. Check the legal notes: yields, buds per vine or chaptalisation limits are the usual causes.");
        if (next.Count == 0) next.Add("A clean year. Next time, experiment: split a Block's harvest dates, or try a different vessel or yeast on one Lot and compare the Tasting sheets.");

        var events = new JsonArray();
        // the season's events from its own year, plus the bottling of its own wines (which happens the year after)
        var labels = vintageWines.Select(w => w.Legal?.Label).Where(l => l != null).ToHashSet();
        var seasonEvents = g.Inbox.Where(m => m.Date.Year == vintage && m.Priority == "high" && m.Kind is "frost" or "frost-warning" or "downy" or "botrytis" or "veraison" or "budburst" or "ferment-stuck" or "overdrawn" or "newseason").OrderBy(m => m.Id).Take(12);
        var bottledEvents = g.Inbox.Where(m => m.Kind == "bottled" && labels.Any(l => m.Subject.EndsWith(": " + l)));
        foreach (var m in seasonEvents.Concat(bottledEvents).OrderBy(m => m.Id))
            events.Add(new JsonObject { ["date"] = Dates.Short(m.Date), ["text"] = m.Subject, ["kind"] = m.Kind });

        // weekly temperature, March to November (or yesterday), against the weekly normal
        var clim = g.Blocks[0].Climate;
        var wn = WeeklyNormal(g);
        var weekly = new JsonArray();
        double ws = 0; int wc = 0;
        var wEnd = new DateOnly(vintage, 11, 30);
        if (wEnd >= g.Date) wEnd = g.Date.AddDays(-1);
        for (var d = new DateOnly(vintage, 3, 1); d <= wEnd; d = d.AddDays(1))
        {
            ws += clim.Adjust(g.Weather.Get(d)).Tmean; wc++;
            if (d.DayOfWeek == DayOfWeek.Sunday || d == wEnd)
            {
                int wk = Math.Min(52, (d.DayOfYear - 1) / 7);
                weekly.Add(new JsonObject { ["date"] = Dates.Short(d), ["tmean"] = Math.Round(ws / wc, 1), ["tmeanNormal"] = Math.Round(wn[wk], 1) });
                ws = 0; wc = 0;
            }
        }

        return new JsonObject
        {
            ["vintage"] = vintage, ["plot"] = g.Plot.Name, ["region"] = g.Region.Name, ["verdict"] = verdict, ["farewell"] = vintage == g.FirstVintage,
            ["weather"] = new JsonObject
            {
                ["winkler"] = Math.Round(y.Wi), ["winklerNormal"] = Math.Round(n.wi), ["heatAnomalyPct"] = Math.Round(heatAnom * 100),
                ["gst"] = Math.Round(y.Gst, 1), ["gstNormal"] = Math.Round(n.gst, 1),
                ["rain"] = Math.Round(y.RainSeason), ["rainNormal"] = Math.Round(n.rainSeason), ["rainAnomalyPct"] = Math.Round(rainAnom * 100),
                ["rainAutumn"] = Math.Round(y.RainAutumn), ["rainAutumnNormal"] = Math.Round(n.rainAutumn),
                ["heatDays"] = y.HeatDays, ["heatDaysNormal"] = Math.Round(n.heatDays, 1), ["frostNights"] = y.FrostNights, ["frostNightsNormal"] = Math.Round(n.frostNights, 1),
                ["historical"] = g.Weather.IsHistorical(new DateOnly(vintage, 6, 1)),
            },
            ["weekly"] = weekly,
            ["meant"] = new JsonArray(meant.Select(s => (JsonNode)s).ToArray()),
            ["events"] = events, ["blocks"] = blocks, ["wines"] = wines,
            ["money"] = new JsonObject { ["revenue"] = Math.Round(revenue), ["costs"] = Math.Round(costs), ["result"] = Math.Round(revenue - costs), ["topCosts"] = topCosts },
            ["next"] = new JsonArray(next.Select(s => (JsonNode)s).ToArray()),
        };
    }

    /// <summary>One row of the Vintage history table (Estate screen): weather against normal, dates, yield, wines and sales.</summary>
    public static JsonObject HistoryRow(GameSession g, int vintage)
    {
        var recs = Records(g, vintage);
        var y = Stats(g, vintage, recs.Select(r => r.Budburst).Where(d => d != null).Min());
        var n = Normal(g);
        var wines = g.WinesOf(vintage);
        var lots = g.Lots.Where(l => l.Vintage == vintage).ToList();
        double ha = Math.Max(0.01, g.Blocks.Sum(b => b.AreaHa));
        double hl = lots.Sum(l => l.GrapeKg * (l.Red ? 0.72 : 0.62) / 100.0) / ha;
        string status = g.IsVintageBottled(vintage) ? "In bottle" : lots.Count > 0 ? "In the cellar" : vintage == g.Vintage ? "Growing" : "No harvest";
        bool seasonStarted = new DateOnly(vintage, 4, 1) < g.Date;   // heat and rain count from 1 April
        return new JsonObject
        {
            ["vintage"] = vintage, ["winkler"] = seasonStarted ? Math.Round(y.Wi) : null, ["winklerNormal"] = Math.Round(n.wi),
            ["rain"] = seasonStarted ? Math.Round(y.RainSeason) : null, ["rainNormal"] = Math.Round(n.rainSeason), ["bottles"] = wines.Sum(w => w.Bottles),
            ["budburst"] = D(recs.Select(r => r.Budburst).Where(d => d != null).Min()), ["harvest"] = D(recs.Select(r => r.HarvestDate).Where(d => d != null).Max()),
            ["yieldHl"] = lots.Count > 0 ? Math.Round(hl) : null, ["status"] = status,
            ["wines"] = new JsonArray(wines.Select(w => (JsonNode)new JsonObject { ["name"] = w.Name, ["quality"] = w.Sheet?.Quality, ["bottles"] = w.Bottles, ["revenue"] = Math.Round(w.Revenue) }).ToArray()),
            ["sales"] = Math.Round(wines.Sum(w => w.Revenue)),
        };
    }

    private static string? D(DateOnly? d) => d == null ? null : Dates.Short(d.Value);
}
