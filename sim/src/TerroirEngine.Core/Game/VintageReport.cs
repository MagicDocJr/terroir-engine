using System.Text.Json.Nodes;
using TerroirEngine.Util;
using TerroirEngine.Vineyard;
using TerroirEngine.Weather;

namespace TerroirEngine.Game;

/// <summary>The year in review: the Vintage's weather against the 1991–2020 normal and what it meant for the grapes,
/// the key events, each Block's result, the wines, the money, and suggestions for next time.
/// Thresholds for the wording (hot/cool, wet/dry) are game presentation choices, not science claims.</summary>
public static class VintageReport
{
    private static readonly Dictionary<string, (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights)> NormalCache = new();

    private record YearStats(double Wi, double Gst, double RainSeason, double RainAutumn, int HeatDays, int FrostNights);

    private static YearStats Stats(GameSession g, int year, DateOnly? budburst)
    {
        var clim = g.Blocks[0].Climate;
        double wi = 0, tsum = 0, rain = 0, rainAut = 0; int n = 0, heat = 0, frost = 0;
        var bb = budburst ?? new DateOnly(year, 4, 15);
        for (var d = new DateOnly(year, 4, 1); d <= new DateOnly(year, 10, 31); d = d.AddDays(1))
        {
            var w = clim.Adjust(g.Weather.Get(d));
            wi += Math.Max(0, w.Tmean - 10); tsum += w.Tmean; n++;
            rain += w.Precip;
            if (d.Month >= 9) rainAut += w.Precip;
            if (w.Tmax >= 35) heat++;
            if (d >= bb && d <= new DateOnly(year, 5, 20) && w.Tmin <= -1) frost++;
        }
        return new YearStats(wi, tsum / n, rain, rainAut, heat, frost);
    }

    private static (double wi, double gst, double rainSeason, double rainAutumn, double heatDays, double frostNights) Normal(GameSession g)
    {
        if (NormalCache.TryGetValue(g.Plot.Id, out var c)) return c;
        var list = new List<YearStats>();
        for (int y = 1991; y <= 2020; y++)
            if (g.Weather.Archive.Has(new DateOnly(y, 1, 1))) list.Add(Stats(g, y, new DateOnly(y, 4, 20)));
        c = (list.Average(s => s.Wi), list.Average(s => s.Gst), list.Average(s => s.RainSeason), list.Average(s => s.RainAutumn), list.Average(s => s.HeatDays), list.Average(s => s.FrostNights));
        NormalCache[g.Plot.Id] = c;
        return c;
    }

