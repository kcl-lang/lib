namespace KclLib.Facade;

using KclLib.API;

/// <summary>
/// Static factories for <see cref="KclOption"/> instances, mirroring the
/// <c>With*</c> functions in kcl-go's <c>pkg/kcl</c> package. Merge
/// semantics follow kcl-go's <c>Option.Merge</c>: repeated fields
/// (filenames, codes, overrides, selectors, args, external packages) append
/// in order, while scalar fields (work dir, flags, formats) are last-wins
/// among the options that set them.
/// </summary>
public static class KclOptions
{
    /// <summary>Append in-memory KCL source <paramref name="codes"/> to the program.</summary>
    public static KclOption WithCode(params string[] codes)
    {
        return new DelegateOption(bag => bag.KCodeList.AddRange(codes));
    }

    /// <summary>Append file paths to the program's input list.</summary>
    public static KclOption WithKFilenames(params string[] paths)
    {
        return new DelegateOption(bag => bag.KFilenameList.AddRange(paths));
    }

    /// <summary>Append file paths to the program's input list.</summary>
    public static KclOption WithKFilenames(IEnumerable<string> paths)
    {
        return new DelegateOption(bag => bag.KFilenameList.AddRange(paths));
    }

    /// <summary>Set the working directory for the KCL evaluation.</summary>
    public static KclOption WithWorkDir(string workDir)
    {
        return new DelegateOption(bag => bag.WorkDir = workDir);
    }

    /// <summary>Append override specs (<c>-O pkgpath:path.to.field=value</c>).</summary>
    public static KclOption WithOverrides(params string[] overrides)
    {
        return new DelegateOption(bag => bag.Overrides.AddRange(overrides));
    }

    /// <summary>Append override specs (<c>-O pkgpath:path.to.field=value</c>).</summary>
    public static KclOption WithOverrides(IEnumerable<string> overrides)
    {
        return new DelegateOption(bag => bag.Overrides.AddRange(overrides));
    }

    /// <summary>Append path selectors (<c>-S path.to.field</c>).</summary>
    public static KclOption WithSelectors(params string[] selectors)
    {
        return new DelegateOption(bag => bag.Selectors.AddRange(selectors));
    }

    /// <summary>Append path selectors (<c>-S path.to.field</c>).</summary>
    public static KclOption WithSelectors(IEnumerable<string> selectors)
    {
        return new DelegateOption(bag => bag.Selectors.AddRange(selectors));
    }

    /// <summary>Toggle <c>disable_none</c> (<c>-n</c>): omit <c>None</c> values from the output.</summary>
    public static KclOption WithDisableNone(bool disableNone)
    {
        return new DelegateOption(bag => bag.DisableNone = disableNone);
    }

    /// <summary>Toggle <c>sort_keys</c> (<c>-k</c>): sort mapping keys in the output.</summary>
    public static KclOption WithSortKeys(bool sortKeys)
    {
        return new DelegateOption(bag => bag.SortKeys = sortKeys);
    }

    /// <summary>Toggle <c>show_hidden</c> (<c>-H</c>): include hidden attributes in the output.</summary>
    public static KclOption WithShowHidden(bool showHidden)
    {
        return new DelegateOption(bag => bag.ShowHidden = showHidden);
    }

    /// <summary>Toggle including the schema type path in the rendered result.</summary>
    public static KclOption WithIncludeSchemaTypePath(bool includeSchemaTypePath)
    {
        return new DelegateOption(bag => bag.IncludeSchemaTypePath = includeSchemaTypePath);
    }

    /// <summary>Toggle strict range checking on numeric attribute values.</summary>
    public static KclOption WithStrictRangeCheck(bool strictRangeCheck)
    {
        return new DelegateOption(bag => bag.StrictRangeCheck = strictRangeCheck);
    }

    /// <summary>Set the verbose level (positive integers only; 0 leaves the runtime default).</summary>
    public static KclOption WithVerbose(int verbose)
    {
        return new DelegateOption(bag => bag.Verbose = verbose);
    }

    /// <summary>Set the debug level (non-zero values enable debug output).</summary>
    public static KclOption WithDebug(int debug)
    {
        return new DelegateOption(bag => bag.Debug = debug);
    }

