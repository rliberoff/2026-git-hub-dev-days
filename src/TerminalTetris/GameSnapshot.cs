namespace TerminalTetris;

public sealed record GameSnapshot(
    IReadOnlyList<Cell> LockedCells,
    IReadOnlyList<Cell> ActiveCells,
    TetrominoType ActiveType,
    TetrominoType NextType,
    int Score,
    int Lines,
    GameStatus Status);
