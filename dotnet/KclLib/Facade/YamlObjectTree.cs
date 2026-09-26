namespace KclLib.Facade;

using System.Globalization;
using YamlDotNet.Core;
using YamlDotNet.Core.Events;
using YamlDotNet.Serialization;

/// <summary>
/// YAML facade for the two untyped parsing needs of <c>KclLib.Facade</c>:
/// the fallback reader for YAML-only <c>ExecProgramResult</c> documents and
/// the values inside <c>kcl_options</c> entries. Both consume the generic
/// object tree produced here — nested <see cref="Dictionary{TKey,TValue}"/> /
/// <see cref="List{T}"/> structures with scalar leaves typed exactly like
/// kcl-go's <c>yaml.v3</c> unmarshalling into <c>any</c>: quoted scalars stay
/// strings, plain scalars infer null/bool/long/double, everything else
/// falls back to string.
///
/// Implemented as an <see cref="INodeDeserializer"/> sitting on top of the
/// pipeline (registered with <c>OnTop</c>) that only claims
/// <see cref="object"/> targets: typed models (the <c>kcl_cli_configs</c>
/// binding) keep flowing through YamlDotNet's regular deserializers.
/// </summary>
internal static class YamlObjectTree
{
    private static readonly IDeserializer Deserializer = new DeserializerBuilder()
        .WithNodeDeserializer(new ObjectTreeNodeDeserializer(), location => location.OnTop())
        .IgnoreUnmatchedProperties()
        .Build();

    /// <summary>Parse YAML into a generic object tree.</summary>
    public static object? Parse(string text)
    {
        return Deserializer.Deserialize<object>(text);
    }

    /// <summary>Parse YAML into a typed model (<c>kcl_cli_configs</c> binding).</summary>
    public static T Deserialize<T>(string text)
    {
        return Deserializer.Deserialize<T>(text);
    }

    private sealed class ObjectTreeNodeDeserializer : INodeDeserializer
    {
        public bool Deserialize(IParser reader, Type expectedType, Func<IParser, Type, object?> nestedObjectDeserializer, out object? value, ObjectDeserializer rootDeserializer)
        {
            switch (reader.Current)
            {
                case Scalar scalar when expectedType == typeof(object):
                    reader.MoveNext();
                    value = ToScalar(scalar);
                    return true;
                case MappingStart when IsDictionaryType(expectedType):
                    // The pipeline rewrites object/dictionary targets to a
                    // concrete dictionary type before node deserializers are
                    // consulted, so the mapping claim cannot be object-only.
                    reader.MoveNext();
                    var map = new Dictionary<string, object?>();
                    while (reader.Current is not MappingEnd)
                    {
                        var key = nestedObjectDeserializer(reader, typeof(object));
                        var item = nestedObjectDeserializer(reader, typeof(object));
                        map[KeyToString(key)] = item;
                    }
                    reader.MoveNext();
                    value = map;
                    return true;
                case SequenceStart when expectedType == typeof(object):
                    reader.MoveNext();
                    var list = new List<object?>();
                    while (reader.Current is not SequenceEnd)
                    {
                        list.Add(nestedObjectDeserializer(reader, typeof(object)));
                    }
                    reader.MoveNext();
                    value = list;
                    return true;
                default:
                    value = null;
                    return false;
            }
        }

        private static bool IsDictionaryType(Type type)
        {
            return type == typeof(object)
                || (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(Dictionary<,>));
        }

        private static string KeyToString(object? key)
        {
            return key switch
            {
                null => "",
                string s => s,
                bool b => b ? "true" : "false",
                long l => l.ToString(CultureInfo.InvariantCulture),
                double d => d.ToString(CultureInfo.InvariantCulture),
                _ => key.ToString() ?? "",
            };
        }

        private static object? ToScalar(Scalar scalar)
        {
            string value = scalar.Value ?? "";
            // Quoted scalars are always strings, even when they look typed.
            if (scalar.Style != ScalarStyle.Plain)
            {
                return value;
            }
            switch (value)
            {
                case "":
                case "null":
                case "Null":
                case "NULL":
                case "~":
                    return null;
                case "true":
                case "True":
                case "TRUE":
                    return true;
                case "false":
                case "False":
                case "FALSE":
                    return false;
            }
            if (long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var l))
            {
                return l;
            }
            if ((value.Contains('.') || value.Contains('e') || value.Contains('E'))
                && double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var d))
            {
                return d;
            }
            return value;
        }
    }
}
