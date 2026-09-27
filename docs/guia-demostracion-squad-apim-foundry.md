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

Sitúate en la raíz del repositorio:

```powershell
Set-Location 'F:\repos\personal\2026-git-hub-dev-days'
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

Cuando `azd` solicite valores, confirma la suscripción y la región primaria `francecentral`.

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

Obtén la URL (*Uniform Resource Locator*) compatible con la API de OpenAI de APIM:

```powershell
$CopilotBaseUrl = terraform -chdir=infra/resources output -raw copilot_base_url
$CopilotBaseUrl
```

Debe terminar en `/openai/v1`.

Comprueba que existen los cuatro deployments en cada región:

```text
gpt-5.6-sol
gpt-5.6-terra
gpt-5.6-luna
gpt-5.4
```

## 6. Obtener una clave de APIM

En Azure Portal:

1. Abre el servicio API Management desplegado.
2. Abre **Subscriptions**.
3. Selecciona `demo-inference`.
4. Copia la clave primaria.
5. No la guardes en el repositorio ni la pegues en una captura.

Carga la clave en memoria como secreto de PowerShell:

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

## 7. Configurar Copilot CLI en modo BYOK

Configura Copilot para usar APIM como proveedor compatible con la API de OpenAI:

```powershell
$env:COPILOT_PROVIDER_TYPE = 'openai'
$env:COPILOT_PROVIDER_BASE_URL = $CopilotBaseUrl
$env:COPILOT_PROVIDER_WIRE_API = 'completions'
$env:COPILOT_MODEL = 'gpt-5.4'
```

`COPILOT_PROVIDER_BASE_URL` activa *BYOK* (*Bring Your Own Key*). Desde ese momento, Copilot CLI usa el endpoint de APIM y no el *routing* de modelos incluido en la licencia.

El modelo `gpt-5.4` se usa para el coordinador. Los especialistas recibirán sus propios modelos mediante la configuración de Squad.

El *gateway* actual expone *Chat Completions*. Por eso se utiliza `completions`. No cambies a *Responses API* durante esta guía.

## 8. Crear el equipo de Squad

Comprueba que no hay miembros creados:

```powershell
squad status
squad cast
```

Añade estos especialistas. Cada comando abre el asistente de creación y permite confirmar la incorporación:

```powershell
squad cast --name shuri --role lead
squad cast --name arcade --role game-developer
squad cast --name ironman --role backend
squad cast --name hulk --role tester
squad cast --name vision --role docs
```

Comprueba el roster:

```powershell
squad cast
squad doctor
```

El equipo debe contener cinco miembros además del coordinador.

## 9. Asignar un modelo Foundry a cada miembro

Dentro de la sesión de Copilot/Squad, solicita estas preferencias persistentes:

```text
Configura estos modelos para los miembros del equipo:
- Miembro `shuri`: gpt-5.6-sol
- Miembro `mario`: gpt-5.6-terra
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
    "mario": "gpt-5.6-terra",
    "ironman": "gpt-5.6-terra",
    "hulk": "gpt-5.6-terra",
    "vision": "gpt-5.6-luna"
  }
}
```

No añadas un `defaultModel` que sobrescriba las preferencias individuales.

## 10. Iniciar Squad con el secreto protegido

Inicia Copilot como agente coordinador de Squad:

```powershell
copilot --agent squad --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

`--secret-env-vars` evita que el valor de la clave de APIM se exponga a herramientas de shell o servidores MCP (*Model Context Protocol*) ejecutados por los agentes.

## 11. Confirmar que Squad usa Foundry

Antes de pedir código, abre Application Insights en Azure Portal:

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

En la misma sesión de Squad, solicita el desarrollo por fases:

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
Mario: implementa el bucle de juego y la representación del tablero.
Ironman: revisa la estructura .NET y corrige problemas de diseño.
Hulk: crea y ejecuta pruebas para colisiones, líneas completas y puntuación.
Vision: documenta cómo compilar y ejecutar el juego.
```

Cuando el equipo termine, comprueba que existe una aplicación .NET compilable:

```powershell
dotnet build
dotnet run
```

Juega una partida corta para demostrar que el resultado es ejecutable.

## 13. Provocar un `429` durante el trabajo de Squad

Esta prueba usa la misma suscripción APIM `demo-inference`. El límite actual es de 2.000 tokens por minuto.

Usa dos terminales:

- **Terminal A:** sesión de Copilot con Squad;
- **Terminal B:** prueba de consumo APIM.

En la Terminal A, solicita trabajo suficiente para mantener a los especialistas activos:

```text
Continúa mejorando el Tetris. Pide a Mario que revise el juego,
a Ironman que revise la implementación y a Hulk que amplíe las pruebas.
Trabajad en paralelo y entrega un resumen de cada resultado.
```

Mientras los agentes trabajan, ejecuta en la Terminal B:

```powershell
./scripts/test-rate-limit.ps1 `
  -BaseUrl $CopilotBaseUrl `
  -PromptWords 650
