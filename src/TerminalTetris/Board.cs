namespace TerminalTetris;

public sealed class Board
{
    private readonly bool[,] cells = new bool[Height, Width];

    public const int Width = 10;
    public const int Height = 20;

    public bool IsInside(Cell cell) =>
        cell.X >= 0 && cell.X < Width && cell.Y >= 0 && cell.Y < Height;

    public bool IsOccupied(Cell cell) =>
        IsInside(cell) && cells[cell.Y, cell.X];

    public bool CanPlace(IEnumerable<Cell> candidateCells) =>
        candidateCells.All(cell => IsInside(cell) && !IsOccupied(cell));

    public void Lock(IEnumerable<Cell> occupiedCells)
    {
        var materializedCells = occupiedCells.ToArray();

        if (!CanPlace(materializedCells))
        {
            throw new InvalidOperationException("Cannot lock cells outside the board or over occupied cells.");
        }

        foreach (var cell in materializedCells)
        {
            cells[cell.Y, cell.X] = true;
        }
    }

    public int ClearFullLines()
    {
        var writeRow = Height - 1;
        var cleared = 0;

        for (var readRow = Height - 1; readRow >= 0; readRow--)
        {
            if (IsRowFull(readRow))
            {
                cleared++;
                continue;
            }

            CopyRow(readRow, writeRow);
            writeRow--;
        }

        for (var row = writeRow; row >= 0; row--)
        {
            ClearRow(row);
        }

        return cleared;
    }

    public IReadOnlyList<Cell> GetOccupiedCells()
    {
        var occupied = new List<Cell>();

        for (var y = 0; y < Height; y++)
        {
            for (var x = 0; x < Width; x++)
            {
                if (cells[y, x])
                {
                    occupied.Add(new Cell(x, y));
                }
            }
        }

        return occupied;
    }

    private bool IsRowFull(int row)
    {
        for (var x = 0; x < Width; x++)
        {
            if (!cells[row, x])
            {
                return false;
            }
        }

        return true;
    }

    private void CopyRow(int source, int destination)
    {
        if (source == destination)
        {
            return;
        }

        for (var x = 0; x < Width; x++)
        {
            cells[destination, x] = cells[source, x];
        }
    }

    private void ClearRow(int row)
    {
        for (var x = 0; x < Width; x++)
        {
            cells[row, x] = false;
        }
    }
}
