# Guía de demostración: Squad, APIM y Foundry

## Siglas y términos

| Término | Significado |
| --- | --- |
| API | Interfaz de programación de aplicaciones (*Application Programming Interface*) |
| APIM | Azure API Management, servicio que protege, limita y observa las llamadas a los modelos |
| AZD | Azure Developer CLI, herramienta de línea de comandos para aprovisionar y desplegar la solución |
| BYOK | *Bring Your Own Key*, uso de un proveedor y una credencial propios en lugar del routing incluido en Copilot |
| CLI | *Command-Line Interface*, interfaz de línea de comandos |
| JSON | *JavaScript Object Notation*, formato usado para archivos de configuración |
| KQL | *Kusto Query Language*, lenguaje usado para consultar Application Insights |
| MCP | *Model Context Protocol*, protocolo para conectar herramientas con los agentes |
| RBAC | *Role-Based Access Control*, control de acceso basado en roles de Azure |
| SDK | *Software Development Kit*, kit de desarrollo de software |
| TPM | *Tokens Per Minute*, tokens por minuto |
| URL | *Uniform Resource Locator*, dirección de un recurso web |
| `tfstate` | Archivo y contenedor donde Terraform guarda el estado de la infraestructura |

Las palabras **Squad**, **Foundry**, **Copilot**, **Terraform** y **PowerShell** son nombres de productos o herramientas, no siglas.

Esta guía describe la demostración completa en Windows:

```text
Squad -> GitHub Copilot CLI con BYOK -> Azure API Management -> Microsoft Foundry
```

La demostración construye un Tetris mínimo jugable en terminal con agentes de Squad. Cada agente usa un modelo diferente desplegado en Foundry y todas las llamadas pasan por APIM.

## Convención de terminales y sesiones

La demostración usa cuatro terminales de PowerShell 7 con propósitos distintos. Las variables de entorno pertenecen a cada proceso: **una terminal nueva no hereda la configuración BYOK de otra, y una sesión de Copilot ya iniciada no ve los cambios que hagas después en las variables**.

| Terminal | Propósito | Configuración BYOK | Pasos |
| --- | --- | --- | --- |
| A — Squad | `squad` y `copilot` | Sí, con la clave de `demo-inference` | 6 a 13 |
| B — Gateway | Scripts de prueba contra APIM | No | 13 y 16 |
| C — Infraestructura | `az`, `azd` y `preflight.ps1` | No | 2 a 5 y 19 |
| D — Prueba negativa | Sesión con clave inválida | Sí, con una clave inválida | 15 |

### Bloque de preparación de la Terminal A

Ejecuta este bloque **cada vez que abras una Terminal A nueva**. Deja la terminal abierta durante toda la demostración; si la cierras, pierdes la clave y tendrás que volver a introducirla.

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json
$CopilotBaseUrl = $AzdValues.copilot_base_url

$env:COPILOT_PROVIDER_TYPE = 'openai'
$env:COPILOT_PROVIDER_BASE_URL = $CopilotBaseUrl
$env:COPILOT_PROVIDER_WIRE_API = 'responses'
$env:COPILOT_MODEL = 'gpt-5.4'

$SubscriptionKey = Read-Host 'APIM demo-inference primary key' -AsSecureString
$Pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SubscriptionKey)
try {
    $env:COPILOT_PROVIDER_HEADERS = 'Ocp-Apim-Subscription-Key: ' +
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Pointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Pointer)
    $SubscriptionKey = $null
}
```

### Iniciar y cerrar la sesión de Squad

Este es el único comando que inicia la sesión de trabajo de la demostración:

```powershell
copilot --agent squad --model gpt-5.4 --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

Para cerrarla, escribe `/exit` en el prompt de Copilot. Vuelves a PowerShell conservando las variables de entorno de la Terminal A.

### Reglas que debes respetar durante la demostración

