using System.Text.Json.Nodes;
using TerroirEngine.Game;

namespace TerroirEngine.Tests;

/// <summary>Vintage in review (docs/superpowers/specs/2026-10-03-vintage-in-review-design.md): cause cards linked to the
/// Tasting-sheet lines they shaped.</summary>
public class VintageReviewTests
{
    private static readonly Lazy<GameSession> Frost = new(() => ScenarioTests.Play("cotedor-2016", 94));
    private static readonly Lazy<GameSession> Hot = new(() => ScenarioTests.Play("mosel-2018", 84));

    private static JsonArray Cards(GameSession g, int v) => VintageReview.Cards(g, v);
    private static List<string> Ids(JsonNode card) => card["causes"]!.AsArray().Select(c => (string)c!["id"]!).ToList();

    [Fact]
    public void SameMoment_SharesOneCard_EvidenceNeverRepeated()
    {
        foreach (var (g, v) in new[] { (Frost.Value, 2016), (Hot.Value, 2018) })
        {
            var cards = Cards(g, v);
            var all = cards.SelectMany(c => c!["happened"]!.AsArray().Select(h => (string)h!)).ToList();
            Assert.Equal(all.Count, all.Distinct().Count());
            Assert.True(cards.Count(c => (string)c!["title"]! == "The harvest") <= 1);
        }
    }

    [Fact]
    public void FrostYear_HasAFrostCard_WithTheNightAndTheLoss()
    {
        var cards = Cards(Frost.Value, 2016);
        var frost = cards.First(c => Ids(c!).Contains("spring-frost-yield"))!;
        Assert.Contains("April", (string)frost["date"]!);
        Assert.Contains(frost["happened"]!.AsArray(), l => ((string)l!).Contains("Young shoots killed"));
        Assert.NotEmpty(frost["lines"]!.AsArray());
    }

    [Fact]
    public void HotYear_HasAWarmSeasonCard()
    {
        var cards = Cards(Hot.Value, 2018);
        Assert.Contains(cards, c => Ids(c!).Contains("warm-season-malic-loss"));
    }

    [Fact]
    public void EveryCard_IsLinkedToACauseOnASheetOfTheVintage()
    {
        foreach (var (g, v) in new[] { (Frost.Value, 2016), (Hot.Value, 2018) })
        {
            var causes = g.Wines.Where(w => w.Vintage == v && w.Sheet != null).SelectMany(w => w.Sheet!.Causes).ToHashSet();
            var cards = Cards(g, v);
            Assert.InRange(cards.Count, 1, 8);
            foreach (var c in cards)
            {
                Assert.All(Ids(c!), id => Assert.Contains(id, causes));
                Assert.NotEmpty(c!["lines"]!.AsArray());
                Assert.All(c["lines"]!.AsArray(), l => Assert.False(string.IsNullOrEmpty((string?)l!["attribute"])));
            }
        }
    }

    [Fact]
    public void Cards_AreSortedByPriorityThenDate()
    {
        var cards = Cards(Frost.Value, 2016);
        var keys = cards.Select(c => ((int)c!["priority"]!, (string)c["when"]!)).ToList();
        Assert.Equal(keys.OrderBy(k => k.Item1).ThenBy(k => k.Item2, StringComparer.Ordinal).ToList(), keys);
    }

    [Fact]
    public void CardText_IsDescriptive_NeverAVerdict()
    {
        string[] verdict = { "mistake", "should", "wrong", "bad", "poor choice", "failed", "error" };
        foreach (var (g, v) in new[] { (Frost.Value, 2016), (Hot.Value, 2018) })
            foreach (var c in Cards(g, v))
            {
                var text = string.Join(" ", c!["happened"]!.AsArray().Select(x => (string)x!)) + " " + (string)c["title"]!;
                foreach (var w in verdict) Assert.DoesNotContain(w, text, StringComparison.OrdinalIgnoreCase);
            }
    }

    [Fact]
    public void NoBottledWine_NoReview()
    {
        var g = new GameSession(Fixture.Data, Scenarios.Setup(Fixture.Data, "napa-2011"));
        Assert.Empty(Cards(g, 2011));
        Assert.Null(VintageReport.Build(g, 2011)["review"]);
        Assert.NotNull(VintageReport.Build(Frost.Value, 2016)["review"]);
        Assert.NotNull(VintageReport.Build(Frost.Value, 2016)["review"]!["strip"]);
    }
}
