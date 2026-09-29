# Squad Decisions

## Active Decisions

### 2026-09-28T19:52:04.082+02:00: Adoptar y cerrar el contrato de Terminal Tetris (consolidated)

**By:** Shuri

**What:** La primera implementación será una aplicación de consola local, de un solo proceso y sin dependencias externas. Separará el motor determinista del juego de la entrada, el reloj y el renderizado de terminal. El motor no conocerá `Console`, tiempo real ni detalles del sistema operativo.

**Why:** El repositorio ya requiere .NET SDK y la demostración necesita una aplicación fácil de ejecutar, observar y modificar con GitHub Copilot CLI. Mantener el motor puro reduce el riesgo de errores, permite pruebas rápidas y evita introducir frameworks innecesarios.

#### Objetivos

- Producir una partida de Tetris reconocible y jugable en una terminal interactiva
- Mantener el diseño suficientemente pequeño para una primera implementación
- Permitir probar las reglas sin depender de una terminal real ni del tiempo de pared
- Funcionar con la biblioteca estándar de .NET
- Restaurar el estado visible básico de la terminal al salir

#### No objetivos

- Multijugador, red, persistencia, tablas de posiciones o integración con Azure
- Inteligencia artificial, repetición de partidas o telemetría
- Compatibilidad completa con todas las variantes históricas de Tetris
- Animaciones avanzadas, audio, temas, configuración o internacionalización
- Motor gráfico, interfaz de ventanas o soporte formal para terminales no interactivas
- Sistema completo de rotación SRS, *wall kicks*, *hold*, pieza fantasma o *hard drop*

#### Componentes y responsabilidades

##### `Program`

- Compone las dependencias concretas
- Valida que exista una terminal interactiva
- Configura y restaura cursor y pantalla mediante `try/finally`
- Inicia el bucle y devuelve un código de salida

##### `Game`

- Conserva el estado autoritativo
- Aplica comandos del jugador
- Ejecuta un paso de gravedad
- Detecta colisiones, fija piezas, limpia líneas y decide el fin de partida
- Expone una instantánea de solo lectura para renderizar

##### `Board`

- Representa exclusivamente las celdas ya fijadas
- Comprueba ocupación y límites
- Fusiona una pieza bloqueada
- Elimina filas completas y desplaza las superiores

##### `Tetromino`

- Describe tipo, rotación y posición de la pieza activa
- Proporciona sus cuatro celdas ocupadas
- No modifica el tablero

##### `PieceSource`

- Entrega la siguiente pieza
- Oculta la estrategia aleatoria tras una interfaz mínima
- La implementación inicial puede usar `Random`; las pruebas usarán una secuencia fija

##### `Input`

- Lee teclas disponibles sin bloquear
- Traduce teclas a comandos del dominio
- No cambia el estado directamente

##### `TerminalRenderer`

- Convierte una instantánea en texto
- Dibuja desde la esquina superior izquierda
- Evita limpiar toda la consola en cada cuadro
- No contiene reglas del juego

##### `GameLoop`

- Usa un reloj monotónico
- Consume entrada, acumula tiempo y solicita pasos de gravedad
- Limita el refresco para no ocupar un núcleo completo
- Termina al recibir `Quit` o cuando el estado sea `GameOver`

#### Modelo de estado

El estado mínimo contiene:

- Tablero fijo de 10 columnas por 20 filas visibles
- Pieza activa: tipo, rotación y coordenada de origen
- Próxima pieza
- Puntuación
- Líneas eliminadas
- Estado de ejecución: `Playing` o `GameOver`
- Instante acumulado hasta el siguiente paso de gravedad

Las coordenadas usan origen `(0, 0)` en la esquina superior izquierda, `x` crece hacia la derecha y `y` hacia abajo. El tablero no almacena la pieza activa; el render combina ambos conceptos. Esta separación evita tener que borrar y reinsertar la pieza durante cada movimiento.

#### Bucle principal

1. Calcular el tiempo transcurrido con un reloj monotónico.
2. Leer todos los comandos pendientes.
3. Aplicar cada comando en orden.
4. Acumular tiempo transcurrido.
5. Ejecutar cero o más pasos de gravedad de duración fija para recuperar retrasos.
6. Renderizar solo si el estado visible cambió o venció el intervalo de refresco.
7. Dormir brevemente para evitar espera activa.
8. Repetir hasta salir o perder.

La actualización será de paso fijo y la gravedad inicial será de una celda cada 500 ms. El refresco puede limitarse aproximadamente a 30 cuadros por segundo; la lógica no depende de esa frecuencia.

#### Entrada y renderizado

Controles iniciales:

