using TerroirEngine.Game;

namespace TerroirEngine.Tests;

/// <summary>Medal tuning (famous-vintages spec §3): sensible default play earns bronze (Napa 2011: silver, see the ledger), the
/// year's right decisions earn gold. Strategies follow what real growers did (docs/science/vintage-notes.md).</summary>
public class ScenarioBalanceTests
{
    private static readonly Dictionary<string, int> ExtractPinot = new() { ["MLF"] = 1, ["Vessel"] = 4, ["Maceration"] = 1, ["Cap management"] = 1, ["Ageing"] = 2, ["Red temperature"] = 2 };

    private static string? Medal(string id, double oe, Dictionary<string, int>? choices = null) =>
        (string?)Scenarios.Evaluate(ScenarioTests.Play(id, oe, choices))["medal"];

    [Fact]
    public void CoteDor2016_DefaultBronze_ExtractionAndRipenessGold()
    {
        Assert.Equal("bronze", Medal("cotedor-2016", 94));                 // the region's default pick, default cellar
        Assert.Equal("gold", Medal("cotedor-2016", 100, ExtractPinot));    // riper pick, malolactic, punch-down, warm ferment, new oak
    }

    [Fact]
    public void Mosel2018_DefaultBronze_EarlyKabinettWithSweetnessGold()
    {
        Assert.Equal("bronze", Medal("mosel-2018", 84));                                        // picked at Spätlese weight
        Assert.Equal("silver", Medal("mosel-2018", 75));                                        // an early, true Kabinett
        Assert.Equal("gold", Medal("mosel-2018", 75, new() { ["Sweetness"] = 2 }));            // stopped with some sweetness
    }

    [Fact]
    public void Napa2011_DefaultSilver_EarlierPickGentlerOakGold()
    {
        Assert.Equal("silver", Medal("napa-2011", 106));                                         // ripe and balanced, but over 15 %
        Assert.Equal("gold", Medal("napa-2011", 103, new() { ["Vessel"] = 3 }));                 // earlier pick, first-fill rather than new oak
    }
}
