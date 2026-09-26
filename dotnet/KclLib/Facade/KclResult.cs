namespace KclLib.Facade;

using System.Text.Json;

/// <summary>
/// One evaluated configuration document. Mirrors kcl-go's <c>KCLResult</c>:
/// the document is held as a plain object tree (nested
/// <see cref="Dictionary{TKey,TValue}"/> / <see cref="List{T}"/> / scalars)
/// parsed with <see cref="System.Text.Json"/>, with dotted-key access via
/// <see cref="Get(string)"/> and structural conversions via
/// <see cref="ToMap"/> / <see cref="ToList"/>.
/// </summary>
public class KclResult
{
    private readonly string yamlDocument;
    private readonly string? jsonDocument;

    internal KclResult(object? value, string yamlDocument, string? jsonDocument)
    {
        Value = value;
        this.yamlDocument = yamlDocument;
        this.jsonDocument = jsonDocument;
    }

    /// <summary>The parsed document value (map, list or scalar).</summary>
    public object? Value { get; }

    /// <summary>The YAML rendering of this document as emitted by the runtime.</summary>
    public string YamlString() => yamlDocument;

    /// <summary>The JSON rendering of this document's value.</summary>
    public string JsonString()
    {
        return JsonSerializer.Serialize(Value, new JsonSerializerOptions { WriteIndented = true });
    }

    /// <summary>
    /// Look up <paramref name="key"/> in the document, where dots navigate
    /// nested mappings (<c>"a.b.c"</c>) and integer segments index into
    /// lists. Returns <c>null</c> when any segment is missing.
    /// </summary>
    public object? Get(string key)
    {
        object? current = Value;
        foreach (var segment in key.Split('.'))
        {
            switch (current)
            {
                case Dictionary<string, object?> map:
                    if (!map.TryGetValue(segment, out current))
                    {
                        return null;
                    }
                    break;
                case List<object?> list when int.TryParse(segment, out var index):
                    if (index < 0 || index >= list.Count)
                    {
                        return null;
                    }
                    current = list[index];
                    break;
                default:
                    return null;
            }
        }
        return current;
    }

    /// <summary>Get with a typed fallback: returns <c>null</c> when the value is missing or not of type <typeparamref name="T"/>.</summary>
    public T? Get<T>(string key)
    {
        return Get(key) is T typed ? typed : default;
    }

    /// <summary>Convert the document to a map, mirroring kcl-go's <c>KCLResult.ToMap</c>.</summary>
    /// <exception cref="KclException">The document is not a map.</exception>
    public Dictionary<string, object?> ToMap()
    {
        if (Value is Dictionary<string, object?> map)
        {
            return map;
        }
        throw new KclException($"failed to convert result to map: got {Value?.GetType().Name ?? "null"}");
    }

    /// <summary>Convert the document to a list, mirroring kcl-go's <c>KCLResult.ToList</c>.</summary>
    /// <exception cref="KclException">The document is not a list.</exception>
    public List<object?> ToList()
    {
        if (Value is List<object?> list)
        {
            return list;
        }
        throw new KclException($"failed to convert result to list: got {Value?.GetType().Name ?? "null"}");
    }

    internal static object? FromJson(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                var map = new Dictionary<string, object?>();
                foreach (var property in element.EnumerateObject())
                {
                    map[property.Name] = FromJson(property.Value);
                }
                return map;
            case JsonValueKind.Array:
                var list = new List<object?>();
                foreach (var item in element.EnumerateArray())
                {
                    list.Add(FromJson(item));
                }
                return list;
            case JsonValueKind.String:
                return element.GetString();
            case JsonValueKind.Number:
                if (element.TryGetInt64(out var l))
                {
                    return l;
                }
                return element.GetDouble();
            case JsonValueKind.True:
                return true;
            case JsonValueKind.False:
                return false;
            default:
                return null;
        }
    }
}
