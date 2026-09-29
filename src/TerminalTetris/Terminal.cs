using System.Runtime.Versioning;

namespace TerminalTetris;

[SupportedOSPlatform("windows")]
public static class Terminal
{
    public const int MinimumWidth = 44;
    public const int MinimumHeight = 24;

    public static bool TryValidate(out string error)
    {
        if (!OperatingSystem.IsWindows())
        {
            error = "Terminal Tetris currently supports Windows interactive terminals only.";
            return false;
        }

        if (Console.IsInputRedirected || Console.IsOutputRedirected)
        {
            error = "Terminal Tetris requires an interactive console with input and output attached.";
            return false;
        }

        try
        {
            if (Console.WindowWidth < MinimumWidth || Console.WindowHeight < MinimumHeight)
            {
                error =
                    $"Terminal is too small. Required: {MinimumWidth}x{MinimumHeight}; " +
                    $"current: {Console.WindowWidth}x{Console.WindowHeight}.";
                return false;
            }

            Console.SetCursorPosition(0, 0);
            _ = Console.CursorVisible;
        }
        catch (Exception exception) when (
            exception is IOException or InvalidOperationException or ArgumentOutOfRangeException)
        {
            error = $"This terminal does not support the required cursor operations: {exception.Message}";
            return false;
        }

        error = string.Empty;
        return true;
    }
}
