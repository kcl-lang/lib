namespace KclLib.Facade;

using System.Collections;
using System.Text.Json;

/// <summary>
/// The collection of <see cref="KclResult"/> documents produced by a single
/// run, mirroring kcl-go's <c>KCLResultList</c>. A multi-document program
/// (several input files or several <c>WithCode</c> sources) yields one entry
/// per YAML document; the raw runtime output stays available through
/// <see cref="GetRawJsonResult"/> / <see cref="GetRawYamlResult"/>.
/// </summary>
public class KclResultList : IReadOnlyList<KclResult>
{
    private readonly IReadOnlyList<KclResult> results;
    private readonly string rawJsonResult;
    private readonly string rawYamlResult;

    internal KclResultList(IReadOnlyList<KclResult> results, string rawJsonResult, string rawYamlResult)
    {
        this.results = results;
        this.rawJsonResult = rawJsonResult;
        this.rawYamlResult = rawYamlResult;
    }

    /// <summary>Number of documents in the result.</summary>
    public int Count => results.Count;

    /// <summary>Document at <paramref name="index"/>; throws when out of range. Use <see cref="Get(int)"/> for a null-on-miss variant.</summary>
    public KclResult this[int index] => results[index];

    public IEnumerator<KclResult> GetEnumerator() => results.GetEnumerator();

    IEnumerator IEnumerable.GetEnumerator() => results.GetEnumerator();

    /// <summary>Document at <paramref name="index"/>, or <c>null</c> when out of range.</summary>
    public KclResult? Get(int index)
    {
        return index >= 0 && index < results.Count ? results[index] : null;
    }

    /// <summary>The first document, or <c>null</c> when the result is empty.</summary>
    public KclResult? First()
    {
        return results.Count > 0 ? results[0] : null;
    }

    /// <summary>The last document, or <c>null</c> when the result is empty (unlike LINQ's <c>Last()</c>, which throws).</summary>
    public KclResult? Last()
    {
        return results.Count > 0 ? results[^1] : null;
    }

    /// <summary>Convert the first document to a map, mirroring kcl-go's <c>KCLResultList.ToMap</c>.</summary>
    /// <exception cref="KclException">The result is empty or the first document is not a map.</exception>
    public Dictionary<string, object?> ToMap()
    {
        return RequireFirst().ToMap();
    }

    /// <summary>Convert the first document to a list, mirroring kcl-go's <c>KCLResultList.ToList</c>.</summary>
    /// <exception cref="KclException">The result is empty or the first document is not a list.</exception>
    public List<object?> ToList()
    {
        return RequireFirst().ToList();
    }

    /// <summary>The unmodified <c>json_result</c> payload returned by the runtime (JSON Lines for multi-document results).</summary>
    public string GetRawJsonResult() => rawJsonResult;

    /// <summary>The unmodified <c>yaml_result</c> payload returned by the runtime (documents separated by <c>---</c>).</summary>
    public string GetRawYamlResult() => rawYamlResult;

    private KclResult RequireFirst()
    {
        if (results.Count == 0)
        {
            throw new KclException("result is nil");
        }
        return results[0];
    }
}
