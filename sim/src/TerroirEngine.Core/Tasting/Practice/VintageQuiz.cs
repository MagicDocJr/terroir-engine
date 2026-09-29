using System.Globalization;
using TerroirEngine.Data;

namespace TerroirEngine.Tasting.Practice;

/// <summary>One vintage-quiz question: the options are the Flight's glasses; the evidence quotes the numbers behind the answer.</summary>
public sealed record QuizQuestion(string Topic, string Text, IReadOnlyList<string> Options, string Answer, string Evidence);

/// <summary>Builds a stand's vintage quiz (3–5 questions) from the poured Wines' contexts and the weather record
/// (tasting-practice design §5). Answers come only from simulated or recorded data; a topic whose answer is not clear-cut in
/// this Flight (e.g. two summers within 0.8 °C) is skipped for the next one.</summary>
public static class VintageQuiz
{
    public const int MaxQuestions = 5, MinQuestions = 3;
    private static readonly string[] Fallback = { "picked-first", "ripest", "acid", "yield", "sweetest", "rain" };
    private static readonly CultureInfo Ci = CultureInfo.InvariantCulture;

    public static string Glass(int i) => $"Glass {i + 1}";

    public static List<QuizQuestion> For(GameData data, Stand stand, IReadOnlyList<PouredWine> flight)
    {
        var quiz = new List<QuizQuestion>();
        foreach (var topic in stand.Quiz.Concat(Fallback))
        {
            if (quiz.Count >= MaxQuestions || (quiz.Count >= MinQuestions && !stand.Quiz.Contains(topic))) break;
            if (quiz.Any(q => q.Topic == topic)) continue;
            var q = Make(data, topic, flight);
            if (q != null) quiz.Add(q);
        }
        return quiz;
    }

