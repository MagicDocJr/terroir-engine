using System.Collections.Concurrent;
using System.Text.Json;
using TerroirEngine.Data;

namespace TerroirEngine.Tasting.Practice;

public sealed record NoteSource(string Id, string Title, string Url);

/// <summary>A real vintage note: what really happened, with its sources (docs/science/vintage-notes.md).</summary>
public sealed record VintageNote(string RegionId, int Year, string Note, IReadOnlyList<NoteSource> Sources);

/// <summary>Loads data/vintage_notes.json. Only sourced notes load: a row marked unverified, without text or without a source that
/// resolves to a URL is never shown (tasting-practice design §8).</summary>
public static class VintageNotes
{
    private static readonly ConcurrentDictionary<string, IReadOnlyList<VintageNote>> Cache = new();

    public static IReadOnlyList<VintageNote> All(GameData data) => Cache.GetOrAdd(data.DataRoot, root =>
    {
        var path = Path.Combine(root, "vintage_notes.json");
        if (!File.Exists(path)) return Array.Empty<VintageNote>();
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var sources = new Dictionary<string, NoteSource>();
        if (doc.RootElement.TryGetProperty("sources", out var src))
            foreach (var s in src.EnumerateObject())
            {
                string title = s.Value.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "";
                string url = s.Value.TryGetProperty("url", out var u) ? u.GetString() ?? "" : "";
                if (url.StartsWith("http")) sources[s.Name] = new NoteSource(s.Name, title, url);
            }
        var list = new List<VintageNote>();
        foreach (var n in doc.RootElement.GetProperty("notes").EnumerateArray())
        {
            if (n.TryGetProperty("unverified", out var uv) && uv.ValueKind == JsonValueKind.True) continue;
            string note = n.TryGetProperty("note", out var nt) ? nt.GetString() ?? "" : "";
            var refs = n.TryGetProperty("sources", out var sr) ? sr.EnumerateArray().Select(x => x.GetString() ?? "").Where(sources.ContainsKey).Select(k => sources[k]).ToList() : new();
            if (note.Length == 0 || refs.Count == 0) continue;
            list.Add(new VintageNote(n.GetProperty("region").GetString()!, n.GetProperty("year").GetInt32(), note, refs));
        }
        return list;
    });

    public static VintageNote? For(GameData data, string regionId, int year) => All(data).FirstOrDefault(n => n.RegionId == regionId && n.Year == year);
}