```

El script usa la clave que solicita de forma segura. Introduce la misma clave de `demo-inference` que utiliza Copilot.

El resultado esperado es:

```text
APIM returned 429 after N successful requests.
```

El `429` demuestra que APIM aplicó la política `llm-token-limit`. La petición fue rechazada por el gateway antes de llegar a Foundry.

En la Terminal A, Squad debe mostrar un error de *rate limit*, un reintento o la imposibilidad temporal de continuar. No cambies el modelo ni la URL para superar el error.

Espera aproximadamente un minuto para que se reinicie la ventana de tokens y pide a Squad que continúe:

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
- Los tokens de las solicitudes aceptadas aparecen en `customMetrics`;
- El `429` no es un fallo regional;
- El circuito de *failover* está diseñado para errores `5xx`, no para este `429`;
- Cambiar de modelo o región no debe permitir saltarse el límite de la suscripción.

## 15. Demostrar que no existe fallback hacia GitHub Copilot

Abre una sesión nueva con una clave inválida:

```powershell
$env:COPILOT_PROVIDER_HEADERS = 'Ocp-Apim-Subscription-Key: invalid-for-demo'
copilot --agent squad --secret-env-vars=COPILOT_PROVIDER_HEADERS
```

Solicita una respuesta sencilla:

```text
Responde únicamente: BYOK conectado.
```

El resultado esperado es un error `401` o equivalente del *gateway*. Copilot no debe responder usando los modelos incluidos en la licencia.

Restaura la clave válida en una nueva sesión antes de continuar con la demostración.

## 16. Consultar tokens por suscripción y backend

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

Estas métricas no son una factura y no atribuyen todavía consumo a un especialista individual. La atribución actual es por suscripción APIM.

## 17. Evidencias que debe mostrar el demostrador

Guarda o muestra estas evidencias, en este orden:

1. `azd up` termina correctamente.
2. Existen los deployments de Foundry en las dos regiones.
3. Squad muestra los cinco especialistas.
4. Squad anuncia el modelo seleccionado para cada especialista.
5. Application Insights muestra tokens para `demo-inference` y `foundry-primary`.
6. El Tetris compila y se ejecuta en terminal.
7. La prueba concurrente devuelve `429`.
8. Application Insights muestra el `429` y los tokens aceptados.
9. La sesión con clave inválida falla y no continúa por GitHub Copilot.
10. Tras reiniciar la ventana de cuota, Squad continúa con la misma configuración BYOK.

## 18. Recuperación al finalizar

Cierra la sesión de Copilot y elimina las variables sensibles de la terminal:

```powershell
Remove-Item Env:COPILOT_PROVIDER_HEADERS -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_TYPE -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_PROVIDER_WIRE_API -ErrorAction SilentlyContinue
Remove-Item Env:COPILOT_MODEL -ErrorAction SilentlyContinue
```

Si solo quieres detener el coste de la demostración, destruye el entorno con el comando de `azd` correspondiente después de confirmar que no necesitas conservar sus datos:

```powershell
azd down
```

No ejecutes `azd down` durante la demostración.

## 19. Limitaciones conocidas

- APIM registra actualmente suscripción y *backend*, no el especialista de Squad ni el *deployment* de modelo como dimensiones métricas.
- El límite de tokens se aplica a la suscripción `demo-inference`, compartida por la sesión de Squad.
- El `429` demuestra gobernanza de consumo, no *failover* regional.
- El *gateway* actual publica *Chat Completions*; la compatibilidad completa con *Responses API* debe validarse por separado.
- Los modelos de *fallback* predeterminados de Squad pueden incluir proveedores que no pertenecen a Foundry. Para esta demostración no aceptes *fallbacks* externos.
