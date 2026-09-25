using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace KclTool;

/// <summary>
/// Locates the bundled <c>kcl</c> (or <c>kcl.exe</c> on Windows) executable for
/// the current runtime identifier and invokes it as a child process.
/// </summary>
/// <remarks>
/// All entry points read <see cref="BinaryPath"/> lazily and thread-safely.
/// The first call resolves the path; subsequent calls reuse it. Use
/// <see cref="ProcessStartInfo.ArgumentList"/> (no shell escaping) so argument
/// values are passed verbatim to <c>kcl</c>.
/// </remarks>
public static class KclRunner
{
    private static readonly Lazy<string> BinaryPathLazy = new(ResolveBinaryPath, isThreadSafe: true);
    private static readonly Lazy<string> NativeDirectoryLazy = new(ResolveNativeDirectory, isThreadSafe: true);

    /// <summary>
    /// Absolute path to the bundled <c>kcl</c> (or <c>kcl.exe</c> on Windows)
    /// executable that matches the current runtime identifier.
    /// </summary>
    /// <exception cref="FileNotFoundException">
    /// Thrown if the package does not include binaries for the current RID.
    /// </exception>
    public static string BinaryPath => BinaryPathLazy.Value;

    /// <summary>
    /// Absolute path to the <c>runtimes/&lt;rid&gt;/native/</c> directory that
    /// ships with this package. The <c>kcl</c> binary looks in this directory
    /// (via <c>KCL_LIB_HOME</c>) for its native <c>libkcl</c> dependency, so
    /// no first-run download is required.
    /// </summary>
    public static string NativeDirectory => NativeDirectoryLazy.Value;

    /// <summary>
    /// Invokes <c>kcl</c> with the given arguments and waits for it to exit.
    /// </summary>
    /// <param name="args">Arguments to pass to <c>kcl</c>.</param>
    /// <param name="workingDirectory">
    /// Optional working directory for the spawned process. When <c>null</c>,
    /// the current process's working directory is inherited.
    /// </param>
    /// <param name="capture">If <c>true</c>, the child's stdout is captured and
    /// returned; otherwise it is streamed to the parent's stdout.</param>
    /// <returns>
    /// When <paramref name="capture"/> is <c>true</c>, the captured stdout
    /// string (possibly empty). Otherwise an empty string.
    /// </returns>
    public static string Run(IEnumerable<string> args, string? workingDirectory = null, bool capture = false)
    {
        ArgumentNullException.ThrowIfNull(args);
        var psi = new ProcessStartInfo(BinaryPath)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        if (workingDirectory != null) psi.WorkingDirectory = workingDirectory;
        foreach (var arg in args) psi.ArgumentList.Add(arg);
        psi.Environment["KCL_LIB_HOME"] = NativeDirectory;

        using var process = Process.Start(psi)
            ?? throw new InvalidOperationException($"Failed to start '{BinaryPath}'.");

        if (!capture)
        {
            process.StandardOutput.BaseStream.CopyToAsync(Console.OpenStandardOutput());
            process.StandardError.BaseStream.CopyToAsync(Console.OpenStandardError());
            process.WaitForExit();
            return string.Empty;
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"kcl exited with code {process.ExitCode}. stderr: {stderr}");
        }
        return stdout;
    }

    /// <summary>
    /// Async variant of <see cref="Run"/>; useful when the caller is itself an
    /// async context and must not block on the child process.
    /// </summary>
    public static async Task<string> RunAsync(
        IEnumerable<string> args,
        string? workingDirectory = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);
        var psi = new ProcessStartInfo(BinaryPath)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        if (workingDirectory != null) psi.WorkingDirectory = workingDirectory;
        foreach (var arg in args) psi.ArgumentList.Add(arg);
        psi.Environment["KCL_LIB_HOME"] = NativeDirectory;

        using var process = Process.Start(psi)
            ?? throw new InvalidOperationException($"Failed to start '{BinaryPath}'.");

        var stdoutTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var stderrTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        var stdout = await stdoutTask;
        var stderr = await stderrTask;
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"kcl exited with code {process.ExitCode}. stderr: {stderr}");
        }
        return stdout;
    }

    private static string ResolveBinaryPath()
    {
        var ext = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? ".exe" : string.Empty;
        var path = Path.Combine(ResolveNativeDirectory(), "kcl" + ext);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException(
                $"The bundled kcl binary was not found at '{path}'. " +
                "Make sure the package supports the current runtime identifier.",
                path);
        }
        return path;
    }

    private static string ResolveNativeDirectory()
    {
        var assemblyLocation = typeof(KclRunner).Assembly.Location;
        var assemblyDir = string.IsNullOrEmpty(assemblyLocation)
            ? AppContext.BaseDirectory
            : Path.GetDirectoryName(assemblyLocation);
        if (string.IsNullOrEmpty(assemblyDir))
        {
            throw new InvalidOperationException("Cannot determine the KclTool package directory.");
        }

        var rid = RuntimeInformation.RuntimeIdentifier;
        var dir = Path.Combine(assemblyDir, "runtimes", rid, "native");

        if (!Directory.Exists(dir))
        {
            throw new DirectoryNotFoundException(
                $"The bundled native directory was not found at '{dir}'. " +
                $"Make sure the package supports RID '{rid}'.");
        }
        return dir;
    }
}