- Los comandos `squad` se ejecutan en PowerShell, **no** dentro del prompt de Copilot. Sal con `/exit` antes de usarlos.
- Las instrucciones en bloques `text` se escriben **dentro** del prompt de Copilot.
- Cambiar `$env:COPILOT_*` no afecta a una sesión de Copilot ya abierta. Para aplicar un cambio, cierra la sesión con `/exit`, cambia la variable y vuelve a lanzar `copilot`.
- La Terminal B nunca define variables `COPILOT_*`. Solo necesita `$CopilotBaseUrl` y la clave que el script pide de forma interactiva.

## 1. Requisitos

Instala estas herramientas y comprueba que están disponibles en PowerShell 7:

```powershell
az --version
azd version
terraform version
copilot --version
squad --version
dotnet --version
```

Necesitas permisos de Azure para:

- Crear recursos en la suscripción de Azure;
- Asignar roles RBAC (*Role-Based Access Control*);
- Crear el estado remoto de Terraform;
- Consultar Application Insights;
- Ejecutar GitHub Copilot CLI (*Command-Line Interface*) y Squad.

No guardes claves de APIM en archivos, comandos históricos ni el repositorio.

## 2. Proporcionar los datos del entorno

Todos los comandos de los pasos 2 a 5 se ejecutan en la **Terminal C**.

La persona que ejecuta la demostración debe proporcionar:

- El identificador de la suscripción de Azure;
- El nombre del entorno de `azd`.

Solicítalos al principio de la demostración:

```powershell
$SubscriptionId = Read-Host 'Azure subscription ID'
$EnvironmentName = Read-Host 'azd environment name'
```

Inicia sesión en el tenant correspondiente y selecciona la suscripción:

```powershell
az login
az account set --subscription $SubscriptionId
azd config set auth.useAzCliAuth true
az account show --query '{subscription:id,tenant:tenantId,name:name}' --output table
```

Comprueba que la suscripción mostrada coincide con `$SubscriptionId`.

## 3. Crear el entorno AZD

Sitúate en la raíz del repositorio. Esta ruta depende de dónde lo hayas clonado; solicítala al principio de la demostración:

```powershell
$RepositoryRoot = Read-Host 'Ruta local del repositorio'
Set-Location $RepositoryRoot
azd env new $EnvironmentName
azd env set AZURE_SUBSCRIPTION_ID $SubscriptionId
```

Si el entorno ya existe, selecciónalo en lugar de crearlo:

```powershell
azd env select $EnvironmentName
azd env set AZURE_SUBSCRIPTION_ID $SubscriptionId
```

## 4. Aprovisionar con `azd up`

Ejecuta el aprovisionamiento completo:

```powershell
azd up -e $EnvironmentName
```

Cuando `azd` solicite valores, confirma la suscripción y la región primaria. Las regiones por defecto están declaradas en [infra/resources/variables.tf](../infra/resources/variables.tf) y solo necesitan sobrescribirse si quieres desplegar en otras.

`azd up` ejecuta las capas declaradas en [azure.yaml](../azure.yaml) en este orden:

1. `backend`: crea el grupo de recursos, la cuenta de Storage y el contenedor privado `tfstate` para el estado remoto de Terraform;
2. `resources`: crea Foundry, APIM, Application Insights, Log Analytics, las políticas y los deployments de modelos.

El Storage Account del estado forma parte de este despliegue. No lo crees manualmente antes de ejecutar `azd up`.

Espera a que `azd up` termine correctamente antes de continuar.

## 5. Validar el despliegue

Ejecuta las comprobaciones locales:

```powershell
./scripts/preflight.ps1
```

