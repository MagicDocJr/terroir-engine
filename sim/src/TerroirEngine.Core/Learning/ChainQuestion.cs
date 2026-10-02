namespace TerroirEngine.Learning;

public sealed record ChainBlank(int Index, List<string> Options, string Answer);

public sealed record ChainQ(string CauseId, string[] Steps, List<ChainBlank> Blanks);

/// <summary>A Cause's chain with its last steps blanked, each blank chosen from the right step and up to three plausible decoys:
/// steps in the same position of other Causes, those on the same kind of sheet line first (palate with palate, nose with nose).
/// Fading (learning-core design §4.4, research track A §4): a new Cause shows its chain with one blank (the effect in the glass),
/// a maturing one with two, then it moves on to Wines.</summary>
public static class ChainQuestion
{
    public static ChainQ For(Cause c, int blanks, int seed, IReadOnlyList<Cause> all)
    {
        int len = c.Chain.Length;
        int n = Math.Clamp(blanks, 1, Math.Max(1, len - 1));
        var rng = new Random(seed * 7919 + c.Id.Sum(ch => ch));
        string Kind(string line) => line.Contains(':') ? line[..line.IndexOf(':')] : line;
        var result = new List<ChainBlank>();
        for (int i = len - n; i < len; i++)
        {
            string? At(Cause o) => i == len - 1 ? o.Chain[^1] : i == 0 ? o.Chain[0] : o.Chain.Length > 2 ? o.Chain[Math.Min(i, o.Chain.Length - 2)] : null;
            var others = all.Where(o => o.Id != c.Id).ToList();
            var same = others.Where(o => Kind(o.Line) == Kind(c.Line)).Select(At).OrderBy(_ => rng.Next());
            var rest = others.Where(o => Kind(o.Line) != Kind(c.Line)).Select(At).OrderBy(_ => rng.Next());
            var decoys = same.Concat(rest).Where(x => !string.IsNullOrEmpty(x) && x != c.Chain[i]).Distinct().Take(3).Select(x => x!).ToList();
            var options = decoys.Append(c.Chain[i]).OrderBy(_ => rng.Next()).ToList();
            result.Add(new ChainBlank(i, options, c.Chain[i]));
        }
        return new ChainQ(c.Id, c.Chain, result);
    }
}
