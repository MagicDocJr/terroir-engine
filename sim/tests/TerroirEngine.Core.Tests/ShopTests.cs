using TerroirEngine.Game;

namespace TerroirEngine.Tests;

/// <summary>The Shop (docs/superpowers/specs/2026-10-07-equipment-shop-design.md): cozy looks bought with the Estate's cash.</summary>
public class ShopTests
{
    private static GameSession New(string plot = "mosel-seitental") => new(Fixture.Data, new GameSetup { PlotId = plot, PlantingYear = 2014, ShopVersion = 1 });
    private static GameSession Legacy(string plot = "mosel-seitental") => new(Fixture.Data, new GameSetup { PlotId = plot, PlantingYear = 2014 });
    private static string InUse(GameSession g, string key) => Snapshot.Build(g)["shop"]!["inUse"]![key]!.GetValue<string>();

    [Fact]
    public void NewGame_OwnsTheRegionsWallsAndFloor_AndThePlainLookElsewhere()
    {
        var g = New();
        Assert.Equal("slate", InUse(g, "walls"));
        Assert.Equal("slate", InUse(g, "floor"));
        Assert.Equal("steel", InUse(g, "ceiling"));
        Assert.Equal("off", InUse(g, "outside"));
        Assert.True(g.OwnsLook("walls", "slate"));
        Assert.True(g.OwnsLook("walls", "render"));
        Assert.False(g.OwnsLook("ceiling", "oak"));
        Assert.False(g.OwnsLook("walls", "limestone"));
        Assert.True(g.OwnsEquipment("candles"));
        Assert.False(g.OwnsEquipment("wind-machine"));
    }

    [Fact]
    public void Buy_DebitsCash_PutsItInUse_AndReplays()
    {
        var g = New();
        double cash = g.Ledger.Cash, price = Shop.Catalog(Fixture.Data).Option("ceiling", "oak")!.Price;
        g.Apply(new Command { Type = "buy", A = "ceiling", B = "oak" });
        Assert.Equal(cash - price, g.Ledger.Cash, 2);
        Assert.Contains(g.Ledger.Entries, e => e.Category == Shop.LookCategory && e.Amount == -price);
        Assert.Equal("oak", InUse(g, "ceiling"));
        g.Apply(new Command { Type = "decor", A = "ceiling", B = "steel" });   // switch back freely
        Assert.Equal("steel", InUse(g, "ceiling"));
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.True(g2.OwnsLook("ceiling", "oak"));
        Assert.Equal("steel", InUse(g2, "ceiling"));
        Assert.Equal(g.Ledger.Cash, g2.Ledger.Cash, 2);
    }

