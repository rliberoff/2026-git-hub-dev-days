using System.Text;

namespace TerminalTetris;

public interface IRenderer
{
    void Render(GameSnapshot snapshot);
}

public sealed class ConsoleRenderer : IRenderer
{
    private int previousFrameLength;

    public void Render(GameSnapshot snapshot)
    {
        var frame = BuildFrame(snapshot);

        if (frame.Length < previousFrameLength)
        {
            frame = frame.PadRight(previousFrameLength);
        }

        Console.SetCursorPosition(0, 0);
        Console.Write(frame);
        previousFrameLength = frame.Length;
    }

    private static string BuildFrame(GameSnapshot snapshot)
    {
        var locked = snapshot.LockedCells.ToHashSet();
        var active = snapshot.ActiveCells.ToHashSet();
        var lines = new List<string>
        {
            "+--------------------+   TERMINAL TETRIS"
        };

        for (var y = 0; y < Board.Height; y++)
        {
            var row = new StringBuilder("|");

            for (var x = 0; x < Board.Width; x++)
            {
                var cell = new Cell(x, y);
                row.Append(active.Contains(cell) ? "[]" : locked.Contains(cell) ? "##" : "  ");
            }

            row.Append('|');

            if (y == 1)
            {
                row.Append($"   Score: {snapshot.Score}");
            }
            else if (y == 2)
            {
                row.Append($"   Lines: {snapshot.Lines}");
            }
            else if (y == 4)
            {
                row.Append("   Next:");
            }
            else if (y is >= 5 and <= 8)
            {
                row.Append("   ");
                row.Append(BuildPreviewRow(snapshot.NextType, y - 5));
            }
            else if (y == 10 && snapshot.Status == GameStatus.GameOver)
            {
                row.Append("   GAME OVER");
            }

            lines.Add(row.ToString());
        }

        lines.Add("+--------------------+");
        lines.Add("Arrows: move / soft drop / rotate");
        lines.Add("Q or Escape: quit");

        return string.Join(Environment.NewLine, lines);
    }

    private static string BuildPreviewRow(TetrominoType type, int row)
    {
        var cells = TetrominoDefinitions.GetCells(type, 0).ToHashSet();
        var preview = new StringBuilder();

        for (var x = 0; x < 4; x++)
        {
            preview.Append(cells.Contains(new Cell(x, row)) ? "[]" : "  ");
        }

        return preview.ToString();
    }
}