    private static string F(double v, string fmt = "0") => v.ToString(fmt, Ci).Replace("-", "−");
    private static string Ord(int n) => n + (n % 100 is 11 or 12 or 13 ? "th" : (n % 10) switch { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" });

    /// <summary>The glass with the largest (or smallest) value, if it leads the next one by at least the margin.</summary>
    private static int? Leader(IReadOnlyList<double> v, double margin, bool lowest = false)
    {
        var order = Enumerable.Range(0, v.Count).OrderBy(i => lowest ? v[i] : -v[i]).ToList();
        return Math.Abs(v[order[0]] - v[order[1]]) >= margin ? order[0] : null;
    }

    private static QuizQuestion? Make(GameData data, string topic, IReadOnlyList<PouredWine> flight)
    {
        int n = flight.Count;
        if (n < 2) return null;
        var ctx = flight.Select(p => p.Context).ToList();
        var options = Enumerable.Range(0, n).Select(Glass).ToList();
        bool distinctVintages = ctx.Select(c => c.Vintage).Distinct().Count() == n;
        string G(int i) => distinctVintages ? $"{Glass(i)} ({ctx[i].Vintage})" : Glass(i);
        string List(Func<int, string> val) => string.Join(", ", Enumerable.Range(0, n).Select(i => $"{G(i)} {val(i)}"));
        var facts = distinctVintages ? ctx.Select(c => VintageFacts.For(data, c.RegionId, c.Vintage)).ToList() : null;
        // the record rank only when it is remarkable (top three)
        string Rank(VintageFacts f, bool cool) => (cool ? f.RecordYears - f.GddRank + 1 : f.GddRank) > 3 ? "" : cool
            ? $" {f.Year} ranks {Ord(f.RecordYears - f.GddRank + 1)} coolest of the {f.RecordYears} years in the record ({f.RecordFrom}–{f.RecordTo})."
            : $" {f.Year} ranks {Ord(f.GddRank)} warmest of the {f.RecordYears} years in the record ({f.RecordFrom}–{f.RecordTo}).";
        QuizQuestion Q(string text, int answer, string evidence) => new(topic, text, options, Glass(answer), evidence);

        switch (topic)
        {
            case "summer" when facts != null:
                if (Leader(facts.Select(f => f.SummerTmax).ToList(), 0.8) is not int s) return null;
                return Q("Which glass comes from the hottest summer?", s,
                    $"Mean daily maximum, June–August, at the Region's weather station: {List(i => F(facts[i].SummerTmax, "0.0") + " °C")}." + Rank(facts[s], false));
            case "season" when facts != null:
            case "season-cool" when facts != null:
                bool cool = topic == "season-cool";
                if (Leader(facts.Select(f => f.Gdd).ToList(), 60, cool) is not int g) return null;
                return Q(cool ? "Which glass comes from the coolest growing season?" : "Which glass comes from the warmest growing season?", g,
                    $"Growing-degree days (April–October, above 10 °C): {List(i => F(facts[i].Gdd))}." + Rank(facts[g], cool));
            case "frost":
            {
                if (Leader(ctx.Select(c => c.FrostLossPct).ToList(), 10) is not int f || ctx[f].FrostLossPct < 10) return null;
                var c = ctx[f];
                var from = c.Budburst ?? new DateOnly(c.Vintage, 4, 1);
                var (night, tmin) = VintageFacts.ColdestNight(data, c.RegionId, from, new DateOnly(c.Vintage, 5, 31));
                return Q("Which glass comes from a vintage that lost crop to spring frost?", f,
                    $"Crop lost to frost: {List(i => F(ctx[i].FrostLossPct) + " %")}. In {c.Vintage} the buds had burst on " +
                    $"{from.ToString("d MMMM", Ci)}; the coldest night after that was {night.ToString("d MMMM", Ci)} ({F(tmin, "0.0")} °C at the Region's " +
                    "weather station, colder in the low spots where frost settles).");
            }
            case "yield":
                if (Leader(ctx.Select(c => c.YieldHlHa).ToList(), 5, lowest: true) is not int y) return null;
                return Q("Which glass comes from the smallest crop?", y,
                    $"Yield: {List(i => F(ctx[i].YieldHlHa) + " hL/ha")}." + (ctx[y].FrostLossPct >= 10 ? $" Frost took {F(ctx[y].FrostLossPct)} % of the {ctx[y].Vintage} crop." : ""));
            case "acid":
            case "acid-low":
                bool low = topic == "acid-low";
                if (Leader(ctx.Select(c => c.HarvestTa).ToList(), 0.5, low) is not int a) return null;
                return Q(low ? "Which glass was made from the least acidic grapes?" : "Which glass was made from the most acidic grapes?", a,
                    $"Titratable acidity of the must at harvest: {List(i => F(ctx[i].HarvestTa, "0.0") + " g/L")}. " +
                    (low ? "Heat burns malic acid off in the grapes as they ripen." : "Cooler seasons and earlier picking leave more malic acid in the grapes."));
            case "picked-first":
            {
                var d = ctx.Select(c => (double)c.HarvestDate.DayOfYear).ToList();
                if (Leader(d, 3, lowest: true) is not int p) return null;
                return Q("Which glass was picked earliest in its year?", p, $"Harvest dates: {List(i => ctx[i].HarvestDate.ToString("d MMMM", Ci))}.");
            }
            case "ripest":
            case "least-ripe":
                bool least = topic == "least-ripe";
                if (Leader(ctx.Select(c => c.HarvestOe).ToList(), 3, least) is not int r) return null;
                return Q(least ? "Which glass was picked least ripe?" : "Which glass was picked ripest?", r,
                    $"Must weight at harvest: {List(i => F(ctx[i].HarvestOe) + " °Oe")}.");
            case "sweetest":
                if (Leader(flight.Select(p => p.Wine.Blend.Rs).ToList(), 5) is not int w) return null;
                return Q("Which glass is the sweetest?", w, $"Residual sugar: {List(i => F(flight[i].Wine.Blend.Rs) + " g/L")}.");
            case "rain":
                if (Leader(ctx.Select(c => c.HarvestRainMm).ToList(), 15) is not int rn) return null;
                return Q("Which glass had the most rain in the three weeks before its harvest?", rn,
                    $"Rain in the 21 days before picking: {List(i => F(ctx[i].HarvestRainMm) + " mm")}.");
            case "new-oak":
            case "steel":
            case "old-oak":
            {
                var idx = Enumerable.Range(0, n).Where(i => ctx[i].StyleId == topic).ToList();
                if (idx.Count != 1) return null;
                string text = topic switch
                {
                    "new-oak" => "Which glass was fermented in new oak barrels?",
                    "steel" => "Which glass never touched wood?",
                    _ => "Which glass was fermented in old barrels?",
                };
                string Oak(int i) => flight[i].Sheet.Aromas.FirstOrDefault(x => x.Family == "oak") is { } o ? $"oak on the nose ({o.Terms})" : "no oak on the nose";
                return Q(text, idx[0], string.Join("; ", Enumerable.Range(0, n).Select(i => $"{Glass(i)}: {ctx[i].StyleLabel}, {Oak(i)}")) + ".");
            }
        }
        return null;
    }
}
