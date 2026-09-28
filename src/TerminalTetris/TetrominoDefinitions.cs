namespace TerminalTetris;

public static class TetrominoDefinitions
{
    private static readonly IReadOnlyDictionary<TetrominoType, Cell[][]> Shapes =
        new Dictionary<TetrominoType, Cell[][]>
        {
            [TetrominoType.I] =
            [
                [new(0, 1), new(1, 1), new(2, 1), new(3, 1)],
                [new(2, 0), new(2, 1), new(2, 2), new(2, 3)],
                [new(0, 2), new(1, 2), new(2, 2), new(3, 2)],
                [new(1, 0), new(1, 1), new(1, 2), new(1, 3)]
            ],
            [TetrominoType.J] =
            [
                [new(0, 0), new(0, 1), new(1, 1), new(2, 1)],
                [new(1, 0), new(2, 0), new(1, 1), new(1, 2)],
                [new(0, 1), new(1, 1), new(2, 1), new(2, 2)],
                [new(1, 0), new(1, 1), new(0, 2), new(1, 2)]
            ],
            [TetrominoType.L] =
            [
                [new(2, 0), new(0, 1), new(1, 1), new(2, 1)],
                [new(1, 0), new(1, 1), new(1, 2), new(2, 2)],
                [new(0, 1), new(1, 1), new(2, 1), new(0, 2)],
                [new(0, 0), new(1, 0), new(1, 1), new(1, 2)]
            ],
            [TetrominoType.O] =
            [
                [new(1, 0), new(2, 0), new(1, 1), new(2, 1)],
                [new(1, 0), new(2, 0), new(1, 1), new(2, 1)],
                [new(1, 0), new(2, 0), new(1, 1), new(2, 1)],
                [new(1, 0), new(2, 0), new(1, 1), new(2, 1)]
            ],
            [TetrominoType.S] =
            [
                [new(1, 0), new(2, 0), new(0, 1), new(1, 1)],
                [new(1, 0), new(1, 1), new(2, 1), new(2, 2)],
                [new(1, 1), new(2, 1), new(0, 2), new(1, 2)],
                [new(0, 0), new(0, 1), new(1, 1), new(1, 2)]
            ],
            [TetrominoType.T] =
            [
                [new(1, 0), new(0, 1), new(1, 1), new(2, 1)],
                [new(1, 0), new(1, 1), new(2, 1), new(1, 2)],
                [new(0, 1), new(1, 1), new(2, 1), new(1, 2)],
                [new(1, 0), new(0, 1), new(1, 1), new(1, 2)]
            ],
            [TetrominoType.Z] =
            [
                [new(0, 0), new(1, 0), new(1, 1), new(2, 1)],
                [new(2, 0), new(1, 1), new(2, 1), new(1, 2)],
                [new(0, 1), new(1, 1), new(1, 2), new(2, 2)],
                [new(1, 0), new(0, 1), new(1, 1), new(0, 2)]
            ]
        };

    public static IReadOnlyList<Cell> GetCells(TetrominoType type, int rotation)
    {
        if (rotation is < 0 or > 3)
        {
            throw new ArgumentOutOfRangeException(nameof(rotation));
        }

        return Array.AsReadOnly(Shapes[type][rotation]);
    }
}
