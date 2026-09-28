# Terminal Tetris minimum architecture

## Context

Shuri's Terminal Tetris is a small local game for demonstrating GitHub Copilot CLI and Squad workflows. It must remain easy to run, inspect, change, and test without adding frameworks or external runtime dependencies.

The application is a single-process .NET console program. Its deterministic game engine is isolated from terminal input, rendering, and wall-clock time.

## Goals

- Deliver a recognizable, playable Tetris game in an interactive terminal
- Keep the first implementation small and understandable
- Test game rules without a real terminal or real-time delays
- Use only the .NET standard library at runtime
- Restore basic terminal state when the application exits

## Non-goals

- Networking, multiplayer, persistence, leaderboards, telemetry, or Azure integration
- Artificial intelligence, replay support, audio, themes, or localization
- A windowed or graphical user interface
- Complete historical or competitive Tetris compatibility
- SRS rotation, wall kicks, hold, ghost pieces, hard drop, levels, or increasing speed
- Formal support for redirected output or non-interactive terminals

## Architecture and responsibilities

The architecture uses a deterministic domain core with thin console adapters and manual composition.

### Program

- Creates concrete dependencies
- Verifies that the terminal is interactive and large enough
- Configures the terminal before play
- Restores cursor and screen state in a `finally` path
- Starts the game loop and returns an exit code

### Game loop

- Reads elapsed time from a monotonic clock
- Drains pending input without blocking
- Sends player commands to the game in order
- Accumulates elapsed time and requests fixed gravity steps
- Renders changed state at a bounded refresh rate
- Sleeps briefly to avoid busy waiting
- Stops after `Quit` or `GameOver`

### Game

- Owns authoritative game state
- Applies player commands and gravity steps
- Validates movement and rotation
- Locks pieces, clears lines, updates score, and detects game over
- Exposes an immutable snapshot for rendering

### Board

- Stores only locked cells
- Checks bounds and occupied cells
- Merges a locked piece
- Removes all complete rows in one operation and shifts remaining rows

### Tetromino

- Describes the active piece type, rotation, and origin
- Provides its four occupied cells from immutable shape definitions
- Does not mutate the board

### Piece source

- Supplies the next tetromino through a replaceable boundary
- Hides the production selection strategy
- Allows deterministic sequences in tests

### Input adapter

- Reads all currently available keys without blocking
- Maps terminal keys to domain commands
- Never changes game state directly

### Terminal renderer

- Converts a read-only game snapshot into text
- Combines locked board cells with the active piece for display
- Writes frames from the terminal's upper-left corner
- Contains no game rules or timing logic

## State and loop flow

### Authoritative game state

- A board with 10 columns and 20 visible rows
- The active piece type, rotation, and origin
- The next piece
- Score and cleared-line count
- A status of `Playing` or `GameOver`

Coordinates start at `(0, 0)` in the upper-left corner. `x` increases to the right and `y` increases downward. The board excludes the active piece so movement does not require removing and reinserting board cells.

### Runtime loop state

- The last monotonic clock reading
- Accumulated time until the next gravity step
- The last rendered frame or equivalent dirty-state marker
- Whether the player requested exit

### Loop sequence

1. Measure elapsed time with a monotonic clock.
2. Read every pending command.
3. Apply commands in arrival order.
4. Add elapsed time to the gravity accumulator.
5. Run zero or more fixed gravity steps to recover from delays.
6. Render when visible state changed or the refresh interval elapsed.
7. Sleep briefly.
8. Repeat until exit or game over.

Gravity initially advances one cell every 500 milliseconds. Rendering may be capped at approximately 30 frames per second, but game rules must not depend on rendering frequency.

## Input and rendering

The initial controls are:

- Left and right arrows: move horizontally
- Down arrow: move down one cell
- Up arrow: rotate 90 degrees clockwise
- `Q` or `Escape`: quit

The console input adapter should use non-blocking key availability checks and intercepted key reads. The renderer should build each complete frame in memory, use portable ASCII characters, and represent each board cell with a fixed width of two characters.

The frame includes the board, next piece, score, cleared lines, and controls. The renderer writes from position `(0, 0)` and clears any remainder from a longer previous frame. The application hides the cursor during play and restores it on exit.