    /// <summary>
    /// Load defaults from a <c>kcl.yaml</c> settings file. Mirrors kcl-go's
    /// <c>WithSettings</c>: the file contributes filenames, overrides,
    /// selectors, flags and <c>kcl_options</c> entries to the merge, so
    /// options applied after it can extend (and, for scalars, replace) the
    /// file's values. Relative <c>file</c>/<c>files</c> entries are resolved
    /// against the working directory set so far.
    /// </summary>
    public static KclOption WithSettings(string settingsFile)
    {
        return new SettingsOption(settingsFile);
    }

    /// <summary>
    /// Set the diagnostic output format for compile/eval errors: one of
    /// <c>pretty</c> (default), <c>short</c>, <c>arcanist</c> or <c>sarif</c>.
    /// </summary>
    public static KclOption WithErrorFormat(string errorFormat)
    {
        return new DelegateOption(bag => bag.ErrorFormat = errorFormat);
    }

    /// <summary>
    /// Set the output format selector passed to the runtime via the proto
    /// <c>format</c> field: <c>yaml</c> or <c>json</c>. When empty the
    /// runtime emits both representations.
    /// </summary>
    public static KclOption WithFormat(string format)
    {
        return new DelegateOption(bag => bag.Format = format);
    }

    /// <summary>
    /// Append <c>key=value</c> arguments (<c>-D key=value</c>), exposed to
    /// the program through <c>option("key")</c>. Entries without an <c>=</c>
    /// separator are ignored, matching kcl-go's <c>WithOptions</c>.
    /// </summary>
    public static KclOption WithArgs(params string[] keyValueList)
    {
        return new DelegateOption(bag => AddKeyValueArgs(bag, keyValueList));
    }

    /// <summary>
    /// Append external package mappings in <c>name=path</c> form
    /// (<c>-E name=path</c>). Entries without an <c>=</c> separator are
    /// ignored, matching kcl-go's <c>WithExternalPkgs</c>.
    /// </summary>
    public static KclOption WithExternalPkgs(params string[] keyValueList)
    {
        return new DelegateOption(bag =>
        {
            foreach (var kv in keyValueList)
            {
                int idx = kv.IndexOf('=');
                if (idx > 0)
                {
                    bag.ExternalPkgs.Add(new ExternalPkg { PkgName = kv.Substring(0, idx), PkgPath = kv.Substring(idx + 1) });
                }
            }
        });
    }

    /// <summary>Append a single external package mapping (<c>-E name=path</c>).</summary>
    public static KclOption WithExternalPkgNameAndPath(string name, string path)
    {
        return new DelegateOption(bag =>
            bag.ExternalPkgs.Add(new ExternalPkg { PkgName = name, PkgPath = path }));
    }

    /// <summary>
    /// Attach a <see cref="TextWriter"/> that receives the runtime's
    /// <c>log_message</c> output, mirroring kcl-go's <c>WithLogger</c>.
    /// </summary>
    public static KclOption WithLogger(TextWriter logger)
    {
        return new DelegateOption(bag => bag.Logger = logger);
    }

    private static void AddKeyValueArgs(KclOptionBag bag, IEnumerable<string> keyValueList)
    {
        foreach (var kv in keyValueList)
        {
            int idx = kv.IndexOf('=');
            if (idx > 0)
            {
                bag.Args.Add(new Argument { Name = kv.Substring(0, idx), Value = kv.Substring(idx + 1) });
            }
        }
    }

    private sealed class DelegateOption : KclOption
    {
        private readonly Action<KclOptionBag> apply;
        public DelegateOption(Action<KclOptionBag> apply)
        {
            this.apply = apply;
        }
        internal override void Apply(KclOptionBag bag) => apply(bag);
    }

    private sealed class SettingsOption : KclOption
    {
        private readonly string path;
        public SettingsOption(string path)
        {
            this.path = path;
        }
        internal override void Apply(KclOptionBag bag)
        {
            // Parse at merge time so ${PWD}/relative file resolution sees the
            // working directory accumulated so far, like kcl-go's WithSettings
            // building its ExecProgramArgs snapshot inside ParseArgs.
            var file = KclSettingsFile.Load(path);
            string workDir = bag.WorkDir ?? ".";
            bag.MergeExecArgs(file.ToExecProgramArgs(workDir));
        }
    }
}
