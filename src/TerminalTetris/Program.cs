using System.Diagnostics;
using System.Runtime.Versioning;

namespace TerminalTetris;

[SupportedOSPlatform("windows")]
internal static class Program
{
    public static int Main()
    {
        if (!Terminal.TryValidate(out var error))
        {
            Console.Error.WriteLine(error);
            return 1;
        }

        var cursorWasVisible = Console.CursorVisible;

        try
        {
            Console.CursorVisible = false;
            Console.Clear();

            var game = new Game(new RandomPieceSource());
            var loop = new GameLoop(
                game,
                new ConsoleInput(),
                new ConsoleRenderer(),
                new StopwatchClock());

            loop.Run();
            return 0;
        }
        catch (IOException exception)
        {
            Console.Error.WriteLine($"Terminal error: {exception.Message}");
            return 1;
        }
        catch (Exception exception) when (
            exception is InvalidOperationException or ArgumentOutOfRangeException)
        {
            Console.Error.WriteLine($"Terminal error: {exception.Message}");
            return 1;
        }
        finally
        {
            try
            {
                Console.CursorVisible = cursorWasVisible;
            }
            catch (Exception exception) when (
                exception is IOException or InvalidOperationException or ArgumentOutOfRangeException)
            {
                Debug.WriteLine(exception);
            }
        }
    }
}