Obtén la URL (*Uniform Resource Locator*) compatible con la API de OpenAI de APIM y las regiones desplegadas. `azd` guarda todas las salidas de Terraform en el entorno activo, así que no hace falta consultar el estado remoto:

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json
$CopilotBaseUrl = $AzdValues.copilot_base_url
$PrimaryRegion = $AzdValues.primary_region
$SecondaryRegion = $AzdValues.secondary_region
$CopilotBaseUrl
```

No uses `terraform -chdir=infra/resources output`. `azd` copia cada capa declarada en [azure.yaml](../azure.yaml) a `.azure/<entorno>/infra/<capa>/` e inicializa allí el backend, por lo que el directorio del repositorio no contiene ni estado ni proveedores.

Debe terminar en `/openai/v1`.

Comprueba que existen los cuatro deployments en cada región. Los nombres están declarados en la variable `foundry_model_deployments` de [infra/resources/variables.tf](../infra/resources/variables.tf):

```text
gpt-5.6-sol
gpt-5.6-terra
gpt-5.6-luna
gpt-5.4
```

## 6. Obtener una clave de APIM

Abre ahora la **Terminal A**. Será la terminal de Squad durante el resto de la demostración y no debe cerrarse hasta el paso 19.

El despliegue crea tres suscripciones de APIM con propósitos distintos:

| Suscripción | Uso | Límite aplicado |
| --- | --- | --- |
| `demo-inference` | Sesión de Copilot y Squad durante toda la demostración | 60.000 tokens por minuto y cuota diaria de 500.000 tokens |
| `demo-failover` | Prueba de conmutación regional | Igual que `demo-inference` |
| `demo-ratelimit` | Prueba deliberada de `429` en el paso 13 | 2.000 tokens por minuto con estimación previa del prompt |

La suscripción `demo-inference` no estima los tokens del prompt antes de llamar al backend. Por eso una petición grande, como la creación del roster de Squad, no se rechaza de forma preventiva.

En Azure Portal:

1. Abre el servicio API Management desplegado.
2. Abre **Subscriptions**.
3. Selecciona `demo-inference`.
4. Copia la clave primaria.
5. Repite los pasos 3 y 4 para `demo-ratelimit` y guarda esa clave para el paso 13.
6. Repite los pasos 3 y 4 para `demo-failover` y guarda esa clave para el paso 16.
7. No las guardes en el repositorio ni las pegues en una captura.

Carga la clave de `demo-inference` en memoria como secreto de PowerShell, en la **Terminal A**:

```powershell
$SubscriptionKey = Read-Host 'APIM demo-inference primary key' -AsSecureString
$Pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SubscriptionKey)
try {
    $env:COPILOT_PROVIDER_HEADERS = 'Ocp-Apim-Subscription-Key: ' +
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Pointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Pointer)
    $SubscriptionKey = $null
}
```

La clave de `demo-ratelimit` no se carga en ninguna variable de entorno. El script del paso 13 la pedirá de forma interactiva.

## 7. Configurar Copilot CLI en modo BYOK

Continúa en la **Terminal A**, sin iniciar todavía ninguna sesión de Copilot.

Si has abierto la terminal desde cero, obtén primero la URL del gateway:

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json
$CopilotBaseUrl = $AzdValues.copilot_base_url
```

Configura Copilot para usar APIM como proveedor compatible con la API de OpenAI:

```powershell
$env:COPILOT_PROVIDER_TYPE = 'openai'
$env:COPILOT_PROVIDER_BASE_URL = $CopilotBaseUrl
$env:COPILOT_PROVIDER_WIRE_API = 'responses'
$env:COPILOT_MODEL = 'gpt-5.4'
```

`COPILOT_PROVIDER_BASE_URL` activa *BYOK* (*Bring Your Own Key*). Desde ese momento, Copilot CLI usa el endpoint de APIM y no el *routing* de modelos incluido en la licencia.

El modelo `gpt-5.4` se usa para el coordinador. Los especialistas recibirán sus propios modelos mediante la configuración de Squad.

El *gateway* expone tanto *Chat Completions* como *Responses API*. Esta guía usa `responses` porque los modelos de razonamiento necesitan *Responses API* cuando Squad utiliza *function tools*.

### Comandos de GitHub Copilot CLI

Comprueba la versión y consulta las opciones disponibles en la **Terminal A**, antes de iniciar la sesión:

