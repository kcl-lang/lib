namespace KclLib.Facade;

using System.Text.Json;
using KclLib.API;
using YamlDotNet.Serialization;

/// <summary>
/// Parsed <c>kcl.yaml</c> settings file, mirroring kcl-go's
/// <c>settings.SettingsFile</c>: a <c>kcl_cli_configs</c> mapping plus a
/// <c>kcl_options</c> list of <c>{key, value}</c> entries. Parsing uses
/// YamlDotNet with a typed model (like <c>yaml.v3</c> unmarshalling into
/// <c>ConfigStruct</c> in kcl-go); <c>kcl_options</c> values keep their
/// inferred scalar types via <see cref="YamlObjectTree"/>.
/// </summary>
internal sealed class KclSettingsFile
{
    public KclCliConfig Config = new();
    public List<KeyValueEntry> Options = new();

    /// <summary>Load and parse a settings file. Missing or empty files yield an empty config.</summary>
    public static KclSettingsFile Load(string path)
    {
        string text;
        try
        {
            text = File.ReadAllText(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException)
        {
            throw new KclException($"kcl.WithSettings({path}): {ex.Message}", ex);
        }
        if (string.IsNullOrWhiteSpace(text))
        {
            return new KclSettingsFile();
        }

        SettingsFileModel model;
        try
        {
            model = YamlObjectTree.Deserialize<SettingsFileModel>(text);
        }
        catch (Exception ex) when (ex is YamlDotNet.Core.YamlException or FormatException)
        {
            throw new KclException($"kcl.WithSettings({path}): {ex.Message}", ex);
        }

        var file = new KclSettingsFile();
        var config = model.Config ?? new KclCliConfigModel();
        file.Config = new KclCliConfig
        {
            Output = config.Output ?? "",
            StrictRangeCheck = config.StrictRangeCheck,
            DisableNone = config.DisableNone,
            SortKeys = config.SortKeys,
            ShowHidden = config.ShowHidden,
            IncludeSchemaTypePath = config.IncludeSchemaTypePath,
            Debug = config.Debug,
        };
        if (config.Verbose is long verbose)
        {
            file.Config.Verbose = (int)verbose;
        }
        AddAll(file.Config.InputFiles, config.InputFile);
        AddAll(file.Config.InputFiles, config.InputFiles);
        AddAll(file.Config.Overrides, config.Overrides);
        AddAll(file.Config.Selectors, config.PathSelector);
        if (config.PackageMaps != null)
        {
            foreach (var (name, value) in config.PackageMaps)
            {
                if (value is string p)
                {
                    file.Config.PackageMaps.Add(new KeyValuePair<string, string>(name, p));
                }
            }
        }
        if (model.Options != null)
        {
            foreach (var option in model.Options)
            {
                if (option?.Key is not string key)
                {
                    continue;
                }
                file.Options.Add(new KeyValueEntry(key, option.Value));
            }
        }
        return file;
    }

    private static void AddAll(List<string> target, IEnumerable<string>? values)
    {
        if (values == null)
        {
            return;
        }
        foreach (var value in values)
        {
            if (!string.IsNullOrEmpty(value))
            {
                target.Add(value);
            }
        }
    }

    /// <summary>
    /// Convert to an <see cref="ExecProgramArgs"/> snapshot, mirroring kcl-go's
    /// <c>SettingsFile.To_ExecProgramArgs</c>. Relative input files are
    /// resolved against <paramref name="workDir"/> (which should already carry
    /// the caller's <c>WithWorkDir</c> value, or "." when unset), with
    /// <c>${PWD}</c> expansion.
    /// </summary>
    public ExecProgramArgs ToExecProgramArgs(string workDir)
    {
        var args = new ExecProgramArgs
        {
            StrictRangeCheck = Config.StrictRangeCheck,
            DisableNone = Config.DisableNone,
            Verbose = Config.Verbose,
            SortKeys = Config.SortKeys,
            ShowHidden = Config.ShowHidden,
            IncludeSchemaTypePath = Config.IncludeSchemaTypePath,
        };
        if (Config.Debug)
        {
            args.Debug = 1;
        }

        foreach (var s in Config.InputFiles)
        {
            args.KFilenameList.Add(ResolveInputFile(s, workDir));
        }
        if (!string.IsNullOrEmpty(Config.Output))
        {
            args.Format = Config.Output;
        }
        args.Overrides.Add(Config.Overrides);
        args.PathSelector.Add(Config.Selectors);
        foreach (var (name, path) in Config.PackageMaps)
        {
            args.ExternalPkgs.Add(new ExternalPkg { PkgName = name, PkgPath = path });
        }

        foreach (var option in Options)
        {
            args.Args.Add(new Argument
            {
                Name = option.Key,
                Value = StringifyValue(option.Value),
            });
        }
        return args;
    }

    private static string ResolveInputFile(string s, string workDir)
    {
        s = s.Replace("${PWD}", workDir);
        if (s.StartsWith(".", StringComparison.Ordinal)
            || (!s.StartsWith("${", StringComparison.Ordinal) && !Path.IsPathRooted(s)))
        {
            return Path.Combine(workDir, s);
        }
        return s;
    }

    private static string StringifyValue(object? value)
    {
        switch (value)
        {
            case null:
                return "";
            case string s:
                return s;
            case bool b:
                return b ? "true" : "false";
            default:
                // Complex (map/list) values are serialised to JSON, matching
                // kcl-go's json.Marshal of kcl_options values.
                return JsonSerializer.Serialize(value);
        }
    }
}

/// <summary>Mirror of kcl-go's <c>settings.ConfigStruct</c> (the <c>kcl_cli_configs</c> block).</summary>
internal sealed class KclCliConfig
{
    public List<string> InputFiles = new();
    public string Output = "";
    public List<string> Overrides = new();
    public List<string> Selectors = new();
    public bool StrictRangeCheck;
    public bool DisableNone;
    public int Verbose;
    public bool Debug;
    public List<KeyValuePair<string, string>> PackageMaps = new();
    public bool SortKeys;
    public bool ShowHidden;
    public bool IncludeSchemaTypePath;
}

internal sealed class KeyValueEntry
{
    public string Key;
    public object? Value;
    public KeyValueEntry(string key, object? value)
    {
        Key = key;
        Value = value;
    }
}

// ---------------------------------------------------------------------------
// YamlDotNet typed model for the settings file
// ---------------------------------------------------------------------------

internal sealed class SettingsFileModel
{
    [YamlMember(Alias = "kcl_cli_configs")]
    public KclCliConfigModel? Config { get; set; }