If output is redirected, cursor positioning is unsupported, or the terminal is too small, startup must fail with a clear message instead of producing unreadable output.

## Minimum rules

- Use the seven tetromino types: `I`, `J`, `L`, `O`, `S`, `T`, and `Z`
- Spawn each piece centered near the top edge
- Accept movement only when all four cells remain in bounds and unoccupied
- Rotate clockwise using predefined local shape data
- Reject invalid rotation without wall kicks
- Advance pieces automatically through gravity
- Lock a piece immediately when it cannot move down
- Clear all complete rows after locking
- Promote the next piece and request another piece
- End the game when a new piece collides at spawn
- Award 100, 300, 500, or 800 points for clearing one, two, three, or four rows at once
- Do not award points for soft drop
- Do not add levels or gravity acceleration in the first version

## Conceptual interface boundaries

Names below describe responsibilities rather than prescribing exact signatures.

- **Player command boundary:** the game accepts domain commands such as move, rotate, soft drop, and quit
- **Gravity boundary:** the loop requests one deterministic gravity step at a time
- **Snapshot boundary:** the renderer consumes immutable visible state and cannot mutate the game
- **Piece source boundary:** the game requests one piece type without knowing the selection algorithm
- **Input boundary:** the loop receives pending domain commands without exposing the game to console APIs
- **Rendering boundary:** the loop submits snapshots without exposing game mutation or timing to the renderer
- **Clock boundary:** the loop reads monotonic elapsed time without embedding wall-clock access in the engine

Manual construction in `Program` is sufficient. A dependency injection container, event bus, mediator, entity-component system, and plug-in architecture are unnecessary.

## Proposed file structure

```text
src/
  TerminalTetris/
    TerminalTetris.csproj
    Program.cs
    Game.cs
    Board.cs
    Tetromino.cs
    TetrominoDefinitions.cs
    GameCommand.cs
    GameSnapshot.cs
    PieceSource.cs
    GameLoop.cs
    ConsoleInput.cs
    ConsoleRenderer.cs
tests/
  TerminalTetris.Tests/
    TerminalTetris.Tests.csproj
    GameTests.cs
    BoardTests.cs
```

The first implementation should keep one clear responsibility per class without introducing additional internal layers.

## Risks and mitigations

- **Flicker or malformed frames:** build complete frames in memory, use fixed-width cells, and reposition the cursor
- **Terminal differences:** depend only on `System.Console`, ASCII output, and explicit capability checks
- **Blocked or lost input:** drain available keys without blocking on reads
- **Machine-speed-dependent behavior:** use a monotonic clock, accumulator, and fixed gravity steps
- **Rotation defects:** centralize all piece rotations in immutable shape definitions
- **Untestable randomness:** isolate piece generation and inject deterministic sequences in tests
- **Scope growth:** retain the explicit non-goals for the first version
- **Insufficient terminal size:** validate minimum dimensions before starting
- **Terminal state left altered:** restore cursor and screen state even after failures

## Accepted decisions

- The application is a local, single-process .NET console program.
- Runtime dependencies are limited to the .NET standard library.
- The deterministic game engine is separate from console, clock, and operating-system details.
- Gravity uses fixed steps driven by a monotonic-clock accumulator.
- The board stores locked cells while the active piece remains separate.
- Rendering uses an in-memory full frame and cursor repositioning.
- Rotation uses predefined shape data without SRS or wall kicks.
- Piece generation is replaceable and deterministic during tests.
- Initial automated tests focus on `Game` and `Board`, not terminal behavior.
- The game has no external service integration.

## Assumptions

- The demonstration will run in a modern interactive terminal.
- A currently supported .NET SDK will be available.
- The primary purpose is to demonstrate the Copilot CLI and Squad workflow rather than competitive Tetris fidelity.
- The terminal supports cursor visibility and positioning when startup validation succeeds.

These assumptions are not accepted platform or version commitments. Human confirmation may change them without invalidating the core engine boundaries.

## Open questions

- Which .NET version should the project target?
- Must the demonstration support Windows only, or Windows, Linux, and macOS?
- Should production piece selection use simple independent randomness or a seven-piece bag?
