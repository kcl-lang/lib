namespace KclLib.Facade;

/// <summary>
/// The exception thrown by the <see cref="Kcl"/> facade entry points when a
/// run fails. Mirrors the error value returned by kcl-go's
/// <c>ExecResultToKCLResult</c>: it is raised both for transport-level
/// failures (the native call itself threw) and for runtime-reported failures
/// (<c>ExecProgramResult.err_message</c> is non-empty).
/// </summary>
public class KclException : Exception
{
    public KclException(string message) : base(message)
    {
    }

    public KclException(string message, Exception innerException) : base(message, innerException)
    {
    }
}
