namespace TerminalTetris.Tests;

public sealed class GameTests
{
    [Fact]
    public void Apply_MoveLeftMovesPieceWhenDestinationIsFree()
    {
        var game = CreateGame(TetrominoType.T, TetrominoType.O);
        var before = game.Snapshot.ActiveCells;

        var changed = game.Apply(GameCommand.MoveLeft);

        Assert.True(changed);
        Assert.Equal(
            before.Select(cell => cell with { X = cell.X - 1 }),
            game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_MoveLeftRejectsBoardBoundaryWithoutChangingPiece()
    {
        var game = CreateGame(TetrominoType.T, TetrominoType.O);

        Assert.True(game.Apply(GameCommand.MoveLeft));
        Assert.True(game.Apply(GameCommand.MoveLeft));
        Assert.True(game.Apply(GameCommand.MoveLeft));
        var atBoundary = game.Snapshot.ActiveCells;

        Assert.False(game.Apply(GameCommand.MoveLeft));
        Assert.Equal(atBoundary, game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_MoveRightRejectsBoardBoundaryWithoutChangingPiece()
    {
        var game = CreateGame(TetrominoType.T, TetrominoType.O);

        for (var move = 0; move < 4; move++)
        {
            Assert.True(game.Apply(GameCommand.MoveRight));
        }

        var atBoundary = game.Snapshot.ActiveCells;

        Assert.False(game.Apply(GameCommand.MoveRight));
        Assert.Equal(atBoundary, game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_MoveLeftRejectsLockedCellWithoutChangingPiece()
    {
        var board = new Board();
        board.Lock([new Cell(2, 1)]);
        var game = CreateGame(board, TetrominoType.T, TetrominoType.O);
        var before = game.Snapshot.ActiveCells;

        Assert.False(game.Apply(GameCommand.MoveLeft));
        Assert.Equal(before, game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_RotateClockwiseRotatesWhenDestinationIsFree()
    {
        var game = CreateGame(TetrominoType.T, TetrominoType.O);

        Assert.True(game.Apply(GameCommand.RotateClockwise));
        Assert.Equal(
            [new Cell(4, 0), new Cell(4, 1), new Cell(5, 1), new Cell(4, 2)],
            game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_RotateClockwiseRejectsWallCollisionWithoutWallKick()
    {
        var game = CreateGame(TetrominoType.I, TetrominoType.O);
        Assert.True(game.Apply(GameCommand.RotateClockwise));

        for (var move = 0; move < 5; move++)
        {
            Assert.True(game.Apply(GameCommand.MoveLeft));
        }

        var before = game.Snapshot.ActiveCells;

        Assert.False(game.Apply(GameCommand.RotateClockwise));
        Assert.Equal(before, game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_RotateClockwiseRejectsLockedCellWithoutChangingPiece()
    {
        var board = new Board();
        board.Lock([new Cell(4, 2)]);
        var game = CreateGame(board, TetrominoType.T, TetrominoType.O);
        var before = game.Snapshot.ActiveCells;

        Assert.False(game.Apply(GameCommand.RotateClockwise));
        Assert.Equal(before, game.Snapshot.ActiveCells);
    }

    [Fact]
    public void Apply_SoftDropLocksImmediatelyWhenLockedCellsBlockDescent()
    {
        var board = new Board();
        board.Lock([new Cell(4, 2), new Cell(5, 2)]);
        var game = CreateGame(
            board,
            TetrominoType.O,
            TetrominoType.J,
            TetrominoType.Z);

        Assert.True(game.Apply(GameCommand.SoftDrop));

        Assert.Equal(TetrominoType.J, game.Snapshot.ActiveType);
        Assert.Equal(6, game.Snapshot.LockedCells.Count);
        Assert.Contains(new Cell(4, 0), game.Snapshot.LockedCells);
        Assert.Contains(new Cell(5, 1), game.Snapshot.LockedCells);
    }

    [Fact]
    public void AdvanceGravity_LocksPieceAndPromotesInjectedNextPiece()
    {
        var source = new SequencePieceSource(
            TetrominoType.O,
            TetrominoType.J,
            TetrominoType.Z);
        var game = new Game(source);

        AdvanceUntilActiveType(game, TetrominoType.J);

        Assert.Equal(4, game.Snapshot.LockedCells.Count);
        Assert.Equal(TetrominoType.J, game.Snapshot.ActiveType);
        Assert.Equal(TetrominoType.Z, game.Snapshot.NextType);
        Assert.Equal(
            [TetrominoType.O, TetrominoType.J, TetrominoType.Z],
            source.RequestedPieces);
    }

    [Theory]
    [InlineData(1, 100)]
    [InlineData(2, 300)]
    [InlineData(3, 500)]
    [InlineData(4, 800)]
    public void LockingPiece_ClearsLinesAndAwardsExactScore(int lineCount, int expectedScore)
    {
        var board = CreateBoardForVerticalLineClear(lineCount);
        var game = CreateGame(
            board,
            TetrominoType.I,
            TetrominoType.O,
            TetrominoType.T);
        Assert.True(game.Apply(GameCommand.RotateClockwise));

        AdvanceUntilActiveType(game, TetrominoType.O);

        Assert.Equal(lineCount, game.Lines);
        Assert.Equal(expectedScore, game.Score);
    }

    [Fact]
    public void Apply_SoftDropDoesNotAwardPoints()
    {
        var game = CreateGame(TetrominoType.O, TetrominoType.T);

        Assert.True(game.Apply(GameCommand.SoftDrop));

        Assert.Equal(0, game.Score);
        Assert.Equal(0, game.Lines);
    }

    [Fact]
    public void LockingPiece_SetsGameOverWhenPromotedPieceCannotSpawn()
    {
        var board = new Board();
        board.Lock([new Cell(4, 0)]);
        var game = CreateGame(
            board,
            TetrominoType.I,
            TetrominoType.T,
            TetrominoType.O);

        AdvanceUntilStopped(game);

        Assert.Equal(GameStatus.GameOver, game.Status);
        Assert.Equal(TetrominoType.T, game.Snapshot.ActiveType);
        Assert.Contains(new Cell(4, 0), game.Snapshot.LockedCells);
    }

    private static Game CreateGame(params TetrominoType[] pieces) =>
        new(new SequencePieceSource(pieces));

    private static Game CreateGame(Board board, params TetrominoType[] pieces) =>
        new(board, new SequencePieceSource(pieces));

    private static Board CreateBoardForVerticalLineClear(int lineCount)
    {
        var board = new Board();
        var cells = Enumerable.Range(Board.Height - lineCount, lineCount)
            .SelectMany(
                y => Enumerable.Range(0, Board.Width)
                    .Where(x => x != 5)
                    .Select(x => new Cell(x, y)));
        board.Lock(cells);
        return board;
    }

    private static void AdvanceUntilActiveType(Game game, TetrominoType expectedType)
    {
        for (var step = 0; step < Board.Height + 1; step++)
        {
            game.AdvanceGravity();

            if (game.Snapshot.ActiveType == expectedType)
            {
                return;
            }
        }

        Assert.Fail($"The active piece was not promoted to {expectedType}.");
    }

    private static void AdvanceUntilStopped(Game game)
    {
        for (var step = 0; step < Board.Height + 1 && game.Status == GameStatus.Playing; step++)
        {
            game.AdvanceGravity();
        }

        Assert.NotEqual(GameStatus.Playing, game.Status);
    }

    private sealed class SequencePieceSource(params TetrominoType[] pieces) : IPieceSource
    {
        private readonly Queue<TetrominoType> pieces = new(pieces);

        public List<TetrominoType> RequestedPieces { get; } = [];

        public TetrominoType Next()
        {
            var piece = pieces.Dequeue();
            RequestedPieces.Add(piece);
            return piece;
        }
    }
}