    public static JsonObject Build(GameSession g)
    {
        var bA = g.Blocks[0];
        var y = Stats(g, g.Vintage, g.Blocks.Where(b => b.Budburst != null).Select(b => b.Budburst).Min());
        var n = Normal(g);
        double heatAnom = y.Wi / Math.Max(1, n.wi) - 1, rainAnom = y.RainSeason / Math.Max(1, n.rainSeason) - 1, autAnom = y.RainAutumn / Math.Max(1, n.rainAutumn) - 1;
        string heatWord = heatAnom > 0.12 ? "hot" : heatAnom > 0.04 ? "warm" : heatAnom < -0.12 ? "cold" : heatAnom < -0.04 ? "cool" : "average-warmth";
        string rainWord = rainAnom > 0.3 ? "wet" : rainAnom > 0.1 ? "rather wet" : rainAnom < -0.3 ? "dry" : rainAnom < -0.1 ? "rather dry" : "normal-rainfall";
        string verdict = $"A {heatWord}, {rainWord} year";

        var meant = new List<string>();
        if (heatAnom > 0.04) meant.Add($"More heat than normal ({heatAnom * 100:+0;-0} %) made sugar rise fast while the grapes burned off malic acid: ripe, fuller wines, but acidity was the thing to protect. Picking a little earlier keeps freshness.");
        else if (heatAnom < -0.04) meant.Add($"Less heat than normal ({heatAnom * 100:+0;-0} %) meant slow ripening: lighter, fresher wines with high acidity. Waiting for ripeness had to be weighed against autumn rot.");
        else meant.Add("Heat was close to normal: a balanced season for ripening.");
        if (y.FrostNights > 0) meant.Add($"{y.FrostNights} frost night(s) after budburst" + (g.Blocks.Max(b => b.FrostShootLoss) > 0.05 ? $" killed up to {g.Blocks.Max(b => b.FrostShootLoss) * 100:0} % of the young shoots in the worst Block." : ", but damage stayed small."));
        if (y.HeatDays > 0) meant.Add($"{y.HeatDays} day(s) reached 35 °C: sunburn risk on exposed bunches and a pause in ripening on the hottest days.");
        if (autAnom > 0.3) meant.Add($"A wet autumn ({autAnom * 100:+0} % rain in Sept–Oct) raised the grey-rot pressure at harvest; sorting and timing mattered.");
        else if (autAnom < -0.3) meant.Add("A dry autumn let the grapes hang healthily: harvest timing was your choice, not the weather's.");
        if (rainAnom < -0.3) meant.Add("Little rain over the season: shallow soils and young vines felt water stress, which concentrates flavour but can stall ripening.");

        var blocks = new JsonArray();
        foreach (var b in g.Blocks)
        {
            g.Provenance.TryGetValue(b.LotId ?? "", out var p);
            var wine = g.Wines.FirstOrDefault(w => w.Components.Any(c => c.LotId == b.LotId));
            blocks.Add(new JsonObject
            {
                ["id"] = b.Data.Id, ["variety"] = b.Variety.Name, ["budburst"] = D(b.Budburst), ["flowering"] = D(b.Flowering), ["veraison"] = D(b.Veraison), ["harvest"] = D(b.HarvestDate),
                ["oe"] = p == null ? null : Math.Round(p.HarvestOe), ["ta"] = p == null ? null : Math.Round(p.HarvestTa, 1), ["ph"] = p == null ? null : Math.Round(p.HarvestPh, 2),
                ["yieldHl"] = p == null ? null : Math.Round(p.YieldHlHa), ["rot"] = p == null ? null : Math.Round(p.GreyRotPct, 1), ["frost"] = Math.Round(b.FrostShootLoss * 100),
                ["wine"] = wine?.Name, ["quality"] = wine?.Sheet?.Quality,
            });
        }

        var wines = new JsonArray();
        foreach (var w in g.Wines.OrderByDescending(w => w.Revenue))
            wines.Add(new JsonObject { ["name"] = w.Name, ["label"] = w.Legal?.Label, ["category"] = w.Legal?.Category, ["quality"] = w.Sheet?.Quality, ["bottles"] = w.Bottles, ["price"] = w.PricePerBottle, ["revenue"] = Math.Round(w.Revenue) });

        var from = new DateOnly(g.Vintage, 1, 1);
        var cats = g.Ledger.ByCategory(from, DateOnly.MaxValue);
        double revenue = cats.Where(kv => kv.Value > 0 && kv.Key != "Capital").Sum(kv => kv.Value);
        double costs = cats.Where(kv => kv.Value < 0).Sum(kv => -kv.Value);
        var topCosts = new JsonArray();
        foreach (var kv in cats.Where(kv => kv.Value < 0).OrderBy(kv => kv.Value).Take(5)) topCosts.Add(new JsonObject { ["category"] = kv.Key, ["amount"] = Math.Round(-kv.Value) });

        // suggestions: look at what happened and point at the lever that addresses it (teaching, not scoring)
        var next = new List<string>();
        var ps = g.Provenance.Values.ToList();
        if (ps.Any(p => p.GreyRotPct > 5)) next.Add("Some fruit came in with more than 5 % grey rot. Try a higher spray tier, morning-side leaf removal to dry the bunches, rigorous sorting, or picking before forecast rain.");
        if (g.Blocks.Max(b => b.FrostShootLoss) > 0.1) next.Add("Frost cost you crop. Watch the frost warnings after budburst and raise frost protection on the nights they forecast.");
        if (ps.Any(p => p.HarvestTa < 5.5) && heatAnom > 0) next.Add("Acidity ended up low in the heat. Pick earlier, or (where legal) let the Cellar master acidify.");
        if (ps.Any(p => p.HarvestTa > 9.5) && g.Region.Id != "mosel") next.Add("Acidity was high: the grapes may have needed more hang time or more fruit exposure.");
        if (g.Wines.Any(w => w.Sheet?.Quality is "Poor" or "Acceptable")) next.Add("For your weaker wines, open the Tasting sheet and look at which quality criteria failed: intensity and length usually come from lower yields (Low bud load, green harvest) and riper fruit.");
        if (g.Wines.Any(w => w.Legal?.Declassified == true)) next.Add("A wine was declassified. Check the legal notes: yields, buds per vine or chaptalisation limits are the usual causes.");
        if (next.Count == 0) next.Add("A clean year. Next time, experiment: split a Block's harvest dates, or try a different vessel or yeast on one Lot and compare the Tasting sheets.");

        var events = new JsonArray();
        foreach (var m in g.Inbox.Where(m => m.Priority == "high" && m.Kind is "frost" or "frost-warning" or "downy" or "botrytis" or "veraison" or "budburst" or "ferment-stuck" or "overdrawn" or "bottled").OrderBy(m => m.Id).Take(14))
            events.Add(new JsonObject { ["date"] = Dates.Short(m.Date), ["text"] = m.Subject, ["kind"] = m.Kind });

        return new JsonObject
        {
            ["vintage"] = g.Vintage, ["plot"] = g.Plot.Name, ["region"] = g.Region.Name, ["verdict"] = verdict,
            ["weather"] = new JsonObject
            {
                ["winkler"] = Math.Round(y.Wi), ["winklerNormal"] = Math.Round(n.wi), ["heatAnomalyPct"] = Math.Round(heatAnom * 100),
                ["gst"] = Math.Round(y.Gst, 1), ["gstNormal"] = Math.Round(n.gst, 1),
                ["rain"] = Math.Round(y.RainSeason), ["rainNormal"] = Math.Round(n.rainSeason), ["rainAnomalyPct"] = Math.Round(rainAnom * 100),
                ["rainAutumn"] = Math.Round(y.RainAutumn), ["rainAutumnNormal"] = Math.Round(n.rainAutumn),
                ["heatDays"] = y.HeatDays, ["heatDaysNormal"] = Math.Round(n.heatDays, 1), ["frostNights"] = y.FrostNights, ["frostNightsNormal"] = Math.Round(n.frostNights, 1),
                ["historical"] = g.Weather.IsHistorical(new DateOnly(g.Vintage, 6, 1)),
            },
            ["meant"] = new JsonArray(meant.Select(s => (JsonNode)s).ToArray()),
            ["events"] = events, ["blocks"] = blocks, ["wines"] = wines,
            ["money"] = new JsonObject { ["revenue"] = Math.Round(revenue), ["costs"] = Math.Round(costs), ["result"] = Math.Round(revenue - costs), ["topCosts"] = topCosts },
            ["next"] = new JsonArray(next.Select(s => (JsonNode)s).ToArray()),
        };
    }

    private static string? D(DateOnly? d) => d == null ? null : Dates.Short(d.Value);
}
