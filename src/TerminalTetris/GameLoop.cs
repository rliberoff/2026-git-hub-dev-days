namespace TerminalTetris;

public sealed class GameLoop
{
    private static readonly TimeSpan GravityInterval = TimeSpan.FromMilliseconds(500);
    private static readonly TimeSpan RenderInterval = TimeSpan.FromMilliseconds(33);
    private readonly Game game;
    private readonly IInput input;
    private readonly IRenderer renderer;
    private readonly IClock clock;

    public GameLoop(Game game, IInput input, IRenderer renderer, IClock clock)
    {
        this.game = game ?? throw new ArgumentNullException(nameof(game));
        this.input = input ?? throw new ArgumentNullException(nameof(input));
        this.renderer = renderer ?? throw new ArgumentNullException(nameof(renderer));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    public void Run()
    {
        var previousTime = clock.Elapsed;
        var gravityAccumulator = TimeSpan.Zero;
        var renderAccumulator = RenderInterval;
        var dirty = true;
        var quit = false;

        while (!quit && game.Status == GameStatus.Playing)
        {
            var currentTime = clock.Elapsed;
            var elapsed = currentTime - previousTime;
            previousTime = currentTime;
            gravityAccumulator += elapsed;
            renderAccumulator += elapsed;

            foreach (var command in input.ReadPending())
            {
                if (command == GameCommand.Quit)
                {
                    quit = true;
                    break;
                }

                dirty |= game.Apply(command);
            }

            while (!quit &&
                   game.Status == GameStatus.Playing &&
                   gravityAccumulator >= GravityInterval)
            {
                dirty |= game.AdvanceGravity();
                gravityAccumulator -= GravityInterval;
            }

            if (dirty || renderAccumulator >= RenderInterval)
            {
                renderer.Render(game.Snapshot);
                dirty = false;
                renderAccumulator = TimeSpan.Zero;
            }

            if (!quit && game.Status == GameStatus.Playing)
            {
                Thread.Sleep(5);
            }
        }

        renderer.Render(game.Snapshot);
    }
}