    [YamlMember(Alias = "kcl_options")]
    public List<KclOptionEntryModel?>? Options { get; set; }
}

internal sealed class KclCliConfigModel
{
    [YamlMember(Alias = "file")]
    public List<string>? InputFile { get; set; }

    [YamlMember(Alias = "files")]
    public List<string>? InputFiles { get; set; }

    [YamlMember(Alias = "output")]
    public string? Output { get; set; }

    [YamlMember(Alias = "overrides")]
    public List<string>? Overrides { get; set; }

    [YamlMember(Alias = "path_selector")]
    public List<string>? PathSelector { get; set; }

    [YamlMember(Alias = "strict_range_check")]
    public bool StrictRangeCheck { get; set; }

    [YamlMember(Alias = "disable_none")]
    public bool DisableNone { get; set; }

    [YamlMember(Alias = "sort_keys")]
    public bool SortKeys { get; set; }

    [YamlMember(Alias = "show_hidden")]
    public bool ShowHidden { get; set; }

    [YamlMember(Alias = "include_schema_type_path")]
    public bool IncludeSchemaTypePath { get; set; }

    // Typed as object so a non-numeric value is ignored (lenient) instead of
    // failing the whole settings file.
    [YamlMember(Alias = "verbose")]
    public object? Verbose { get; set; }

    [YamlMember(Alias = "debug")]
    public bool Debug { get; set; }

    [YamlMember(Alias = "package_maps")]
    public Dictionary<string, object?>? PackageMaps { get; set; }
}

internal sealed class KclOptionEntryModel
{
    [YamlMember(Alias = "key")]
    public string? Key { get; set; }

    [YamlMember(Alias = "value")]
    public object? Value { get; set; }
}