- Flechas izquierda y derecha: mover
- Flecha abajo: descenso suave de una celda
- Flecha arriba: rotar 90 grados en sentido horario
- `Q` o `Escape`: salir

La entrada usa `Console.KeyAvailable` y `Console.ReadKey(intercept: true)` para no bloquear el bucle. El render usa caracteres ASCII portables: borde, espacio vacío y bloque de dos caracteres de ancho para mantener proporción visual. La pantalla muestra tablero, próxima pieza, puntuación, líneas y controles.

El render construye el cuadro completo en memoria y lo escribe con `Console.SetCursorPosition(0, 0)`. Debe rellenar cualquier resto del cuadro anterior si la salida nueva es más corta. Al iniciar oculta el cursor; al finalizar lo restaura. Si la salida está redirigida o la consola no admite posicionamiento, la aplicación debe finalizar con un mensaje claro en lugar de degradarse a una salida ilegible.

#### Reglas mínimas

- Tablero de 10 por 20
- Siete tetrominós: `I`, `J`, `L`, `O`, `S`, `T` y `Z`
- Cada pieza aparece centrada cerca del borde superior
- Movimiento válido solo cuando las cuatro celdas quedan dentro del tablero y libres
- Rotación horaria alrededor de una definición local preestablecida
- Rotación inválida se rechaza sin *wall kick*
- Descenso automático por gravedad
- Si una pieza no puede bajar, se fija inmediatamente
- Tras fijarla, se eliminan todas las filas completas en una operación
- Se genera la siguiente pieza y se prepara otra
- La partida termina si la nueva pieza colisiona al aparecer
- Puntuación mínima por líneas eliminadas simultáneamente: 100, 300, 500 y 800

No habrá niveles ni aceleración en la primera versión. Tampoco se puntúa el descenso suave.

#### Límites e interfaces

- `Game.Apply(GameCommand)` es la única entrada de acciones del jugador
- `Game.AdvanceGravity()` es la única entrada temporal al motor
- `Game.Snapshot` es la única vista consumida por el render
- `IPieceSource.Next()` es el único origen de piezas
- `IInput.ReadPending()` devuelve comandos y desconoce el juego
- `IRenderer.Render(GameSnapshot)` desconoce mutaciones y tiempo
- El bucle coordina interfaces, pero no implementa reglas

No se propone un contenedor de inyección de dependencias. La composición manual en `Program` es suficiente.

#### Estructura de archivos propuesta

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

La primera implementación puede conservar una clase por responsabilidad. No se justifican capas adicionales, carpetas internas, eventos, mediadores, ECS ni arquitectura de complementos.

#### Riesgos principales y mitigaciones

- **Parpadeo o salida deformada:** usar un búfer de texto, posicionamiento de cursor y ancho fijo de dos caracteres por celda
- **Diferencias entre terminales:** limitarse a `System.Console`, ASCII y detección explícita de consola interactiva
- **Entrada perdida o bucle bloqueado:** vaciar todas las teclas pendientes sin llamadas bloqueantes
- **Lógica dependiente de velocidad de máquina:** gravedad con acumulador y paso fijo
- **Errores de rotación:** centralizar las cuatro rotaciones de cada pieza en datos inmutables
- **Aleatoriedad difícil de probar:** aislar el origen de piezas y usar secuencias deterministas en pruebas
- **Crecimiento accidental del alcance:** excluir de la primera versión SRS, *hold*, *hard drop*, niveles y persistencia
- **Terminal sin tamaño suficiente:** comprobar dimensiones mínimas antes de iniciar y mostrar el tamaño requerido

#### Decisiones explícitas

- Plataforma: aplicación de consola .NET
- Dependencias de ejecución: solo biblioteca estándar
- Arquitectura: motor determinista separado de adaptadores de consola
- Modelo temporal: gravedad de paso fijo con reloj monotónico
- Modelo de tablero: solo celdas fijadas; pieza activa separada
- Renderizado: cuadro completo en memoria y reposicionamiento del cursor
- Rotación: tablas predefinidas, sin SRS ni *wall kicks*
- Aleatoriedad: interfaz sustituible; `Random` como implementación inicial
- Pruebas: centradas en `Game` y `Board`, sin pruebas de terminal en la primera versión
- Integración externa: ninguna; el juego es un artefacto local de la demostración

#### Supuestos

- La demostración se ejecutará en una terminal interactiva moderna desde Windows
- El .NET SDK disponible admite una aplicación de consola mantenida actualmente
- El objetivo es demostrar el flujo de trabajo de Copilot CLI y Squad, no fidelidad competitiva
- Vision convertirá esta decisión en documentación orientada a la demostración

#### Contrato de implementación cerrado

