namespace TerminalTetris;

public sealed class Game
{
    private readonly Board board;
    private readonly IPieceSource pieceSource;
    private Tetromino activePiece;
    private TetrominoType nextType;

    public Game(IPieceSource pieceSource)
        : this(new Board(), pieceSource)
    {
    }

    public Game(Board board, IPieceSource pieceSource)
    {
        this.board = board ?? throw new ArgumentNullException(nameof(board));
        this.pieceSource = pieceSource ?? throw new ArgumentNullException(nameof(pieceSource));

        activePiece = CreateSpawnedPiece(this.pieceSource.Next());
        nextType = this.pieceSource.Next();
        Status = board.CanPlace(activePiece.Cells) ? GameStatus.Playing : GameStatus.GameOver;
    }

    public int Score { get; private set; }

    public int Lines { get; private set; }

    public GameStatus Status { get; private set; }

    public GameSnapshot Snapshot => new(
        board.GetOccupiedCells(),
        activePiece.Cells,
        activePiece.Type,
        nextType,
        Score,
        Lines,
        Status);

    public bool Apply(GameCommand command)
    {
        if (Status != GameStatus.Playing)
        {
            return false;
        }

        return command switch
        {
            GameCommand.MoveLeft => TryMove(-1, 0),
            GameCommand.MoveRight => TryMove(1, 0),
            GameCommand.SoftDrop => DropOrLock(),
            GameCommand.RotateClockwise => TryRotate(),
            GameCommand.Quit => false,
            _ => throw new ArgumentOutOfRangeException(nameof(command))
        };
    }

    public bool AdvanceGravity() =>
        Status == GameStatus.Playing && DropOrLock();

    private bool TryMove(int deltaX, int deltaY)
    {
        var candidate = activePiece.Move(deltaX, deltaY);

        if (!board.CanPlace(candidate.Cells))
        {
            return false;
        }

        activePiece = candidate;
        return true;
    }

    private bool TryRotate()
    {
        var candidate = activePiece.RotateClockwise();

        if (!board.CanPlace(candidate.Cells))
        {
            return false;
        }

        activePiece = candidate;
        return true;
    }

    private bool DropOrLock()
    {
        if (TryMove(0, 1))
        {
            return true;
        }

        board.Lock(activePiece.Cells);
        var clearedLines = board.ClearFullLines();
        Lines += clearedLines;
        Score += ScoreFor(clearedLines);

        activePiece = CreateSpawnedPiece(nextType);
        nextType = pieceSource.Next();

        if (!board.CanPlace(activePiece.Cells))
        {
            Status = GameStatus.GameOver;
        }

        return true;
    }

    private static Tetromino CreateSpawnedPiece(TetrominoType type) =>
        new(type, Rotation: 0, X: (Board.Width - 4) / 2, Y: 0);

    private static int ScoreFor(int clearedLines) =>
        clearedLines switch
        {
            0 => 0,
            1 => 100,
            2 => 300,
            3 => 500,
            4 => 800,
            _ => throw new InvalidOperationException("A tetromino cannot clear more than four lines.")
        };
}