    [Fact]
    public void Buy_Twice_ChargesOnce()
    {
        var g = New();
        g.Apply(new Command { Type = "buy", A = "plants", B = "on" });
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "buy", A = "plants", B = "on" });
        Assert.Equal(cash, g.Ledger.Cash);
    }

    [Fact]
    public void Buy_WithTooLittleCash_IsRefused_WithTheGap()
    {
        var g = New();
        double price = Shop.Catalog(Fixture.Data).Option("facade", "ashlar")!.Price;
        g.Ledger.Post(g.Date, "Test", -(g.Ledger.Cash - price + 1000), "drain");   // 1,000 short
        Assert.Equal(1000, g.ShopGap("facade", "ashlar"), 2);
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "buy", A = "facade", B = "ashlar" });
        Assert.Equal(cash, g.Ledger.Cash);
        Assert.False(g.OwnsLook("facade", "ashlar"));
        Assert.Contains("1,000", g.ShopRefusal);
    }

    [Fact]
    public void Decor_NotOwned_IsRefused_AndTheLookKeepsItsValue()
    {
        var g = New();
        g.Apply(new Command { Type = "decor", A = "corner", B = "lounge" });
        Assert.Equal("none", InUse(g, "corner"));
        Assert.False(g.Decor.ContainsKey("corner"));
    }

    [Fact]
    public void Buy_UnknownItem_IsIgnored()
    {
        var g = New();
        double cash = g.Ledger.Cash;
        g.Apply(new Command { Type = "buy", A = "walls", B = "gold" });
        g.Apply(new Command { Type = "buy", A = "hologram", B = "on" });
        g.Apply(new Command { Type = "buy", A = "equipment", B = "jetpack" });
        Assert.Equal(cash, g.Ledger.Cash);
    }

    [Fact]
    public void OldSave_OwnsItsLook_AndNothingDisappears()
    {
        var g = Legacy("cotedor-village");   // a game from before the shop: the full cozy regional look, and a lounge chosen
        g.Apply(new Command { Type = "decor", A = "corner", B = "lounge" });
        var before = Snapshot.Build(g)["shop"]!["inUse"]!.ToJsonString();
        var g2 = GameSession.Load(Fixture.Data, g.Save());
        Assert.Equal(1, g2.Setup.ShopVersion);
        Assert.Equal(before, Snapshot.Build(g2)["shop"]!["inUse"]!.ToJsonString());
        Assert.True(g2.OwnsLook("corner", "lounge"));
        Assert.True(g2.OwnsLook("corner", "table"));           // the regional default it had for free
        Assert.True(g2.OwnsLook("lights", "chandelier"));
        Assert.False(g2.OwnsLook("walls", "redwood"));        // never chosen: for sale
        Assert.True(g2.OwnsEquipment("candles"));
        Assert.False(g2.OwnsEquipment("wind-machine"));
        // a second load keeps it
        var g3 = GameSession.Load(Fixture.Data, g2.Save());
        Assert.Equal(before, Snapshot.Build(g3)["shop"]!["inUse"]!.ToJsonString());
        g3.Apply(new Command { Type = "decor", A = "walls", B = "redwood" });
        Assert.Equal("limestone", InUse(g3, "walls"));
    }

    [Fact]
    public void Snapshot_ListsSections_WithOwnedInUseAndAffordable()
    {
        var g = New();
        var shop = Snapshot.Build(g)["shop"]!;
        var walls = shop["look"]!.AsArray().First(s => (string)s!["key"]! == "walls")!;
        var slate = walls["options"]!.AsArray().First(o => (string)o!["value"]! == "slate")!;
        Assert.True((bool)slate["owned"]!);
        Assert.True((bool)slate["inUse"]!);
        var lime = walls["options"]!.AsArray().First(o => (string)o!["value"]! == "limestone")!;
        Assert.False((bool)lime["owned"]!);
        Assert.True((bool)lime["affordable"]!);
        Assert.NotEmpty(shop["equipment"]!.AsArray());
    }

    [Fact]
    public void PriceBand_TheFullLookCosts_OneToThreeTypicalVintages()
    {
        // a typical Vintage's sales on a small Estate (mosel-blauschiefer, the scripted player: about €160k)
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2015, ShopVersion = 1 });
        Scenarios.Autoplay(g, 85);
        double sales = g.Ledger.Entries.Where(e => e.Category == "Sales").Sum(e => e.Amount);
        double full = Shop.Catalog(Fixture.Data).Look.Sum(s => s.Options.Sum(o => o.Price));
        Assert.InRange(full, sales, 3 * sales);
        // the first treat is affordable after one Vintage: the cheapest item costs under 2 % of it
        Assert.True(Shop.Catalog(Fixture.Data).Look.SelectMany(s => s.Options).Where(o => o.Price > 0).Min(o => o.Price) < 0.02 * sales);
    }

    [Fact]
    public void FirstSaleOfAVintage_InvitesYouToTheShop_Once()
    {
        var g = new GameSession(Fixture.Data, new GameSetup { PlotId = "mosel-blauschiefer", PlantingYear = 2015, ShopVersion = 1 });
        Scenarios.Autoplay(g, 85);
        var bottled = g.Inbox.Where(m => m.Kind == "bottled").ToList();
        Assert.True(bottled.Count >= 2, "the scripted player bottles each Lot on its own");
        Assert.Single(bottled, m => m.Actions.Any(a => a.Action == "goto" && a.Arg == "shop"));
        Assert.Contains("treat", bottled.First(m => m.Actions.Any(a => a.Arg == "shop")).Body);
    }

    [Fact]
    public void Welcome_MentionsTheShop_OnlyInShopGames()
    {
        Assert.Contains(New().Inbox, m => m.Kind == "intro" && m.Body.Contains("Shop"));
        Assert.DoesNotContain(Legacy().Inbox, m => m.Kind == "intro" && m.Body.Contains("Shop"));
    }
}
