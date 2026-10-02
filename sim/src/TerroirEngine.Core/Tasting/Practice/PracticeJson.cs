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
        w["glassColour"] = GlassColour(p.Sheet);
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

    /// <summary>The glass's colour for drawing (a presentation of the sheet's appearance terms), as #rrggbb.</summary>
    public static string GlassColour(TastingSheet sh)
    {
        (double r, double g, double b) c = sh.Colour switch
        {
            "lemon-green" => (0xE4, 0xE8, 0xA2), "lemon" => (0xEC, 0xDF, 0x8E), "gold" => (0xE0, 0xB8, 0x4E), "amber" => (0xC3, 0x82, 0x2C),
            "purple" => (0x4E, 0x1A, 0x3F), "ruby" => (0x85, 0x1A, 0x2A), "garnet" => (0x86, 0x35, 0x2A), "tawny" => (0x9A, 0x5A, 0x2A),
            "brown" => sh.Palate.Any(l => l.Attribute == "Tannin") ? (0x6E, 0x40, 0x22) : (0x9C, 0x6A, 0x2E),
            _ => (0xD8, 0xC8, 0x89),
        };
        double k = sh.ColourIntensity switch { "pale" => 0.5, "medium" => 0.2, _ => 0.0 };
        int L(double v, double to) => (int)Math.Round(v + (to - v) * k);
        return $"#{L(c.r, 0xF7):x2}{L(c.g, 0xF3):x2}{L(c.b, 0xE6):x2}";
    }

    private static JsonArray A(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());

    /// <summary>Only what a screen may show before the player answers (learning-core design §5): no label, category, style,
    /// "because" lines or conclusions, and per exercise only its own material. The reveal sends the full Wine.</summary>
    public static JsonObject Shown(PouredWine p, string exercise, bool blind, bool stand)
    {
        var sh = p.Sheet; var c = p.Context;
        var o = new JsonObject { ["glassColour"] = GlassColour(sh), ["red"] = c.Red };
        JsonObject Described() => new()
        {
            ["appearance"] = new JsonObject { ["clarity"] = sh.Clarity, ["intensity"] = sh.ColourIntensity, ["colour"] = sh.Colour },
            ["nose"] = new JsonObject { ["condition"] = sh.NoseCondition, ["intensity"] = sh.NoseIntensity, ["development"] = sh.Development },
            ["aromas"] = new JsonArray(sh.Aromas.Select(a => (JsonNode)new JsonObject { ["category"] = a.Category, ["family"] = a.Family, ["terms"] = a.Terms, ["intensity"] = a.Intensity }).ToArray()),
            ["palate"] = new JsonArray(sh.Palate.Select(l => (JsonNode)new JsonObject { ["attribute"] = l.Attribute, ["level"] = l.Level }).ToArray()),
            ["faults"] = A(sh.Faults),
            ["fruitRipeness"] = sh.FruitRipeness, ["simple"] = sh.Simple, ["flavours"] = A(sh.Flavours),
            ["observations"] = A(sh.Observations.Select(o => o.Term)),
        };
        JsonObject Label() => new()
        {
            ["producer"] = stand ? null : c.Producer, ["plotName"] = c.PlotName, ["regionName"] = c.RegionName, ["variety"] = c.Variety,
            ["vintage"] = blind ? null : c.Vintage,
        };
        switch (exercise)
        {
            case "conclusions": o["sheet"] = Described(); break;
            case "identify": o["sheet"] = Described(); break;
            case "cause":
            case "session":
                o["context"] = new JsonObject
                {
                    ["producer"] = c.Producer, ["plotName"] = c.PlotName, ["regionName"] = c.RegionName, ["variety"] = c.Variety, ["vintage"] = c.Vintage,
                    ["gdd"] = Math.Round(c.Gdd), ["summerTmax"] = c.SummerTmax, ["harvestRain"] = c.HarvestRainMm, ["frostLoss"] = Math.Round(c.FrostLossPct),
                    ["harvestDate"] = c.HarvestDate.ToString("yyyy-MM-dd"), ["harvestOe"] = Math.Round(c.HarvestOe), ["harvestTa"] = Math.Round(c.HarvestTa, 1),
                    ["harvestPh"] = Math.Round(c.HarvestPh, 2), ["yield"] = Math.Round(c.YieldHlHa), ["styleLabel"] = c.StyleLabel, ["ageYears"] = c.AgeYears,
                };
                break;
            default: o["context"] = Label(); break;
        }
        return o;
    }
}