```powershell
copilot --version
copilot --help
```

Puedes abrir aquí una sesión corta para verificar que la configuración BYOK responde. La sesión definitiva se inicia en el paso 10:

```powershell
copilot --model gpt-5.4 --agent squad --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

También puedes iniciar primero la sesión y seleccionar el modelo y el agente desde el terminal de Copilot. Escribe estos comandos en el prompt de Copilot, no en PowerShell:

```text
/model gpt-5.4
/agent squad
```

Usa `/model` para abrir el selector interactivo de modelos, `/models` como alias, o `/model --session gpt-5.4` para cambiar el modelo solo en la sesión actual. Usa `/agent` para abrir el selector de agentes personalizados o `/agent squad` para activar el coordinador definido en `.github/agents/squad.agent.md`.

Comprueba dentro de Copilot que el modelo y el agente activos son los esperados:

```text
/model
/agent
```

`/agent squad` selecciona el coordinador de Squad. No selecciona directamente a `shuri`, `arcade`, `ironman`, `hulk` o `vision`; esos especialistas se incorporan al roster de Squad y se solicitan mediante instrucciones al coordinador.

Cierra esta sesión de verificación con `/exit` antes de continuar. En el paso 8 ejecutarás `squad init` desde PowerShell y después iniciarás una sesión del coordinador para crear el roster.

## 8. Crear el equipo de Squad

Ejecuta `squad init` en la **Terminal A**, desde PowerShell y sin una sesión de Copilot abierta. Después iniciarás una sesión del coordinador en la misma terminal; esa sesión hereda las variables `COPILOT_*` y crea el roster a través de APIM.

Si el proyecto todavía no está inicializado para Squad, ejecuta primero:

```powershell
squad init --state-backend local --no-workflows
```

Este comando prepara la estructura local de Squad en el proyecto actual:

- `squad init` crea el layout basado en Markdown bajo `.squad/` y deja preparado el archivo de configuración persistente del equipo. No añade por sí solo los cinco especialistas de esta demostración; esos se incorporan después mediante el coordinador de Squad.
- `--state-backend local` configura el estado de Squad para que se mantenga en el propio proyecto, en lugar de usar un backend alternativo o un equipo remoto.
- `--no-workflows` evita que Squad escriba workflows de GitHub Actions bajo `.github/`. La demostración ejecuta Squad desde la Terminal A y no necesita automatizaciones de GitHub Actions.

La inicialización es segura de repetir pues los archivos existentes se conservan. Si ya existe el directorio `.squad/` y el proyecto está inicializado, omite este comando.

Es importante contestar que "no" (`n`) cuando se pregunte por *"Add @copilot as an autonomous team member?"*

Para crear los agentes especialistas del Squad, inicia una sesión del coordinador:

```powershell
copilot --agent squad --model gpt-5.4 --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

Tras cargar Copilot, debes ver una pantalla como la siguiente donde el agente de Squads está activo y el modelo `gpt-5.4` seleccionado.

![Pantalla de Copilot con el agente de Squads activo](images/demo-guide-1.jpg)

Escribe esta instrucción en el prompt de Copilot:

```text
Configura el roster de Squad con estos cinco especialistas:
- `shuri`, con rol `lead`
- `arcade`, con rol `game-developer`
- `ironman`, con rol `backend`
- `hulk`, con rol `tester`
- `vision`, con rol `docs`

Conserva los cuatro agentes integrados: Scribe, Ralph, Rai y Fact Checker.
No añadas a `@copilot` como miembro autónomo.
Pide confirmación antes de crear o modificar archivos.
```

Confirma la propuesta del coordinador cuando muestre los cinco especialistas. El coordinador creará sus archivos `charter.md` e `history.md`, actualizará `.squad/team.md`, `.squad/routing.md` y `.squad/casting/registry.json`, y mantendrá los cuatro agentes integrados. Después escribe `/exit` para volver a PowerShell.

Comprueba el roster:

