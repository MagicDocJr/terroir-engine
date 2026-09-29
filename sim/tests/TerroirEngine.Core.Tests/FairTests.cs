using TerroirEngine.Tasting.Practice;
using TerroirEngine.Weather;

namespace TerroirEngine.Tests;

/// <summary>The Wine Fair: stands, vintage facts from the weather record, quizzes and real vintage notes
/// (tasting-practice design §5, §8).</summary>
public class FairTests
{
    private static Stand StandById(string id, int? maxVintage = null) => FairStands.All(Fixture.Data, maxVintage).First(s => s.Id == id);

    [Theory]
    [InlineData("mosel-cool-warm", "mosel")]
    [InlineData("napa-cool-hot", "napa")]
    public void CoolWarmPicks_AreTheRecordsMinAndMaxGrowingDegreeDays(string standId, string region)
    {
        // independent of VintageFacts: Winkler degree-days (Apr–Oct, base 10 °C) straight from the archive
        var arc = new WeatherArchive(Fixture.Data.DataRoot, Fixture.Data.Region(region).WeatherFile);
        double Gdd(int y)
        {
            double s = 0;
            for (var d = new DateOnly(y, 4, 1); d <= new DateOnly(y, 10, 31); d = d.AddDays(1)) { var w = arc.Get(d); s += Math.Max(0, (w.Tmax + w.Tmin) / 2 - 10); }
            return s;
        }
        var years = Enumerable.Range(1995, 31).ToList();
        int cool = years.MinBy(Gdd), warm = years.MaxBy(Gdd);
        Assert.Equal(new[] { cool, warm }, StandById(standId).Pours.Select(p => p.Vintage).ToArray());
    }

    [Fact]
    public void VintageFacts_CoteDor2016_FindsTheFrostNight()
    {
        var f = VintageFacts.For(Fixture.Data, "cote-dor", 2016);
        var (date, tmin) = VintageFacts.ColdestNight(Fixture.Data, "cote-dor", new DateOnly(2016, 4, 10), new DateOnly(2016, 5, 31));
        Assert.Equal(new DateOnly(2016, 4, 27), date);
        Assert.True(tmin < 0);
        Assert.InRange(f.Gdd, 900, 1800);
        Assert.InRange(f.GddRank, 1, f.RecordYears);
    }

    [Fact]
    public void FrostStand_Quiz_AsksAboutTheFrost_Answered2016WithTheDate()
    {
        var stand = StandById("frost-2016");
        var flight = FairStands.Pour(Fixture.Data, stand, 1);
        var quiz = VintageQuiz.For(Fixture.Data, stand, flight);
        var q = quiz.First(q => q.Topic == "frost");
        int i = stand.Pours.FindIndex(p => p.Vintage == 2016);
        Assert.Equal(VintageQuiz.Glass(i), q.Answer);
        Assert.Contains("27 April", q.Evidence);
    }

    [Fact]
    public void Stands_InAGame_LockFutureVintages()
    {
        var stands = FairStands.All(Fixture.Data, maxVintage: 2010);
        var frost = stands.First(s => s.Id == "frost-2016");
        Assert.True(frost.Locked);
        Assert.Equal(2017, frost.UnlockYear);
        Assert.DoesNotContain("2016", frost.Title + frost.Blurb + frost.Host.Greeting);   // the theme is future knowledge too
        Assert.DoesNotContain("frost", (frost.Title + frost.Blurb).ToLowerInvariant());
        Assert.Empty(frost.Pours);
        Assert.False(stands.First(s => s.Id == "burgundy-2003-2005").Locked);
        foreach (var s in stands.Where(s => !s.Locked)) Assert.All(s.Pours, p => Assert.True(p.Vintage <= 2010, $"{s.Id} pours {p.Vintage}"));
        Assert.Throws<InvalidOperationException>(() => FairStands.Pour(Fixture.Data, frost, 1));
        // from the title screen every stand is open
        Assert.All(FairStands.All(Fixture.Data), s => Assert.False(s.Locked));
    }

    [Fact]
    public void Notes_OnlySourcedNotesLoad()
    {
        var all = VintageNotes.All(Fixture.Data);
        Assert.NotEmpty(all);
        Assert.All(all, n => Assert.NotEmpty(n.Sources));
        Assert.All(all.SelectMany(n => n.Sources), s => Assert.StartsWith("http", s.Url));
        Assert.Null(VintageNotes.For(Fixture.Data, "mosel", 2005));      // an UNVERIFIED candidate in the doc
        Assert.Contains("April", VintageNotes.For(Fixture.Data, "cote-dor", 2016)!.Note);
    }

    [Fact]
    public void EveryStand_HasAPourableFlight_AndAQuizOfThreeToFive_WithTheAnswerAmongTheOptions()
    {
        foreach (var stand in FairStands.All(Fixture.Data))
        {
            Assert.InRange(stand.Pours.Count, 2, 4);
            Assert.False(string.IsNullOrEmpty(stand.Host.Name));
            var flight = FairStands.Pour(Fixture.Data, stand, 2);
            Assert.Equal(stand.Pours.Count, flight.Count);
            Assert.All(flight, p => Assert.Equal(stand.Host.Producer, p.Context.Producer));
            var quiz = VintageQuiz.For(Fixture.Data, stand, flight);
            Assert.True(quiz.Count is >= 3 and <= 5, $"{stand.Id}: {quiz.Count} questions ({string.Join(",", quiz.Select(q => q.Topic))})");
            Assert.All(quiz, q => { Assert.Contains(q.Answer, q.Options); Assert.False(string.IsNullOrEmpty(q.Evidence)); });
            Assert.Equal(quiz.Count, quiz.Select(q => q.Topic).Distinct().Count());
        }
    }
}
