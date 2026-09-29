namespace TerminalTetris;

public enum TetrominoType
{
    I,
    J,
    L,
    O,
    S,
    T,
    Z
}

public readonly record struct Tetromino(
    TetrominoType Type,
    int Rotation,
    int X,
    int Y)
{
    public IReadOnlyList<Cell> Cells
    {
        get
        {
            var localCells = TetrominoDefinitions.GetCells(Type, Rotation);
            var translatedCells = new Cell[localCells.Count];

            for (var index = 0; index < localCells.Count; index++)
            {
                translatedCells[index] = new Cell(
                    localCells[index].X + X,
                    localCells[index].Y + Y);
            }

            return translatedCells;
        }
    }

    public Tetromino Move(int deltaX, int deltaY) =>
        this with { X = X + deltaX, Y = Y + deltaY };

    public Tetromino RotateClockwise() =>
        this with { Rotation = (Rotation + 1) % 4 };
}