```powershell
squad cast
squad doctor
```

El equipo debe contener cinco especialistas de la demostración y los cuatro agentes integrados, además del coordinador.

## 9. Asignar un modelo Foundry a cada miembro

Este paso se ejecuta **dentro** de una sesión de Copilot. Iníciala en la **Terminal A** si la cerraste al terminar el paso 7:

```powershell
copilot --agent squad --model gpt-5.4 --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

Escribe la siguiente instrucción en el prompt de Copilot, no en PowerShell:

```text
Configura estos modelos para los miembros del equipo:
- Miembro `shuri`: gpt-5.6-sol
- Miembro `arcade`: gpt-5.6-terra
- Miembro `ironman`: gpt-5.6-terra
- Miembro `hulk`: gpt-5.6-terra
- Miembro `vision`: gpt-5.6-luna
Guarda las preferencias en la configuración persistente de Squad.
```

Squad debe guardar los overrides en `.squad/config.json`. La estructura esperada es equivalente a esta:

```json
{
  "version": 1,
  "stateBackend": "local",
  "agentModelOverrides": {
    "shuri": "gpt-5.6-sol",
    "arcade": "gpt-5.6-terra",
    "ironman": "gpt-5.6-terra",
    "hulk": "gpt-5.6-terra",
    "vision": "gpt-5.6-luna"
  }
}
```

No añadas un `defaultModel` que sobrescriba las preferencias individuales.

## 10. Iniciar Squad con el secreto protegido

Squad lee `.squad/config.json` al arrancar. Para que los modelos asignados en el paso 9 estén activos, reinicia la sesión:

1. Escribe `/exit` en el prompt de Copilot para cerrar la sesión del paso 9.
2. Comprueba que sigues en la **Terminal A** y que las variables no se han perdido:

   ```powershell
   $env:COPILOT_PROVIDER_BASE_URL
   ```

   Debe mostrar la URL de APIM terminada en `/openai/v1`. Si aparece vacía, la terminal es nueva: vuelve a ejecutar el bloque de preparación de la Terminal A.

3. Inicia la sesión definitiva de la demostración:

   ```powershell
   copilot --agent squad --model gpt-5.4 --secret-env-vars=COPILOT_PROVIDER_HEADERS
   ```

`--secret-env-vars` evita que el valor de la clave de APIM se exponga a herramientas de shell o servidores MCP (*Model Context Protocol*) ejecutados por los agentes.

Esta sesión debe permanecer abierta durante los pasos 11, 12 y 13. No la cierres para consultar Application Insights: esas consultas se hacen en el navegador.

## 11. Confirmar que Squad usa Foundry

Antes de pedir código, abre Application Insights en Azure Portal desde el navegador, sin tocar la Terminal A:

1. Abre el recurso de Application Insights.
2. Selecciona **Logs**.
3. Selecciona un rango de tiempo corto, por ejemplo **Last 15 minutes**.
4. Ejecuta esta consulta inicial:

```kusto
customMetrics
| where timestamp > ago(15m)
| where name == "Total Tokens"
| extend Subscription = tostring(customDimensions["Subscription ID"]),
         Backend = tostring(customDimensions["Backend ID"])
| summarize Tokens = sum(valueSum) by Subscription, Backend
| order by Subscription asc, Backend asc
```

Anota los resultados.

En la sesión de Squad, solicita una tarea pequeña y explícita:

```text
Pide a Shuri que diseñe la arquitectura mínima del Tetris de terminal.
Pide a Vision que documente las decisiones.
No escribas código todavía.
```

Espera a que terminen los agentes y vuelve a ejecutar la consulta.

Debe aumentar la fila:

```text
Subscription: demo-inference
Backend:      foundry-primary
```

Esta evidencia demuestra que la ejecución de Squad generó llamadas que atravesaron APIM y llegaron al backend Foundry primario.

La consulta actual identifica la suscripción y la región de *backend*. No identifica todavía el modelo en la métrica de APIM. Para demostrar el modelo individual, usa los anuncios de modelo de Squad junto con los *deployments* de Foundry y verifica el consumo del *deployment* en las métricas del recurso Foundry.

## 12. Construir el Tetris mínimo

Continúa en la sesión de Squad abierta en el paso 10 y solicita el desarrollo por fases:

```text
Construye un Tetris mínimo jugable en terminal usando .NET.