La primera versión será una solución .NET con `TerminalTetris.slnx`, una aplicación de consola dirigida a `net10.0` y un proyecto de pruebas también dirigido a `net10.0`. La plataforma primaria y única exigida en esta fase es Windows PowerShell en una terminal interactiva. La selección de piezas de producción usará `Random` detrás de `IPieceSource`; las pruebas sustituirán esa interfaz por secuencias deterministas.

Una bolsa de siete piezas requiere mantener y barajar estado adicional, además de probar el agotamiento y la regeneración de la bolsa. Esa complejidad no mejora los criterios del alcance mínimo jugable. El límite `IPieceSource` conserva la posibilidad de incorporarla después sin cambiar el motor.

##### Alcance obligatorio

- Tablero visible de 10 por 20 y siete tipos de tetrominós
- Pieza activa separada de las celdas fijadas
- Movimiento horizontal, descenso suave, rotación horaria y gravedad cada 500 ms
- Colisión contra límites y celdas ocupadas
- Bloqueo inmediato cuando la pieza no puede descender
- Eliminación simultánea de filas completas
- Puntuación de 100, 300, 500 y 800 por una, dos, tres y cuatro filas
- Próxima pieza visible y fin de partida por colisión al aparecer
- Controles: flechas izquierda, derecha, abajo y arriba; `Q` o `Escape` para salir
- Renderizado ASCII en terminal, entrada no bloqueante y restauración del cursor al finalizar
- Mensaje claro y salida controlada si la terminal no es interactiva, no permite posicionar el cursor o es demasiado pequeña

##### Fuera de alcance

- Bolsa de siete piezas, SRS, *wall kicks*, *hold*, pieza fantasma y *hard drop*
- Niveles, aceleración, puntuación por descenso, pausa y reinicio
- GUI, audio, configuración, persistencia, red, telemetría y servicios externos
- Compatibilidad formal con Linux, macOS o salida redirigida
- Pruebas automatizadas de la terminal o del tiempo real

##### Criterios de aceptación para Arcade

- Existe `TerminalTetris.slnx` con los proyectos `src\TerminalTetris\TerminalTetris.csproj` y `tests\TerminalTetris.Tests\TerminalTetris.Tests.csproj`, ambos con `TargetFramework` igual a `net10.0`
- El proyecto de ejecución no tiene dependencias externas y mantiene el motor separado de `Console`, reloj y aleatoriedad concreta
- `IPieceSource.Next()` es el único origen de piezas; la implementación de producción usa una única instancia de `Random`
- El tablero conserva solo piezas fijadas y el render combina tablero y pieza activa
- Los movimientos o rotaciones inválidos no alteran el estado
- La gravedad, el bloqueo, la limpieza de filas, la puntuación, la promoción de la siguiente pieza y `GameOver` cumplen el alcance obligatorio
- El bucle consume todas las teclas pendientes sin bloquear y evita espera activa
- La aplicación restaura como mínimo la visibilidad del cursor mediante `try/finally`
- Desde la raíz del repositorio, compilación, pruebas y ejecución funcionan con los comandos especificados abajo

##### Criterios de aceptación para Hulk

- Verifica mediante pruebas deterministas las dimensiones y límites del tablero
- Verifica colisiones con bordes y celdas fijadas para movimiento, descenso y rotación
- Verifica rotación válida y rechazo sin *wall kick* de una rotación inválida
- Verifica bloqueo, aparición de la siguiente pieza y `GameOver` por colisión de aparición
- Verifica eliminación de una, dos, tres y cuatro filas, incluyendo desplazamiento correcto de filas
- Verifica puntuaciones exactas de 100, 300, 500 y 800 y ausencia de puntos por descenso suave
- Verifica que una secuencia inyectada de piezas hace las pruebas repetibles
- Ejecuta la suite completa y revisa manualmente una partida en Windows PowerShell
- Rechaza cualquier ampliación de alcance o acoplamiento del motor con `Console`, tiempo real o `Random`

##### Comandos de aceptación desde Windows PowerShell

```powershell
dotnet build .\TerminalTetris.slnx
dotnet test .\TerminalTetris.slnx --no-build
dotnet run --project .\src\TerminalTetris\TerminalTetris.csproj
```

Los dos primeros comandos deben finalizar con código `0`. El tercero debe abrir una partida jugable en una terminal interactiva y permitir salir con `Q` o `Escape`.

##### Puerta de fase

No hay bloqueos técnicos ni decisiones abiertas para el alcance mínimo. Se aprobó el paso a implementación por Arcade. Hulk aprobó la validación con 26 de 26 pruebas, y Shuri emitió el veredicto final **APROBADO** sin observaciones ni correcciones.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
