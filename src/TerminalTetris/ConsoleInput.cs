namespace TerminalTetris;

public interface IInput
{
    IReadOnlyList<GameCommand> ReadPending();
}

public sealed class ConsoleInput : IInput
{
    public IReadOnlyList<GameCommand> ReadPending()
    {
        var commands = new List<GameCommand>();

        while (Console.KeyAvailable)
        {
            var key = Console.ReadKey(intercept: true).Key;

            switch (key)
            {
                case ConsoleKey.LeftArrow:
                    commands.Add(GameCommand.MoveLeft);
                    break;
                case ConsoleKey.RightArrow:
                    commands.Add(GameCommand.MoveRight);
                    break;
                case ConsoleKey.DownArrow:
                    commands.Add(GameCommand.SoftDrop);
                    break;
                case ConsoleKey.UpArrow:
                    commands.Add(GameCommand.RotateClockwise);
                    break;
                case ConsoleKey.Q:
                case ConsoleKey.Escape:
                    commands.Add(GameCommand.Quit);
                    break;
            }
        }

        return commands;
    }
}
