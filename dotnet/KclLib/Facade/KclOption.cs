namespace KclLib.Facade;

using KclLib.API;

/// <summary>
/// Base class for functional options accepted by <see cref="Kcl.Run(string, KclOption[])"/>
/// and friends. Mirrors kcl-go's <c>Option</c>: each option contributes a
/// slice of state that is merged into a shared option bag before the
/// <see cref="ExecProgramArgs"/> proto is materialised. Build options with
/// the static factories on <see cref="KclOptions"/>.
/// </summary>
public abstract class KclOption
{
    internal KclOption()
    {
    }

    /// <summary>Merge this option into the accumulated option bag.</summary>
    internal abstract void Apply(KclOptionBag bag);
}

/// <summary>
/// Mutable bag of merged option state, mirroring the union of fields the
/// kcl-go <c>Option</c> struct can populate. Internal to the facade; users
/// only ever see <see cref="KclOption"/> instances.
/// </summary>
internal sealed class KclOptionBag
{
    public string? WorkDir;
    public List<string> KFilenameList = new();
    public List<string> KCodeList = new();
    public List<Argument> Args = new();
    public List<string> Overrides = new();
    public List<string> Selectors = new();
    public List<ExternalPkg> ExternalPkgs = new();
    public bool? DisableNone;
    public bool? SortKeys;
    public bool? ShowHidden;
    public bool? IncludeSchemaTypePath;
    public bool? StrictRangeCheck;
    public bool? CompileOnly;
    public bool? PrintOverrideAst;
    public bool? DisableYamlResult;
    public bool? FastEval;
    public int? Verbose;
    public int? Debug;
    public string? ErrorFormat;
    public string? Format;
    public string? SourcemapOutput;
    public TextWriter? Logger;

    /// <summary>
    /// Merge an <see cref="ExecProgramArgs"/> snapshot into the bag using the
    /// same rules as kcl-go's <c>Option.Merge</c>: repeated fields append,
    /// non-empty scalars overwrite (last wins), and plain bool fields only
    /// propagate when <c>true</c> (the zero value means "not set" in the
    /// source data, e.g. a settings file).
    /// </summary>
    public void MergeExecArgs(ExecProgramArgs a)
    {
        if (!string.IsNullOrEmpty(a.WorkDir)) WorkDir = a.WorkDir;
        KFilenameList.AddRange(a.KFilenameList);
        KCodeList.AddRange(a.KCodeList);
        Args.AddRange(a.Args);
        Overrides.AddRange(a.Overrides);
        Selectors.AddRange(a.PathSelector);
        ExternalPkgs.AddRange(a.ExternalPkgs);
        if (a.DisableNone) DisableNone = true;
        if (a.SortKeys) SortKeys = true;
        if (a.ShowHidden) ShowHidden = true;
        if (a.IncludeSchemaTypePath) IncludeSchemaTypePath = true;
        if (a.StrictRangeCheck) StrictRangeCheck = true;
        if (a.CompileOnly) CompileOnly = true;
        if (a.PrintOverrideAst) PrintOverrideAst = true;
        if (a.DisableYamlResult) DisableYamlResult = true;
        if (a.FastEval) FastEval = true;
        if (a.Verbose > 0) Verbose = a.Verbose;
        if (a.Debug != 0) Debug = a.Debug;
        if (!string.IsNullOrEmpty(a.ErrorFormat)) ErrorFormat = a.ErrorFormat;
        if (!string.IsNullOrEmpty(a.Format)) Format = a.Format;
        if (!string.IsNullOrEmpty(a.SourcemapOutput)) SourcemapOutput = a.SourcemapOutput;
    }

    /// <summary>Materialise the bag into a proto <see cref="ExecProgramArgs"/>.</summary>
    public ExecProgramArgs ToExecProgramArgs()
    {
        var args = new ExecProgramArgs();
        if (WorkDir != null) args.WorkDir = WorkDir;
        args.KFilenameList.AddRange(KFilenameList);
        args.KCodeList.AddRange(KCodeList);
        args.Args.AddRange(Args);
        args.Overrides.AddRange(Overrides);
        args.PathSelector.AddRange(Selectors);
        args.ExternalPkgs.AddRange(ExternalPkgs);
        if (DisableNone.HasValue) args.DisableNone = DisableNone.Value;
        if (SortKeys.HasValue) args.SortKeys = SortKeys.Value;
        if (ShowHidden.HasValue) args.ShowHidden = ShowHidden.Value;
        if (IncludeSchemaTypePath.HasValue) args.IncludeSchemaTypePath = IncludeSchemaTypePath.Value;
        if (StrictRangeCheck.HasValue) args.StrictRangeCheck = StrictRangeCheck.Value;
        if (CompileOnly.HasValue) args.CompileOnly = CompileOnly.Value;
        if (PrintOverrideAst.HasValue) args.PrintOverrideAst = PrintOverrideAst.Value;
        if (DisableYamlResult.HasValue) args.DisableYamlResult = DisableYamlResult.Value;
        if (FastEval.HasValue) args.FastEval = FastEval.Value;
        if (Verbose.HasValue) args.Verbose = Verbose.Value;
        if (Debug.HasValue) args.Debug = Debug.Value;
        if (ErrorFormat != null) args.ErrorFormat = ErrorFormat;
        if (Format != null) args.Format = Format;
        if (SourcemapOutput != null) args.SourcemapOutput = SourcemapOutput;
        return args;
    }
}