Condiciones:
- Usa una solución .NET ejecutable desde Windows PowerShell;
- Implementa tablero, piezas, movimiento, rotación, caída y puntuación;
- Usa controles de teclado en terminal;
- No añadas interfaz gráfica;
- Mantén el alcance mínimo y jugable;
- Trabaja por fases y pide revisión al especialista correspondiente.
```

Después solicita las fases en este orden:

```text
Shuri: define la arquitectura mínima y las decisiones técnicas.
Arcade: implementa el bucle de juego y la representación del tablero.
Ironman: revisa la estructura .NET y corrige problemas de diseño.
Hulk: crea y ejecuta pruebas para colisiones, líneas completas y puntuación.
Vision: documenta cómo compilar y ejecutar el juego.
```

Cuando el equipo termine, comprueba que existe una aplicación .NET compilable. Ejecuta esto en la **Terminal C** para no cerrar la sesión de Squad:

```powershell
dotnet build
dotnet run
```

Juega una partida corta para demostrar que el resultado es ejecutable.

## 13. Provocar un `429` durante el trabajo de Squad

Esta prueba usa la suscripción APIM `demo-ratelimit`, limitada a 2.000 tokens por minuto. Squad sigue trabajando con `demo-inference`, que tiene un límite de trabajo mucho mayor.

Usa dos terminales simultáneas:

- **Terminal A:** la sesión de Squad abierta en el paso 10, autenticada con `demo-inference`. No la cierres ni cambies su configuración;
- **Terminal B:** una terminal de PowerShell nueva, en la raíz del repositorio, **sin** ninguna variable `COPILOT_*`.

Prepara la Terminal B así:

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json
$CopilotBaseUrl = $AzdValues.copilot_base_url
```

En la **Terminal A**, solicita trabajo suficiente para mantener a los especialistas activos:

```text
Continúa mejorando el Tetris. Pide a Arcade que revise el juego,
a Ironman que revise la implementación y a Hulk que amplíe las pruebas.
Trabajad en paralelo y entrega un resumen de cada resultado.
```

Mientras los agentes trabajan, ejecuta en la **Terminal B**:

```powershell
./scripts/test-rate-limit.ps1 `
  -BaseUrl $CopilotBaseUrl `
  -PromptWords 650
```

El script solicita la clave de forma segura. Introduce la clave de `demo-ratelimit`, no la de `demo-inference`.

El resultado esperado es:

```text
APIM returned 429 after N successful requests.
```

El `429` demuestra que APIM aplicó la política `llm-token-limit`. La petición fue rechazada por el gateway antes de llegar a Foundry.

En la **Terminal A**, Squad debe continuar trabajando sin interrupción. Esto demuestra que el límite es por suscripción APIM y aisla el consumo de cada consumidor. No cambies el modelo ni la URL en ninguna de las dos terminales.

Si quieres mostrar también el efecto sobre Squad, repite el script en la Terminal B apuntando a `demo-inference` con un valor alto de `-PromptWords` y `-MaxAttempts`. Espera aproximadamente un minuto para que se reinicie la ventana de tokens y pide a Squad que continúe desde la Terminal A:

```text
Reintenta la última tarea ahora que la ventana de consumo debería haberse reiniciado.
```

La tarea debe volver a progresar con la misma configuración BYOK.

## 14. Mostrar el `429` en Application Insights

En Application Insights, ejecuta esta consulta KQL (*Kusto Query Language*):

```kusto
requests
| where timestamp > ago(15m)
| where resultCode == "429"
| project timestamp, name, resultCode, operation_Id
| order by timestamp desc
```

