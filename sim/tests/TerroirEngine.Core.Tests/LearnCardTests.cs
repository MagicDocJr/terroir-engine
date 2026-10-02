using System.Text.Json.Nodes;
using TerroirEngine.Learning;

namespace TerroirEngine.Tests;

/// <summary>Learn cards: the mechanical quality gate, the "On this site" line and the brief depth (learning-core design §7).</summary>
public class LearnCardTests
{
    [Fact]
    public void Cards_PassTheMechanicalGate()
    {
        var cards = LearnCards.All(Fixture.Data);
        Assert.True(cards.Count >= 12, $"{cards.Count} cards");
        var problems = cards.SelectMany(c => LearnCards.Problems(Fixture.Data, c).Select(p => $"{c.Id}: {p}")).ToList();
        Assert.True(problems.Count == 0, string.Join("\n", problems));
        Assert.Equal(cards.Count, cards.Select(c => c.Id).Distinct().Count());
    }

    [Fact]
    public void Card_SiteLine_UsesPlayerData()
    {
        var yan = LearnCards.SiteLine("yeast-nitrogen", new SiteFacts(LotId: "A-2015", Yan: 120, Sugar: 220));
        Assert.Contains("120", yan);
        Assert.Contains("short", yan);   // at about 22 °Brix the game's need is about 200 mg/L
        var steep = LearnCards.SiteLine("training-system", new SiteFacts(BlockId: "B", BlockSlope: 58, TrainingAllowed: new[] { "Einzelpfahl" }));
        Assert.Contains("58 %", steep);
        Assert.Contains("Einzelpfahl", steep);
        // from real data: a Côte d'Or Block's soil
        var f = LearnCards.Facts(Fixture.Data, new JsonObject { ["plot"] = "cotedor-village", ["block"] = "A" }, null);
        var rs = LearnCards.SiteLine("rootstock", f);
        Assert.Contains("active lime", rs);
        Assert.Contains("chlorosis index", rs);
        // 4 % active lime is index 16: 3309C (limit 10) yellows, the others cope
        Assert.Contains("3309C would turn yellow", LearnCards.SiteLine("rootstock", new SiteFacts(BlockId: "B", ActiveLime: 4, Taw: 150)));
    }

    [Fact]
    public void Card_SiteLine_MissingContext_General()
    {
        foreach (var c in LearnCards.All(Fixture.Data))
        {
            var line = LearnCards.SiteLine(c.Id, LearnCards.Facts(Fixture.Data, new JsonObject(), null));
            Assert.False(string.IsNullOrWhiteSpace(line), c.Id);
            Assert.NotNull(LearnCards.Card(Fixture.Data, c.Id, new JsonObject { ["lot"] = "no-such-lot", ["block"] = "Z" }, new JsonObject(), null));
        }
        Assert.Null(LearnCards.Card(Fixture.Data, "no-such-card", new JsonObject(), new JsonObject(), null));
    }

    [Fact]
    public void Card_Brief_WhenItsCausesAreKnown()
    {
        var c = LearnCards.All(Fixture.Data).First(x => x.Causes.Length > 0);
        Assert.Equal("full", LearnCards.Card(Fixture.Data, c.Id, new JsonObject(), new JsonObject(), null)!["depth"]!.GetValue<string>());
        var rec = new JsonObject();
        var d0 = new DateOnly(2026, 10, 5);
        foreach (var d in new[] { 0, 1, 4 })
            rec = TerroirEngine.Tasting.Practice.PracticeProgress.Apply(rec, new JsonObject
            {
                ["kind"] = "practice", ["date"] = d0.AddDays(d).ToString("yyyy-MM-dd"),
                ["items"] = new JsonArray(c.Causes.Select(id => (JsonNode)new JsonObject { ["skill"] = "nose", ["score"] = 1, ["confidence"] = 3, ["causes"] = new JsonArray(id) }).ToArray()),
            });
        Assert.Equal("brief", LearnCards.Card(Fixture.Data, c.Id, new JsonObject(), rec, null)!["depth"]!.GetValue<string>());
    }
}
