namespace TerminalTetris.Tests;

public sealed class BoardTests
{
    [Fact]
    public void Dimensions_AreTenByTwenty()
    {
        Assert.Equal(10, Board.Width);
        Assert.Equal(20, Board.Height);
    }

    [Theory]
    [InlineData(0, 0, true)]
    [InlineData(9, 19, true)]
    [InlineData(-1, 0, false)]
    [InlineData(10, 0, false)]
    [InlineData(0, -1, false)]
    [InlineData(0, 20, false)]
    public void IsInside_EnforcesBoardBoundaries(int x, int y, bool expected)
    {
        var board = new Board();

        Assert.Equal(expected, board.IsInside(new Cell(x, y)));
    }

    [Fact]
    public void CanPlace_RejectsOccupiedCellsAndOutOfBoundsCells()
    {
        var board = new Board();
        board.Lock([new Cell(4, 5)]);

        Assert.False(board.CanPlace([new Cell(4, 5)]));
        Assert.False(board.CanPlace([new Cell(-1, 5)]));
        Assert.False(board.CanPlace([new Cell(10, 5)]));
        Assert.False(board.CanPlace([new Cell(4, 20)]));
        Assert.True(board.CanPlace([new Cell(3, 5), new Cell(5, 5)]));
    }

    [Fact]
    public void Lock_RejectsInvalidCellsWithoutChangingBoard()
    {
        var board = new Board();
        board.Lock([new Cell(4, 5)]);

        Assert.Throws<InvalidOperationException>(
            () => board.Lock([new Cell(5, 5), new Cell(4, 5)]));
        Assert.Equal([new Cell(4, 5)], board.GetOccupiedCells());
    }

    [Fact]
    public void ClearFullLines_RemovesRowsSimultaneouslyAndShiftsRowsDown()
    {
        var board = new Board();
        var cells = Enumerable.Range(0, Board.Width)
            .SelectMany(x => new[] { new Cell(x, 18), new Cell(x, 19) })
            .Append(new Cell(3, 17));
        board.Lock(cells);

        var cleared = board.ClearFullLines();

        Assert.Equal(2, cleared);
        Assert.Equal([new Cell(3, 19)], board.GetOccupiedCells());
    }
}
