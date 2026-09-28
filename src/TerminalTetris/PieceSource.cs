namespace TerminalTetris;

public interface IPieceSource
{
    TetrominoType Next();
}

public sealed class RandomPieceSource : IPieceSource
{
    private readonly Random random;

    public RandomPieceSource()
        : this(new Random())
    {
    }

    public RandomPieceSource(Random random)
    {
        this.random = random ?? throw new ArgumentNullException(nameof(random));
    }

    public TetrominoType Next() =>
        (TetrominoType)random.Next(Enum.GetValues<TetrominoType>().Length);
}