Después consulta los tokens aceptados:

```kusto
customMetrics
| where timestamp > ago(15m)
| where name in ("Total Tokens", "Prompt Tokens", "Completion Tokens")
| extend Subscription = tostring(customDimensions["Subscription ID"]),
         Backend = tostring(customDimensions["Backend ID"])
| summarize Tokens = sum(valueSum) by Subscription, Backend, Metric = name
| order by Subscription asc, Backend asc, Metric asc
```

Explica al público:

- `requests.resultCode == "429"` demuestra el rechazo de APIM;
- Los tokens de las solicitudes aceptadas aparecen en `customMetrics`, separados por suscripción;
- `demo-ratelimit` alcanza su límite mientras `demo-inference` sigue consumiendo con normalidad;
- El `429` no es un fallo regional;
- El circuito de *failover* está diseñado para errores `5xx`, no para este `429`;
- Cambiar de modelo o región no debe permitir saltarse el límite de la suscripción.

## 15. Demostrar que no existe fallback hacia GitHub Copilot

Esta prueba necesita una **Terminal D** nueva. No modifiques la Terminal A: si sobrescribes su clave, perderás la sesión de trabajo y tendrás que volver a introducir la clave válida.

Abre una terminal de PowerShell nueva en la raíz del repositorio y configúrala con una clave inválida:

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json

$env:COPILOT_PROVIDER_TYPE = 'openai'
$env:COPILOT_PROVIDER_BASE_URL = $AzdValues.copilot_base_url
$env:COPILOT_PROVIDER_WIRE_API = 'responses'
$env:COPILOT_MODEL = 'gpt-5.4'
$env:COPILOT_PROVIDER_HEADERS = 'Ocp-Apim-Subscription-Key: invalid-for-demo'

copilot --agent squad --model gpt-5.4 --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

Solicita una respuesta sencilla:

```text
Responde únicamente: BYOK conectado.
```

El resultado esperado es un error `401` o equivalente del *gateway*. Copilot no debe responder usando los modelos incluidos en la licencia.

Cierra la sesión con `/exit` y **cierra por completo la Terminal D**. Así garantizas que la clave inválida no se reutiliza en el resto de la demostración. Continúa en la Terminal A, que conserva la clave válida.

## 16. Demostrar el failover regional

Esta prueba usa la suscripción `demo-failover` y se ejecuta en la **Terminal B**, la misma del paso 13. No requiere variables `COPILOT_*` ni cerrar la sesión de Squad.

Ejecútala solo cuando ninguna otra carga esté usando el gateway de la demostración; redirige temporalmente el *backend* primario a respuestas `503` controladas.

Obtén los parámetros del entorno azd y lanza el script:

```powershell
$AzdValues = azd env get-values --output json | ConvertFrom-Json

./scripts/test-failover.ps1 `
  -SubscriptionId $AzdValues.AZURE_SUBSCRIPTION_ID `
  -ResourceGroup $AzdValues.resource_group_name `
  -ServiceName $AzdValues.apim_name `
  -GatewayUrl $AzdValues.apim_gateway_url `
  -ExpectedPrimaryUrl $AzdValues.apim_primary_backend_url `
  -PrimaryRegion $AzdValues.primary_region `
  -SecondaryRegion $AzdValues.secondary_region
```

El script pide la clave de `demo-failover` de forma interactiva. El resultado esperado confirma que la región secundaria respondió después de los fallos `5xx` del primario.

El script restaura la URL original y el *circuit breaker* en su bloque `finally`. APIM puede mantener el circuito abierto hasta dos minutos después de la restauración; espera ese tiempo antes de pedir trabajo nuevo a Squad en la Terminal A.

Contrasta este comportamiento con el del paso 13: el `429` del límite de tokens no activa el *circuit breaker*, que solo reacciona a errores `5xx` del *backend*.

## 17. Consultar tokens por suscripción y backend

En Application Insights, ejecuta:

```kusto
customMetrics
| where timestamp > ago(24h)
| where name in ("Total Tokens", "Prompt Tokens", "Completion Tokens")
| extend Subscription = tostring(customDimensions["Subscription ID"]),
         Backend = tostring(customDimensions["Backend ID"])
