using TerroirEngine.Game;

namespace TerroirEngine.Tests;

/// <summary>The 3D sky's cloud cover comes from the day's measured radiation (look only).</summary>
public class SkyDataTests
{
    [Fact]
    public void Today_CarriesTheClearSkyFraction_SunnyDaysClearerThanRainyOnes()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "cotedor-village", PlantingYear = 2013 });
        var sunny = new List<double>(); var rainy = new List<double>();
        for (int i = 0; i < 200; i++)
        {
            var t = Snapshot.Build(g)["weather"]!["today"]!;
            double c = t["clear"]!.GetValue<double>();
            Assert.InRange(c, 0.0, 1.0);
            (t["icon"]!.GetValue<string>() == "rain" ? rainy : t["icon"]!.GetValue<string>() == "sun" ? sunny : new List<double>()).Add(c);
            g.Advance(1, stopAtAlerts: false);
        }
        Assert.True(sunny.Average() > rainy.Average() + 0.2, $"sunny {sunny.Average():0.00} rainy {rainy.Average():0.00}");
    }
}
