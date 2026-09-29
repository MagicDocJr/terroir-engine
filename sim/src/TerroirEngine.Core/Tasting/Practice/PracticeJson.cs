using System.Text.Json.Nodes;
using TerroirEngine.Game;

namespace TerroirEngine.Tasting.Practice;

/// <summary>JSON for the game's Tasting practice screens (the bridge passes it through unchanged).</summary>
public static class PracticeJson
{
    public static JsonObject Poured(PouredWine p)
    {
        var c = p.Context;
        var w = Snapshot.WineObj(p.Wine);
        w["context"] = new JsonObject
        {
            ["region"] = c.RegionId, ["regionName"] = c.RegionName, ["plot"] = c.PlotId, ["plotName"] = c.PlotName, ["block"] = c.BlockId,
            ["variety"] = c.Variety, ["red"] = c.Red, ["vintage"] = c.Vintage, ["producer"] = c.Producer, ["style"] = c.StyleId, ["styleLabel"] = c.StyleLabel,
            ["gdd"] = Math.Round(c.Gdd), ["seasonTemp"] = Math.Round(c.SeasonTemp, 1), ["summerTmax"] = c.SummerTmax, ["harvestRain"] = c.HarvestRainMm,
            ["frostLoss"] = Math.Round(c.FrostLossPct), ["greyRot"] = Math.Round(c.GreyRotPct, 1), ["nobleRot"] = Math.Round(c.NobleRotPct, 1),
            ["yield"] = Math.Round(c.YieldHlHa), ["harvestOe"] = Math.Round(c.HarvestOe), ["harvestTa"] = Math.Round(c.HarvestTa, 1), ["harvestPh"] = Math.Round(c.HarvestPh, 2),
            ["harvestDate"] = c.HarvestDate.ToString("yyyy-MM-dd"), ["budburst"] = c.Budburst?.ToString("yyyy-MM-dd"),
            ["tastedOn"] = c.TastedOn.ToString("yyyy-MM-dd"), ["ageYears"] = c.AgeYears,
        };
        return w;
    }
}
