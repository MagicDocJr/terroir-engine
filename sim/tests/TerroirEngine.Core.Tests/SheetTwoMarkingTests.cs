using System.Text.Json.Nodes;
using TerroirEngine.Learning;
using TerroirEngine.Tasting;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>Marking the Tasting sheet 2 lines (spec §4).</summary>
public class SheetTwoMarkingTests
{
    private static readonly Lazy<PouredWine> White = new(() => TastingLab.Pour(Fixture.Data, new PourSpec("mosel-blauschiefer", 2018, Variety: "Riesling", Style: "kabinett"), 1));
    private static JsonArray Arr(IEnumerable<string> xs) => new(xs.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());
    private static double Score(PouredWine p, string exercise, string key, JsonObject answers) =>
        TastingMarker.Mark(Fixture.Data, p, exercise, answers).Items.First(x => x.Key == key).Score;

    [Fact]
    public void Options_UseTheNewVocabulary()
    {
        var w = TastingMarker.Options(Fixture.Data, false); var r = TastingMarker.Options(Fixture.Data, true);
        var wa = w["aromas"]!.AsArray().Select(x => (string)x!).ToList(); var ra = r["aromas"]!.AsArray().Select(x => (string)x!).ToList();
        Assert.Contains("stone fruit", wa); Assert.Contains("simple", wa); Assert.DoesNotContain("fruit", wa);
        Assert.Contains("black fruit", ra); Assert.DoesNotContain("red and black fruit", ra);
        Assert.Equal(TastingSheet.ReadinessOptions, w["readiness"]!.AsArray().Select(x => (string)x!));
        Assert.Contains("brown", w["colour"]!.AsArray().Select(x => (string)x!));
        Assert.Equal(TastingSheet.FruitRipenessScale, w["fruitRipeness"]!.AsArray().Select(x => (string)x!));
        Assert.DoesNotContain("simple", w["flavours"]!.AsArray().Select(x => (string)x!));
        Assert.DoesNotContain("volatile", w["flavours"]!.AsArray().Select(x => (string)x!));
    }

    [Fact]
    public void FullSheet_AsksFruitRipenessAndFlavours()
    {
        var k = TastingMarker.Keys("sheet", false);
        Assert.True(k.ToList().IndexOf("fruitRipeness") == k.ToList().IndexOf("aromas") + 1);
        Assert.Contains("flavours", k);
        Assert.DoesNotContain("flavours", TastingMarker.Keys("cause", true));
    }

    [Fact]
    public void FruitRipeness_IsAnOrderedScale()
    {
        var p = White.Value; var sc = TastingSheet.FruitRipenessScale; int i = Array.IndexOf(sc, p.Sheet.FruitRipeness);
        Assert.Equal(1, Score(p, "sheet", "fruitRipeness", new JsonObject { ["fruitRipeness"] = sc[i] }));
        Assert.Equal(0.5, Score(p, "sheet", "fruitRipeness", new JsonObject { ["fruitRipeness"] = sc[i > 0 ? i - 1 : i + 1] }));
    }

    [Fact]
    public void Flavours_MarkedByOverlap()
    {
        var p = White.Value;
        Assert.Equal(1, Score(p, "sheet", "flavours", new JsonObject { ["flavours"] = Arr(p.Sheet.Flavours) }));
        Assert.True(Score(p, "sheet", "flavours", new JsonObject { ["flavours"] = Arr(p.Sheet.Flavours.Append("oak")) }) < 1);
    }

    [Fact]
    public void Simple_IsRightOnlyOnASimpleWine()
    {
        PouredWine? simple = null, complex = null;
        for (int seed = 1; seed <= 40 && (simple == null || complex == null); seed++)
        {
            var p = TastingLab.Pour(Fixture.Data, PracticePours.Random(Fixture.Data, seed), seed);
            if (p.Sheet.Simple) simple ??= p; else complex ??= p;
        }
        Assert.NotNull(simple); Assert.NotNull(complex);
        var sf = simple!.Sheet.Aromas.Select(a => a.Family).Distinct().ToList();
        Assert.Equal(1, Score(simple, "sheet", "aromas", new JsonObject { ["aromas"] = Arr(sf.Append("simple")) }));
        Assert.True(Score(simple, "sheet", "aromas", new JsonObject { ["aromas"] = Arr(sf) }) < 1);
        var cf = complex!.Sheet.Aromas.Select(a => a.Family).Distinct().ToList();
        Assert.Equal(1, Score(complex, "sheet", "aromas", new JsonObject { ["aromas"] = Arr(cf) }));
        Assert.True(Score(complex, "sheet", "aromas", new JsonObject { ["aromas"] = Arr(cf.Append("simple")) }) < 1);
    }

    [Fact]
    public void FaultyWine_HasNoReadinessItem()
    {
        var p = White.Value;
        var faulty = new PouredWine { Wine = p.Wine, Context = p.Context, Sheet = p.Sheet };
        string q = p.Sheet.Quality, r = p.Sheet.Readiness;
        try
        {
            faulty.Sheet.Quality = "Faulty"; faulty.Sheet.Readiness = "";
            var m = TastingMarker.Mark(Fixture.Data, faulty, "conclusions", new JsonObject { ["readiness"] = "too old" });
            Assert.DoesNotContain(m.Items, x => x.Key == "readiness");
            Assert.DoesNotContain("readiness", TastingMarker.KeysFor(faulty, "conclusions"));
        }
        finally { p.Sheet.Quality = q; p.Sheet.Readiness = r; }
    }

    [Fact]
    public void Predictions_LeadAroma_IsNeverAFruitFamily()
    {
        var p = White.Value;
        var lead = Predictions.LeadAroma(p.Sheet);
        if (lead != null && p.Sheet.Aromas.Any(a => !TastingSheet.IsFruit(a.Family))) Assert.False(TastingSheet.IsFruit(lead.Family));
    }

    [Fact]
    public void ShownJson_DescribesTheNewLines_ForConclusions_AndHidesThemForTheFullSheet()
    {
        var p = White.Value;
        var c = PracticeJson.Shown(p, "conclusions", false, false);
        Assert.NotNull(c["sheet"]!["flavours"]);
        Assert.NotNull(c["sheet"]!["fruitRipeness"]);
        var s = PracticeJson.Shown(p, "sheet", false, false);
        Assert.Null(s["sheet"]);
        var full = TerroirEngine.Game.Snapshot.WineObj(p.Wine)["sheet"]!;
        Assert.NotNull(full["qualityFor"]); Assert.NotNull(full["observations"]); Assert.NotNull(full["flavours"]);
    }
}