| summarize Tokens = sum(valueSum) by Subscription, Backend, Metric = name
| order by Subscription asc, Backend asc, Metric asc
```

Interpreta las columnas así:

| Columna | Significado |
| --- | --- |
| `Subscription` | Suscripción APIM que autenticó la llamada, por ejemplo `demo-inference` |
| `Backend` | Backend seleccionado por APIM, por ejemplo `foundry-primary` |
| `Metric` | Tipo de tokens contabilizado |
| `Tokens` | Suma de tokens emitida por APIM en el periodo consultado |

Además del límite por minuto, `demo-inference` aplica una cuota diaria de 500.000 tokens. APIM devuelve la cuota restante en la cabecera `x-demo-remaining-quota-tokens` de cada respuesta aceptada y responde `403` cuando la cuota se agota. Esto permite demostrar gobernanza de coste acumulado sin interrumpir la sesión de Squad con un `429` por minuto.

Estas métricas no son una factura y no atribuyen todavía consumo a un especialista individual. La atribución actual es por suscripción APIM.

## 18. Evidencias que debe mostrar el demostrador

Guarda o muestra estas evidencias, en este orden:

1. `azd up` termina correctamente.
2. Existen los deployments de Foundry en las dos regiones.
3. Squad muestra los cinco especialistas.
4. Squad anuncia el modelo seleccionado para cada especialista.
5. Application Insights muestra tokens para `demo-inference` y `foundry-primary`.
6. El Tetris compila y se ejecuta en terminal.
7. La prueba sobre `demo-ratelimit` devuelve `429` mientras Squad continúa trabajando con `demo-inference`.
8. Application Insights muestra el `429` y los tokens aceptados, separados por suscripción.
9. La sesión con clave inválida falla y no continúa por GitHub Copilot.
10. La prueba de failover obtiene una respuesta correcta desde la región secundaria tras los `5xx` del primario.
11. Tras reiniciar la ventana de cuota, Squad continúa con la misma configuración BYOK.

## 19. Recuperación al finalizar

Cierra la sesión de Copilot de la Terminal A con `/exit` y elimina las variables sensibles de esa terminal:

```powershell
Remove-Item Env:COPILOT_PROVIDER_HEADERS -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_TYPE -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_WIRE_API -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_MODEL -ErrorAction SilentlyContinue
```

Cierra después todas las terminales de la demostración. La clave de APIM solo vive en la memoria del proceso de PowerShell, así que cerrar la terminal la elimina.

Si solo quieres detener el coste de la demostración, destruye el entorno con el comando de `azd` correspondiente después de confirmar que no necesitas conservar sus datos:

```powershell
azd down
```

No ejecutes `azd down` durante la demostración.

## 20. Limitaciones conocidas

- APIM registra actualmente suscripción y *backend*, no el especialista de Squad ni el *deployment* de modelo como dimensiones métricas.
- El límite estricto de 2.000 tokens por minuto se aplica solo a `demo-ratelimit`. La sesión de Squad usa `demo-inference`, con 60.000 tokens por minuto y cuota diaria.
- `demo-inference` no estima los tokens del prompt; el límite se aplica con el consumo real devuelto por Foundry, de modo que una petición grande no se rechaza antes de ejecutarse.
- El `429` demuestra gobernanza de consumo, no *failover* regional.
- El *gateway* publica *Chat Completions* y *Responses API*. La sesión de Squad usa *Responses API*; los scripts de prueba mantienen *Chat Completions* porque sus payloads y comprobaciones están diseñados para ese contrato.
- Los modelos de *fallback* predeterminados de Squad pueden incluir proveedores que no pertenecen a Foundry. Para esta demostración no aceptes *fallbacks* externos.
