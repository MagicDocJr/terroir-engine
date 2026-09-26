using TerroirEngine.Util;
using TerroirEngine.Vineyard;

namespace TerroirEngine.Winery;

/// <summary>Juice/wine composition used by the pH solver. Concentrations in g/L unless stated.</summary>
public struct AcidComposition
{
    public double Tartaric, Malic, Lactic, Acetic, Succinic, Citric, PotassiumGL, EthanolPctVol;
}

public readonly record struct MustAnalysis(double SugarGL, double Oe, double Brix, double PotentialAlcohol, double TaGL, double Ph, double MalicGL,
    double TartaricGL, double PotassiumGL, double YanMgL);

/// <summary>Acid–base chemistry (docs/science/acid-ph-so2.md): charge-balance pH solver (Boulton 1980 form), titratable acidity to
/// pH 8.2 as tartaric, molecular SO₂. pKa values are the standard enology values in water (UNVERIFIED as sourced in the doc).</summary>
public static class Chemistry
{
    private record Acid(double MolarMass, double[] PKa);
    private static readonly Acid Tart = new(150.09, new[] { 3.04, 4.37 });
    private static readonly Acid Mal = new(134.09, new[] { 3.40, 5.11 });
    private static readonly Acid Lac = new(90.08, new[] { 3.86 });
    private static readonly Acid Ace = new(60.05, new[] { 4.76 });
    private static readonly Acid Suc = new(118.09, new[] { 4.21, 5.64 });
    private static readonly Acid Cit = new(192.12, new[] { 3.13, 4.76, 6.40 });
    private const double PotassiumMolar = 39.10;
    // Minor cations in must (Na, Ca, Mg): ≈ 0.02 g/L Na, 0.08 g/L Ca, 0.08 g/L Mg (UNVERIFIED typical values)
    private const double MinorCationEq = 0.01 / 22.99 + 2 * 0.06 / 40.08 + 2 * 0.06 / 24.31;
    /// <summary>Empirical correction so solver pH matches measured must pH (activity effects; acid-ph-so2.md "regional correction").
    /// Calibrated to Mosel Riesling ≈ 3.0 and Napa Cabernet ≈ 3.7 at harvest. UNVERIFIED fit.</summary>
    public const double ActivityOffset = 0.0;

    private static double AnionCharge(Acid a, double molL, double h, double ethanolShift)
    {
        int n = a.PKa.Length;
        double[] ka = new double[n];
        for (int i = 0; i < n; i++) ka[i] = Math.Pow(10, -(a.PKa[i] + ethanolShift));
        // fractions of each protonation state
        double denom = Math.Pow(h, n), term = 1;
        var terms = new double[n + 1];
        terms[0] = Math.Pow(h, n);
        for (int i = 1; i <= n; i++) { term *= ka[i - 1]; terms[i] = term * Math.Pow(h, n - i); denom += terms[i]; }
        double charge = 0;
        for (int i = 1; i <= n; i++) charge += i * terms[i] / denom;
        return charge * molL;
    }

    private static double NetAnions(in AcidComposition c, double h)
    {
        double shift = 0.006 * c.EthanolPctVol;  // ethanol raises apparent pKa ≈ +0.1 at 8–12 % vol (acid-ph-so2.md; UNVERIFIED magnitude)
        return AnionCharge(Tart, c.Tartaric / Tart.MolarMass, h, shift) + AnionCharge(Mal, c.Malic / Mal.MolarMass, h, shift)
             + AnionCharge(Lac, c.Lactic / Lac.MolarMass, h, shift) + AnionCharge(Ace, c.Acetic / Ace.MolarMass, h, shift)
             + AnionCharge(Suc, c.Succinic / Suc.MolarMass, h, shift) + AnionCharge(Cit, c.Citric / Cit.MolarMass, h, shift);
    }

    public static double Ph(in AcidComposition c)
    {
        double cations = c.PotassiumGL / PotassiumMolar + MinorCationEq;
        double lo = 1.5, hi = 7.5;
        for (int i = 0; i < 60; i++)
        {
            double mid = (lo + hi) / 2, h = Math.Pow(10, -mid);
            double f = h + cations - 1e-14 / h - NetAnions(c, h);
            if (f > 0) lo = mid; else hi = mid;    // too many positive charges → pH must rise
        }
        return (lo + hi) / 2 + ActivityOffset;
    }

    /// <summary>Titratable acidity (g/L as tartaric): base needed to go from the solution's pH to the pH 8.2 end point.</summary>
    public static double TitratableAcidity(in AcidComposition c)
    {
        double ph = Ph(c) - ActivityOffset;
        double h0 = Math.Pow(10, -ph), h1 = Math.Pow(10, -8.2);
        double eq = (NetAnions(c, h1) - NetAnions(c, h0)) + (h0 - h1);
        return Math.Max(0, eq * 75.04 / 1.0 * 1.0 / 1.0 * 1.0) ;
    }

    public static double MolecularSo2(double freeSo2, double ph) => freeSo2 / (1 + Math.Pow(10, ph - 1.81));
    public static double FreeSo2ForMolecular(double molecular, double ph) => molecular * (1 + Math.Pow(10, ph - 1.81));

    /// <summary>Must composition of a Block's fruit right now (the weekly lab sample; spec §7: exact in Normal mode).</summary>
    public static MustAnalysis MustFromBlock(BlockState b)
    {
        double sugar = b.SugarGL;
        var c = new AcidComposition
        {
            Tartaric = b.TartaricGL, Malic = b.MalicGL, PotassiumGL = Math.Max(0.4, b.PotassiumGL > 0 ? b.PotassiumGL : 0.9),
            Citric = 0.3, Succinic = 0, Lactic = 0, Acetic = 0, EthanolPctVol = 0,
        };
        double ph = Ph(c), ta = TitratableAcidity(c);
        double brix = Units.BrixFromSugar(sugar), oe = Units.OeFromBrix(brix);
        double stress = b.StressPostDays > 0 ? b.StressPostSum / b.StressPostDays : 0;
        double yan = 230 * (1 - 0.35 * stress) * (1 - 0.3 * b.Chlorosis) * (1 - 0.5 * b.Disease.GreyRot) * (b.Variety.Red ? 0.9 : 1.0);
        return new MustAnalysis(sugar, oe, brix, Units.PotentialAlcohol(sugar), ta, ph, b.MalicGL, b.TartaricGL, c.PotassiumGL, yan);
    }
}
