namespace TerminalTetris.Tests;

public sealed class TetrominoTests
{
    [Fact]
    public void Definitions_ContainSevenTetrominoTypesWithFourDistinctCellsPerRotation()
    {
        var types = Enum.GetValues<TetrominoType>();

        Assert.Equal(
            [
                TetrominoType.I,
                TetrominoType.J,
                TetrominoType.L,
                TetrominoType.O,
                TetrominoType.S,
                TetrominoType.T,
                TetrominoType.Z
            ],
            types);

        foreach (var type in types)
        {
            for (var rotation = 0; rotation < 4; rotation++)
            {
                var cells = TetrominoDefinitions.GetCells(type, rotation);
                Assert.Equal(4, cells.Count);
                Assert.Equal(4, cells.Distinct().Count());
                Assert.All(
                    cells,
                    cell =>
                    {
                        Assert.InRange(cell.X, 0, 3);
                        Assert.InRange(cell.Y, 0, 3);
                    });
            }
        }
    }
}
