using System.Diagnostics;

namespace TerminalTetris;

public interface IClock
{
    TimeSpan Elapsed { get; }
}

public sealed class StopwatchClock : IClock
{
    private readonly Stopwatch stopwatch = Stopwatch.StartNew();

    public TimeSpan Elapsed => stopwatch.Elapsed;
}
