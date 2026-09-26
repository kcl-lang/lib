namespace KclLib.Facade;

using System.Text.Json;
using KclLib.API;

/// <summary>
/// High-level entry points for evaluating KCL, mirroring the capabilities of
/// kcl-go's <c>pkg/kcl</c>: <see cref="Run(string, KclOption[])"/> for
/// in-memory source and <see cref="RunFiles(IEnumerable{string}, KclOption[])"/>
/// for files. Built on top of the low-level <see cref="API"/> RPC layer.
/// Like idiomatic .NET APIs, a failed run throws a <see cref="KclException"/>
/// instead of returning an error value.
/// </summary>
public static class Kcl
{
    /// <summary>
    /// Evaluate in-memory KCL <paramref name="code"/> and return the parsed
    /// result. Throws <see cref="KclException"/> on any failure: a non-empty
    /// runtime <c>err_message</c> (the exception message is the runtime's
    /// message), a failed native call, or invalid options.
    /// </summary>
    public static KclResultList Run(string code, params KclOption[] options)
    {
        return RunInternal(new[] { code }, isCode: true, options);
    }

    /// <summary>Multi-file variant of <see cref="Run(string, KclOption[])"/>.</summary>
    public static KclResultList RunFiles(IEnumerable<string> paths, params KclOption[] options)
    {
        return RunInternal(paths, isCode: false, options);
    }

    private static KclResultList RunInternal(IEnumerable<string> paths, bool isCode, KclOption[] options)
    {
        var bag = new KclOptionBag();
        try
        {
            foreach (var option in options)
            {
                option?.Apply(bag);
            }
            // The positional inputs are merged last, matching kcl-go's
            // ParseArgs where Run's paths append after the user options.
            if (isCode)
            {
                bag.KCodeList.AddRange(paths);
            }
            else
            {
                bag.KFilenameList.AddRange(paths);
            }
            if (bag.KFilenameList.Count == 0 && bag.KCodeList.Count == 0)
            {
                throw new KclException("kcl.Run: no kcl file");
            }
        }
        catch (KclException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new KclException($"kcl.Run: {ex.Message}", ex);
        }

        var args = bag.ToExecProgramArgs();
        ExecProgramResult resp;
        try
        {
            resp = new API().ExecProgram(args);
        }
        catch (KclException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new KclException(ex.Message, ex);
        }
        return ExecResultToKclResult(resp, bag.Logger);
    }

    /// <summary>
    /// Package an <see cref="ExecProgramResult"/> into a
    /// <see cref="KclResultList"/>, porting kcl-go's
    /// <c>ExecResultToKCLResult</c>: forward <c>log_message</c> to the
    /// configured logger, raise <c>err_message</c> as a
    /// <see cref="KclException"/>, then split the YAML output on
    /// <c>---</c> document separators and pair each document with the
    /// corresponding <c>json_result</c> line (falling back to the YAML
    /// fallback reader when the runtime only emitted YAML).
    /// </summary>
    internal static KclResultList ExecResultToKclResult(ExecProgramResult resp, TextWriter? logger)
    {
        if (logger != null && !string.IsNullOrEmpty(resp.LogMessage))
        {
            logger.Write(resp.LogMessage);
        }
        if (!string.IsNullOrEmpty(resp.ErrMessage))
        {
            throw new KclException(resp.ErrMessage);
        }

        var yamlResult = resp.YamlResult ?? "";
        var jsonResult = resp.JsonResult ?? "";
        if (string.IsNullOrWhiteSpace(yamlResult) && string.IsNullOrWhiteSpace(jsonResult))
        {
            return new KclResultList(Array.Empty<KclResult>(), jsonResult, yamlResult);
        }

        var documents = SplitDocuments(yamlResult);
        var jsonLines = new List<string>();
        foreach (var line in jsonResult.Split('\n'))
        {
            if (!string.IsNullOrWhiteSpace(line))
            {
                jsonLines.Add(line.Trim());
            }
        }

        var results = new List<KclResult>();
        int count = Math.Max(documents.Count, jsonLines.Count);
        for (int i = 0; i < count; i++)
        {
            string yamlDoc = i < documents.Count ? documents[i] : "";
            string? jsonDoc = i < jsonLines.Count ? jsonLines[i] : null;
            object? value;
            if (jsonDoc != null)
            {
                value = KclResult.FromJson(JsonDocument.Parse(jsonDoc).RootElement);
            }
            else
            {
                value = YamlObjectTree.Parse(yamlDoc);
            }
            results.Add(new KclResult(value, yamlDoc, jsonDoc));
        }
        return new KclResultList(results, jsonResult, yamlResult);
    }

    /// <summary>
    /// Split a YAML stream into its documents on <c>---</c> separator lines
    /// (trailing whitespace or <c>#</c> comments allowed), porting kcl-go's
    /// <c>kcl.SplitDocuments</c>. Anything else on the separator line raises
    /// <see cref="KclException"/>. Internal: multi-document splitting is an
    /// implementation detail of <see cref="ExecResultToKclResult"/>.
    /// </summary>
    internal static List<string> SplitDocuments(string s)
    {
        var docs = new List<string>();
        if (s.Length == 0)
        {
            return docs;
        }
        int prev = 0;
        int i = 0;
        while (i < s.Length)
        {
            if (s[i] == '\n' && i + 4 <= s.Length && s.Substring(i + 1).StartsWith("---", StringComparison.Ordinal)
                && (i + 4 >= s.Length || s[i + 4] == '\n' || s[i + 4] == '\r' || s[i + 4] == ' ' || s[i + 4] == '\t'))
            {
                int lineEnd = s.IndexOf('\n', i + 4);
                string separator = lineEnd < 0 ? s.Substring(i) : s.Substring(i, lineEnd - i + 1);
                string trailing = separator.Substring(4).Trim();
                if (trailing.Length > 0 && !trailing.StartsWith("#", StringComparison.Ordinal))
                {
                    throw new KclException($"invalid document separator: {separator.Trim()}");
                }
                docs.Add(s.Substring(prev, i - prev));
                prev = i + separator.Length;
                i = prev;
            }
            else
            {
                i++;
            }
        }
        docs.Add(s.Substring(prev));
        // Drop empty documents (e.g. a leading separator).
        docs.RemoveAll(d => d.Trim().Length == 0);
        return docs;
    }
}
