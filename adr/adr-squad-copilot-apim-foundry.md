# ADR — Architecture Description Review
## Squad + GitHub Copilot CLI + Azure API Management + Microsoft Foundry

**Estado:** Proposed  
**Fecha:** 2026-09-26  
**Tipo:** Architecture Description Review (ADR)  
**Ámbito:** Demo técnica / blueprint reutilizable  
**Audiencia:** Coding assistant / ingeniería de plataforma / DevRel / arquitectura Azure

---

## 1. Resumen ejecutivo

Esta demo debe demostrar cómo un proyecto configurado con Squads a través de GitHub Copilot CLI  para hacer algo simple, como un Tetris, empleando un equipo de agentes de IA cuyos modelos LLM están desplegados en **Microsoft Foundry** y son accedidos a través de **Azure API Management (APIM)** como gateway central de IA.

**NO ES USAR** Squads como librería.

La arquitectura debe mantener separadas cuatro responsabilidades:

1. **Squad**: orquestación del equipo de agentes, especialización, delegación y ejecución paralela.
2. **GitHub Copilot CLI**: runtime/harness desde el que Squad ejecuta los agentes y que proporciona el acceso configurable al proveedor de modelos.
3. **Azure API Management**: frontera de gobierno de las llamadas LLM: autenticación al backend, límites de tokens, observabilidad, atribución por agente y routing/failover.
4. **Microsoft Foundry**: hosting de los deployments de modelos que reciben las llamadas de inferencia.

La idea central de la demo es:

> **Los agentes hacen el trabajo; el gateway gobierna el consumo.**

Por tanto, los agentes no deben conocer directamente las regiones de Foundry ni incorporar lógica propia de rate limiting, coste o failover.

---

## 2. Contexto

Squad proporciona un equipo humano-dirigido de agentes de desarrollo a través de GitHub Copilot. La documentación actual de Squad describe especialistas como frontend, backend, tester y lead, cada uno con su propio contexto, conocimiento persistente y capacidad de trabajar en paralelo. Squad recomienda actualmente utilizar GitHub Copilot CLI como interfaz principal, por ejemplo mediante `copilot --agent squad`. Squad continúa siendo software alpha/experimental, por lo que sus APIs y comandos pueden cambiar. [1]

GitHub Copilot CLI permite configurar un proveedor de modelos propio (BYOK) y soporta proveedores OpenAI-compatible, incluido cualquier endpoint que implemente la API de Chat Completions de OpenAI. La configuración usa, entre otras, `COPILOT_PROVIDER_BASE_URL`, `COPILOT_PROVIDER_TYPE`, `COPILOT_PROVIDER_BEARER_TOKEN`/`COPILOT_PROVIDER_API_KEY` y `COPILOT_MODEL`. Los modelos deben soportar tool calling y streaming; GitHub recomienda una ventana de contexto de al menos 128k tokens para mejores resultados. [2]

Microsoft Foundry ofrece endpoints compatibles con OpenAI para determinados deployments. La forma exacta de endpoint y autenticación depende del tipo de deployment; cuando se utiliza una superficie OpenAI-compatible, el cliente puede utilizar un `base_url` compatible y un nombre de deployment/modelo apropiado. Foundry admite autenticación mediante Microsoft Entra ID en los escenarios compatibles. [3]

Azure API Management dispone de capacidades específicas para APIs LLM. Entre ellas:

- `llm-token-limit` para limitar consumo de tokens por clave/counter key.
- `llm-emit-token-metric` para emitir métricas de consumo de tokens a Application Insights.
- entidades backend con circuit breaker.
- pools de backends para routing/load balancing.
- autenticación de backend mediante Managed Identity. [4][5][6]

La demo debe combinar estas capacidades en una arquitectura única y reproducible con Terraform.

---

## 3. Problema que queremos demostrar

Un Squad puede generar muchas llamadas LLM simultáneas. Cuando varios agentes trabajan en paralelo, aparecen rápidamente problemas de plataforma:

- Un agente puede consumir una parte desproporcionada del presupuesto.
- Un `429` puede no ser atribuible de forma inmediata al agente que lo provocó.
- Las métricas agregadas por aplicación no permiten distinguir fácilmente frontend, backend, tester, lead, etc.
- Una aplicación o agente no debería conocer las regiones concretas de inferencia.
- La lógica de retry/failover no debería estar repartida entre prompts y agentes.
- Las claves de acceso al backend de modelos no deberían vivir en los agentes.
- Ante un fallo regional, el equipo de agentes debería poder continuar trabajando sin reconfiguración manual.

La demo debe mostrar una solución de plataforma para estos problemas.

Para ello la demo aprovisionará los recursos necesarios (Foundry, APIM, managed identities) para que desde GitHub Copilot CLI se configuren modelos disponibles para los agentes de Squads, quienes puedan interactuar con los modelos LLM desplegados en Microsoft Foundry a través de Azure API Management como gateway central de IA.

---

## 4. Decisión arquitectónica

### 4.1 Flujo canónico

El flujo oficial de la demo será:

```text
                         HUMAN
                           │
                           ▼
                     Squad / task
                           │
                           ▼
                  GitHub Copilot CLI
                           │
                  BYOK / OpenAI-compatible
                           │
                           ▼
               ┌────────────────────────┐
               │ Azure API Management   │
               │        AI Gateway      │
               │                        │
               │ • token limits         │
               │ • agent attribution    │
               │ • token metrics        │
               │ • cost estimation      │
               │ • managed identity     │
               │ • backend routing      │
               │ • circuit breaker      │
               └───────────┬────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
       ┌─────────────────┐   ┌─────────────────┐
       │ Microsoft       │   │ Microsoft       │
       │ Foundry         │   │ Foundry         │
       │ Region A        │   │ Region B        │
       │ model deployment│   │ model deployment│
       └─────────────────┘   └─────────────────┘
```

### 4.2 Regla fundamental de separación de responsabilidades

**Squad no llama directamente a Foundry.**

Squad ejecuta agentes dentro de GitHub Copilot CLI (GHC). Y es el GHC el que tiene configurado los modelos LLM que usará cada agente de Squads para interactuar con los backends de Microsoft Foundry a través de Azure API Management.

**Copilot CLI no debe conocer las URLs regionales de Foundry.**

Copilot CLI debe utilizar como `COPILOT_PROVIDER_BASE_URL` el endpoint del gateway de APIM.

**APIM sí conoce los backends regionales.**

APIM es responsable de seleccionar backend, aplicar políticas de consumo y autenticarse ante Foundry.

---

## 5. Arquitectura lógica por componente

### 5.1 Squad

Squad es la capa de orquestación.

Debe:

- mantener el roster y las responsabilidades de los agentes;
- enrutar trabajo al especialista correspondiente;
- lanzar trabajo paralelo cuando corresponda;
- mantener estado y conocimiento persistente en `.squad/`;
- permitir inspeccionar decisiones y logs.

Squad no debe:

- contener URLs de Foundry;
- contener API keys de Foundry;
- implementar el circuit breaker regional;
- implementar el coste financiero;
- calcular límites de tokens como mecanismo principal de gobierno.

La demo debe utilizar la instalación y estructura real de Squad. No se debe crear un simulador de Squad.

Referencia:

https://github.com/bradygaster/squad

La idea es hacer un tetris en terminal utilizando agentes de Squads que interactúan con modelos LLM desplegados en Microsoft Foundry a través de Azure API Management.

---

### 5.2 GitHub Copilot CLI

GitHub Copilot CLI es el harness de ejecución.

La configuración conceptual será:

```bash
export COPILOT_PROVIDER_BASE_URL="<APIM_OPENAI_COMPATIBLE_ENDPOINT>"
export COPILOT_PROVIDER_TYPE="openai"
export COPILOT_MODEL="<MODEL_OR_DEPLOYMENT>"
```

Para el acceso al proveedor, usar el mecanismo BYOK soportado por la versión actual de Copilot CLI.

Importante: no asumir que una API key de Foundry debe ser utilizada por el cliente. El diseño preferido es que APIM controle el acceso al backend y que la autenticación cliente → APIM sea independiente de la autenticación APIM → Foundry.

La demo debe documentar qué credencial, si alguna, utiliza Copilot CLI para autenticarse ante APIM.

---

### 5.3 Microsoft Foundry

Provisionar dos entornos funcionalmente equivalentes:

```text
Foundry Primary
Foundry Secondary
```

Cada región debe disponer de:

- recurso Foundry/AI Services compatible con la arquitectura elegida;
- proyecto cuando aplique;
- deployment del modelo;
- permisos RBAC necesarios para la identidad de APIM.

El modelo/deployment será parametrizable.

No asumir que el mismo deployment está disponible automáticamente en todas las regiones. Terraform debe parametrizar:

```hcl
primary_region
secondary_region
model_name
primary_deployment_name
secondary_deployment_name
```

La arquitectura deberá comprobar durante `plan/apply` o mediante un script de preflight que la combinación elegida es válida.

---

### 5.4 Azure API Management

APIM es el componente central de gobernanza.

Debe exponer una API compatible con el contrato que espera Copilot CLI.

La implementación no debe forzar a Squad a conocer detalles específicos de Foundry.

Las responsabilidades de APIM serán:

```text
Inbound:
  • identificación del agente
  • token governance
  • observabilidad
  • selección/routing del backend

Backend:
  • autenticación con Managed Identity
  • primary/secondary routing
  • circuit breaker

Outbound:
  • preservación del contrato esperado por Copilot CLI
```

---

## 6. Identificación por agente

Este punto es crítico para la demo porque necesitamos responder:

> ¿Qué agente consumió los tokens?

La arquitectura debe conservar una identidad estable del agente durante el recorrido:

```text
Squad agent
   ↓
Copilot CLI execution
   ↓
APIM request
   ↓
agent identity
```

### 6.1 Principio

La atribución debe ser **explícita y determinista**.

No se debe intentar deducir el agente analizando:

- el prompt;
- el texto de la conversación;
- el modelo elegido;
- la ruta del archivo modificado.

### 6.2 Estrategia de implementación

Antes de modificar Squad, inspeccionar la versión utilizada y determinar el extension point soportado para propagar la identidad del agente.

La implementación debe seguir este orden de preferencia:

1. mecanismo oficial de Squad/Copilot para diferenciar la ejecución del agente;
2. configuración por agente que permita proporcionar metadatos al proceso;
3. wrapper/launcher local que establezca la identidad del agente para esa ejecución;
4. adaptador/proxy local únicamente como último recurso.

No hacer un fork permanente de Squad para resolver esta necesidad si existe una alternativa externa y contenida.

### 6.3 Header propuesto

Cuando el mecanismo real permita añadir headers, utilizar un header técnico no ambiguo, por ejemplo:

```http
X-Squad-Agent: frontend
```

Los nombres y valores definitivos deben quedar definidos por la implementación real y documentados.

No asumir que `COPILOT_PROVIDER_HEADERS` es el mecanismo por defecto para esta atribución: la referencia actual de Copilot CLI documenta su existencia y precedencias, pero la política de la demo debe demostrar que el header llega efectivamente al gateway en la ejecución real. [7]

Si se utiliza `COPILOT_PROVIDER_HEADERS`, debe tratarse como mecanismo de transporte, no como fuente de verdad de la identidad.

---

## 7. Gobernanza de tokens

APIM debe aplicar límites de consumo por agente utilizando `llm-token-limit`.

Esta política permite limitar una tasa de tokens por minuto y/o una cuota temporal. Cuando se supera la tasa de tokens se devuelve HTTP `429 Too Many Requests`. [4]

### 7.1 Counter key

El diseño preferido es:

```text
squad:<agent-id>
```

Ejemplos:

```text
squad:lead
squad:frontend
squad:backend
squad:tester
```

La counter key debe derivarse de la identidad del agente extraída de una fuente controlada.

No aceptar ciegamente valores arbitrarios del cliente sin validación. La implementación debe establecer un conjunto permitido de agentes para la demo.

### 7.2 Límites

Los límites deben ser configurables en Terraform:

```hcl
variable "agent_token_limits" {
  type = map(number)

  default = {
    lead     = 30000
    frontend = 20000
    backend  = 20000
    tester   = 12000
  }
}
```

Estos valores son ejemplos y deben poder cambiarse sin editar manualmente la política.

### 7.3 Demo de 429

Debe existir un escenario controlado que provoque un 429 en un agente concreto.

Ejemplo:

```text
frontend
  token rate limit = 20,000 TPM
```

La prueba debe conseguir que el agente exceda el límite y debe mostrar:

```text
HTTP 429
agent = frontend
tokens
timestamp
backend
request identifier
```

El objetivo no es provocar una situación inestable, sino demostrar visualmente que APIM impone el límite.

---

## 8. Métricas de consumo

Utilizar `llm-emit-token-metric` para emitir métricas de uso de tokens a Application Insights. La política soporta APIs LLM con esquemas OpenAI Chat Completions o Responses, entre otros. [5]

### 8.1 Dimensiones

El dashboard debe poder segmentar por:

- Agent
- Model
- Backend/Region
- Token type cuando esté disponible

La implementación debe respetar los límites de dimensiones de Azure Monitor.

Actualmente la política permite hasta cinco dimensiones personalizadas y Azure Monitor establece límites sobre el número de claves y de series temporales activas. Por ello no deben utilizarse dimensiones de cardinalidad elevada como prompts completos, nombres únicos de archivos o IDs efímeros. [5]

### 8.2 Streaming

La política puede depender del campo de uso proporcionado en la respuesta LLM.

Cuando se utiliza streaming, los recuentos pueden ser inexactos si el stream se interrumpe. Para APIs/modelos que lo requieran, habilitar el retorno de usage según el contrato soportado, por ejemplo `include_usage` cuando sea compatible. [5]

La demo debe documentar esta limitación.

---

## 9. Coste por agente

El dashboard debe calcular un **coste estimado**, no presentar el resultado como una factura de Azure.

### 9.1 Formula

```text
estimated_cost =
    (input_tokens / 1,000,000)  * input_price_per_1m
  + (output_tokens / 1,000,000) * output_price_per_1m
```

### 9.2 Configuración

Utilizar una tabla configurable:

```hcl
variable "model_pricing" {
  type = object({
    input_per_1m_tokens  = number
    output_per_1m_tokens = number
  })
}
```

### 9.3 Dashboard esperado

```text
Agent       Input       Output       Total       Est. Cost
----------------------------------------------------------------
Frontend    125,430     48,320       173,750     $...
Backend      98,210     35,102       133,312     $...
Tester       62,300     21,840        84,140     $...
Lead         45,910     18,920        64,830     $...
```

El dashboard debe mostrar una nota:

> Estimated cost based on configured model pricing. Final billing is determined by Azure.

---

## 10. Autenticación APIM → Foundry

APIM debe utilizar **Managed Identity** para acceder a los backends de Foundry.

El objetivo es:

```text
APIM
  ↓
Microsoft Entra ID
  ↓
Foundry
```

sin almacenar una API key de Foundry en:

- código;
- Terraform;
- `.env`;
- policies;
- scripts;
- Git.

APIM permite utilizar una identidad administrada del servicio para solicitar un access token y enviarlo al backend como `Authorization: Bearer`. También permite configurar la identidad directamente en el backend. [6]

### 10.1 Identidad

Preferir una **system-assigned managed identity** para reducir componentes y simplificar la demo, salvo que el entorno requiera separación de identidades.

### 10.2 RBAC

Asignar a la identidad exclusivamente los permisos necesarios.

La documentación actual de APIM destaca que conceder permisos de edición de políticas implica riesgo indirecto porque el editor puede modificar la autenticación basada en identidad administrada. La demo debe documentar este riesgo y seguir mínimo privilegio. [6]

### 10.3 Nunca propagar credenciales del cliente a Foundry

La autenticación cliente → APIM y APIM → Foundry deben ser capas separadas.

APIM es responsable de transformar/autenticar la llamada al backend.

---

## 11. Backend pool y failover regional

Crear dos backends en APIM:

```text
foundry-primary
foundry-secondary
```

El objetivo es:

```text
Priority 1 → primary
Priority 2 → secondary
```

APIM soporta entidades backend, pools para múltiples backends y circuit breaker en backend. [8]

### 11.1 Comportamiento esperado

En condiciones normales:

```text
Client
  ↓
APIM
  ↓
Primary
```

Cuando Primary queda fuera de servicio y su circuito se abre:

```text
Client
  ↓
APIM
  ↓
Secondary
```

Squad no cambia su configuración.

### 11.2 Circuit breaker

Configurar una regla de circuit breaker sensible a fallos apropiados para la demo.

El valor de los umbrales será parametrizable.

Ejemplo conceptual:

```text
Failure condition:
  HTTP 5xx

Trip:
  N failures within T seconds/minutes

Reset:
  configurable duration
```

Debe evaluarse expresamente si los `429` del backend de modelo deben considerarse condición de apertura del circuito en este escenario. Los `429` tienen semántica de throttling y no necesariamente equivalen a una caída regional.

La documentación actual de APIM indica que el circuit breaker protege el backend, detiene temporalmente el envío de requests y restablece el tráfico tras la duración configurada. También advierte que el tripping es aproximado debido a la naturaleza distribuida del gateway. [8]

### 11.3 SKU

No utilizar Consumption si el escenario necesita backend circuit breaker, dado que la documentación actual indica que el circuit breaker de backend no está soportado en Consumption. [8]

Elegir un SKU v2/dedicated compatible y documentarlo.

---

## 12. Simulación de caída regional

La demo necesita una forma segura de provocar una indisponibilidad controlada.

Crear:

```bash
./scripts/fail-primary.sh
```

y:

```bash
./scripts/restore-primary.sh
```

La acción debe ser reversible y no debe destruir la infraestructura.

### 12.1 Secuencia

```text
1. Iniciar Squad.
2. Ejecutar la tarea de login.
3. Confirmar tráfico contra Primary.
4. Mostrar el dashboard.
5. Ejecutar fail-primary.sh.
6. Provocar fallos del Primary.
7. Observar la apertura del circuito.
8. Observar tráfico en Secondary.
9. Verificar que Squad continúa.
10. Ejecutar restore-primary.sh.
```

Durante la transición pueden existir requests en vuelo o fallos puntuales. La demo debe explicitar que “continuidad” significa recuperación automática de nuevas requests, no ausencia matemática de errores durante el cambio.

---

## 13. Tarea funcional de la demo

La tarea debe ser suficientemente real para provocar actividad de varios agentes:

> **Build the login page for the application. Include the frontend experience, authentication API integration, validation, tests, and documentation.**

La implementación de ejemplo puede ser deliberadamente pequeña.

El objetivo es generar:

- trabajo paralelo;
- múltiples llamadas LLM;
- diferencias de consumo;
- telemetría observable;
- oportunidad de provocar 429;
- oportunidad de provocar failover.

---

## 14. Squad de la demo

Utilizar un squad real, configurado según la versión actual del repositorio.

Como equipo conceptual:

```text
Lead
Frontend
Backend
Tester
Scribe
```

Los nombres pueden ser los que Squad genere realmente; la arquitectura no debe depender de nombres concretos.

### 14.1 Responsabilidades

**Lead**

- analizar requisitos;
- coordinar;
- resolver dependencias.

**Frontend**

- construir UI de login;
- validaciones;
- integración cliente.

**Backend**

- endpoint/authentication contract;
- validación;
- integración de backend.

**Tester**

- pruebas;
- edge cases;
- regresión.

**Scribe**

- memoria/registro de decisiones y estado del Squad, conforme al comportamiento estándar de Squad.

Squad actualmente materializa estado en `.squad/`, incluyendo team/routing/decisions, agentes e historial/logs. [1]

---

## 15. Repository layout

La estructura objetivo:

```text
.
├── README.md
├── terraform/
│   ├── providers.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── foundry.tf
│   ├── apim.tf
│   ├── policies.tf
│   ├── monitoring.tf
│   ├── workbook.tf
│   └── modules/
│       ├── foundry/
│       ├── apim/
│       └── monitoring/
│
├── apim/
│   ├── policies/
│   │   ├── inbound.xml
│   │   ├── outbound.xml
│   │   └── errors.xml
│   └── README.md
│
├── squad/
│   └── demo configuration
│
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── preflight.sh
│   ├── smoke-test.sh
│   ├── fail-primary.sh
│   ├── restore-primary.sh
│   └── run-demo.sh
│
├── dashboard/
│   └── workbook.json
│
└── docs/
    ├── architecture.md
    └── demo-script.md
```

Adaptar los nombres si el proveedor Terraform o el recurso de Azure requieren una estructura diferente, pero conservar la separación de responsabilidades.

---

## 16. Terraform

Terraform debe ser la fuente reproducible de la infraestructura.

### 16.1 Variables mínimas

```hcl
subscription_id
tenant_id
resource_group_name
primary_region
secondary_region
apim_name
foundry_primary_name
foundry_secondary_name
model_name
primary_deployment_name
secondary_deployment_name
agent_token_limits
model_pricing
```

### 16.2 Outputs

```text
apim_gateway_url
primary_foundry_endpoint
secondary_foundry_endpoint
dashboard_url
```

Nunca exponer secretos en outputs.

### 16.3 Provider

Usar una versión actual del provider `azurerm`.

Utilizar `azapi` solo cuando exista una propiedad necesaria que no esté disponible de forma fiable en `azurerm`.

No inventar recursos o argumentos Terraform.

---

## 17. Políticas APIM

La policy composition debe ser legible.

Conceptualmente:

```xml
<policies>
  <inbound>
    <base />

    <!-- Resolve / validate agent identity -->

    <!-- Token governance -->
    <llm-token-limit ... />

    <!-- Token telemetry -->
    <llm-emit-token-metric ... />

    <!-- Select backend / pool -->
  </inbound>

  <backend>
    <base />

    <!-- Backend authentication/routing as required -->
  </backend>

  <outbound>
    <base />
  </outbound>

  <on-error>
    <base />
  </on-error>
</policies>
```

No copiar literalmente este fragmento si la policy final necesita una composición diferente.

La policy final debe ser validable por APIM.

---

## 18. Observabilidad

La demo debe tener un dashboard de Azure Monitor/Application Insights.

### 18.1 Agent Cost

```text
Agent
Requests
Input tokens
Output tokens
Total tokens
Estimated cost
429s
5xx
```

### 18.2 Token consumption

Gráfico temporal:

```text
tokens/minute by agent
```

### 18.3 Backend/region

```text
requests by backend
errors by backend
latency by backend
```

### 18.4 Failover

Mostrar:

```text
Primary traffic
Secondary traffic
Circuit state / related errors
```

### 18.5 Request correlation

Cuando sea posible, incluir un request/correlation identifier para poder seleccionar una llamada concreta y seguirla en la telemetría.

No incluir prompts completos ni secretos en métricas.

---

## 19. Cost attribution

La atribución por agente debe construirse con la siguiente cadena:

```text
Agent identity
      ↓
APIM request
      ↓
LLM token metric
      ↓
Azure Monitor
      ↓
Cost estimation workbook/query
```

No hacer:

```text
Prompt text
   ↓
guess agent
```

No hacer:

```text
Application total cost
   ↓
divide equally among agents
```

---

## 20. Smoke tests

Crear:

```bash
./scripts/preflight.sh
./scripts/smoke-test.sh
```

### Preflight

Comprobar:

- Azure CLI autenticado.
- Terraform disponible.
- Copilot CLI disponible.
- Squad disponible.
- suscripción accesible.
- regiones configuradas.
- modelo/deployments configurados.

### Smoke test

#### Test A — APIM

Confirmar endpoint activo.

#### Test B — Primary

Request LLM → Primary.

#### Test C — Managed Identity

Confirmar que APIM autentica al backend sin API key de Foundry.

#### Test D — Token limit

Provocar 429 en el agente de prueba.

#### Test E — Metrics

Confirmar que aparecen métricas tokenizadas.

#### Test F — Attribution

Confirmar `agent=<expected-agent>` en telemetría.

#### Test G — Failover

Forzar Primary down y confirmar request recuperada en Secondary.

---

## 21. Scripts de demostración

### Deploy

```bash
./scripts/deploy.sh
```

Responsabilidades:

1. terraform init;
2. terraform validate;
3. terraform apply;
4. mostrar outputs;
5. opcionalmente ejecutar smoke test.

### Run demo

```bash
./scripts/run-demo.sh
```

Debe preparar:

- endpoint APIM;
- variables de proveedor;
- modelo;
- configuración necesaria para Copilot CLI;
- instrucciones para abrir Squad.

No automatizar una sesión interactiva de Copilot de forma frágil.

### Failover

```bash
./scripts/fail-primary.sh
```

### Restore

```bash
./scripts/restore-primary.sh
```

---

## 22. Seguridad

### Prohibido

No guardar en Git:

```text
Foundry API keys
APIM secrets
GitHub tokens
client secrets
passwords
full bearer tokens
```

### Recomendado

```text
Local:
  Azure CLI / credential chain

Runtime:
  APIM Managed Identity → Foundry
```

### Logging

Nunca registrar:

- Authorization headers;
- API keys;
- bearer tokens;
- prompts completos;
- datos sensibles.

---

## 23. 429: dos clases distintas

La demo debe distinguir dos fuentes posibles de HTTP 429:

### 23.1 429 generado por APIM

Se produce cuando `llm-token-limit` impone el límite configurado para el agente.

Esto demuestra:

```text
agent governance
```

### 23.2 429 generado por Foundry

Puede indicar throttling o límites del backend.

Esto no debe confundirse con el límite per-agent de APIM.

El dashboard debe permitir distinguirlos cuando la telemetría disponible lo permita.

La política de circuit breaker debe considerar cuidadosamente qué status codes representan indisponibilidad y cuáles representan throttling.

---

## 24. Modelo de errores

El comportamiento esperado:

```text
Client/Copilot
     │
     ├── 429 from APIM token policy
     │       → request rejected by governance
     │
     ├── 5xx from Primary
     │       → backend failure accounting
     │
     └── Primary circuit open
             → routing to Secondary
```

No convertir todos los errores en failover automáticamente.

Especialmente, un 429 por token governance no debe provocar un failover de región: cambiar de región no debería permitir a un agente saltarse su límite de consumo.

---

## 25. Model selection

El modelo debe elegirse por compatibilidad con Copilot CLI.

Requisitos mínimos:

- tool calling/function calling;
- streaming;
- suficiente context window;
- API surface compatible con el protocolo elegido.

La documentación actual de Copilot CLI exige tool calling y streaming para proveedores BYOK. [2]

Si un deployment de Foundry no satisface estas capacidades a través del endpoint elegido, debe descartarse para la demo aunque pueda realizar chat completions simples.

---

## 26. Model routing versus agent routing

No confundir:

### Agent routing

Lo realiza Squad:

```text
login UI → Frontend
auth API → Backend
tests → Tester
coordination → Lead
```

### Model routing

Lo realiza APIM:

```text
API request
   ↓
backend pool
   ↓
Foundry Primary / Secondary
```

El agente no debería seleccionar la región.

---

## 27. Multi-region strategy

Primaria:

```text
Region A
```

Secundaria:

```text
Region B
```

Ambas deben proporcionar un deployment suficientemente compatible para procesar las mismas llamadas del cliente.

La arquitectura debe verificar:

- nombre/shape de deployment;
- API compatibility;
- tool calling;
- streaming;
- context window;
- disponibilidad regional;
- autorización.

Cuando no sea posible utilizar idéntico modelo, documentar explícitamente cualquier diferencia y demostrar que el contrato OpenAI-compatible sigue siendo válido.

---

## 28. Decisiones que NO tomamos

### No: llamar directamente a Foundry desde Squad

Rompe la frontera de gobernanza.

### No: repartir el presupuesto desde prompts

El prompt no es una capa fiable de enforcement.

### No: guardar una API key de Foundry en cada agente

Introduce duplicación y superficie de ataque.

### No: enseñar al agente las dos regiones

El agente no debe encargarse de disponibilidad regional.

### No: crear un servicio adicional de proxy salvo necesidad

APIM ya es el gateway.

### No: crear un sistema de facturación

Solo se necesita estimación de coste por agente.

### No: sustituir Squad por un orquestador propio

La demo debe probar Squad real.

---

## 29. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Squad cambia APIs al ser alpha | Alto | Fijar versión usada en la demo y documentarla |
| Copilot CLI cambia BYOK config | Alto | Pin/versionar CLI y validar preflight |
| Modelo Foundry no soporta tools/streaming | Alto | Validarlo antes de la demo |
| Header de agente no llega a APIM | Alto | Test explícito de attribution |
| Métricas no incluyen usage en streaming | Medio | Configurar usage y documentar limitación |
| Alta cardinalidad en métricas | Medio | Limitar dimensiones a valores controlados |
| Failover con errores transitorios | Medio | Usar circuit breaker con umbral/duración conservadores |
| 429 interpretado como fallo regional | Medio | Separar throttling de indisponibilidad |
| Diferencias entre regiones/modelos | Medio | Validación de compatibilidad previa |
| Coste estimado no coincide con billing | Bajo/Medio | Etiquetar claramente como estimación |

---

## 30. Criterios de aceptación

La implementación se considera válida únicamente si puede demostrarse:

### A. Squad real

La tarea corre mediante Squad real dentro de GitHub Copilot CLI.

### B. Paralelismo

Varios especialistas participan en paralelo.

### C. Foundry como model runtime

Los modelos utilizados por Copilot CLI están desplegados en Microsoft Foundry.

### D. APIM como gateway

Copilot CLI utiliza APIM como endpoint de proveedor.

### E. Per-agent attribution

Las llamadas quedan identificadas por agente de manera determinista.

### F. Token governance

APIM aplica límites de tokens por agente.

### G. 429 reproducible

Un agente puede provocar un 429 por exceso de tokens.

### H. Token metrics

El consumo aparece por agente.

### I. Cost estimate

El dashboard muestra coste estimado por agente.

### J. Managed Identity

APIM autentica contra Foundry sin API key almacenada.

### K. Primary/Secondary

Existen dos regiones/backends de Foundry.

### L. Circuit breaker

La región primaria puede abrir circuito ante fallos configurados.

### M. Failover

Las nuevas requests terminan en la región secundaria cuando el primary está fuera de servicio.

### N. Continuidad del Squad

Squad continúa trabajando sin cambiar sus prompts ni conocer la región secundaria.

### O. Terraform

Toda la infraestructura relevante es reproducible mediante Terraform.

---

## 31. Secuencia de demo en directo

### Acto 1 — Presentación

Mostrar:

```text
Squad
↓
GitHub Copilot CLI
↓
APIM
↓
Foundry
```

Explicar que Copilot CLI es el runtime, Squad es la orquestación y APIM es la frontera de gobierno.

### Acto 2 — Deployments

Mostrar en Azure:

```text
Foundry Primary
Foundry Secondary
APIM
```

### Acto 3 — Squad

Ejecutar:

```text
copilot --agent squad
```

Dar la tarea:

```text
Build the login page for the application. Include the frontend experience, authentication API integration, validation, tests, and documentation.
```

Mostrar varios agentes trabajando.

### Acto 4 — Consumo

Abrir el dashboard.

Mostrar:

```text
Frontend → tokens
Backend  → tokens
Tester   → tokens
Lead     → tokens
```

Mostrar coste estimado.

### Acto 5 — 429

Reducir deliberadamente el límite del agente de prueba.

Ejecutar trabajo suficiente.

Mostrar:

```text
429 Too Many Requests
```

Explicar:

> El agente no sabe cuál es su límite y no tiene que saberlo. El gateway lo impone.

### Acto 6 — Fallo regional

Mostrar que Primary está recibiendo tráfico.

Ejecutar:

```bash
./scripts/fail-primary.sh
```

Mostrar errores del Primary.

Mostrar apertura del circuito.

Mostrar tráfico entrando por Secondary.

Volver al Squad y comprobar que sigue trabajando.

### Acto 7 — Regla final

Cerrar con:

> **Los límites de tasa, el failover y la asignación de costes pertenecen al gateway, no a los prompts de tus agentes.**

---

## 32. Entregables del coding assistant

El coding assistant debe entregar:

1. Infraestructura Terraform.
2. Policies APIM.
3. Backends regionales.
4. Managed Identity + RBAC.
5. Foundry primary/secondary.
6. Configuración de Squad.
7. Integración de Copilot CLI con APIM.
8. Mecanismo verificable de `agent-id`.
9. Dashboard Workbook/Monitor.
10. Scripts de deploy, smoke test, failover y restore.
11. README completo.
12. Guion de demo.

---

## 33. Requisitos de calidad

El código debe:

- estar formateado;
- pasar `terraform validate`;
- tener variables y outputs claros;
- evitar valores hardcoded salvo defaults seguros de demo;
- contener comentarios solo donde aporten contexto;
- no contener secretos;
- ser idempotente;
- ser destruible con Terraform.

Validaciones:

```bash
terraform fmt -check
terraform validate
terraform plan
```

Y después del despliegue:

```bash
./scripts/smoke-test.sh
```

---

## 34. Arquitectura final de referencia

```text
┌───────────────────────────────────────────────────────────┐
│                        HUMAN                             │
│                  "Build the login page"                   │
└────────────────────────────┬──────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────┐
│                  GitHub Copilot CLI                       │
│                                                           │
│                 Squad agent coordinator                   │
│                                                           │
│      ┌──────────┬──────────┬──────────┬──────────┐       │
│      │  Lead    │ Frontend │ Backend  │  Tester  │ ...   │
│      └──────────┴──────────┴──────────┴──────────┘       │
└────────────────────────────┬──────────────────────────────┘
                             │
                 OpenAI-compatible BYOK
                             │
                             ▼
┌───────────────────────────────────────────────────────────┐
│                AZURE API MANAGEMENT                      │
│                     AI GATEWAY                           │
│                                                           │
│  Agent Identity                                           │
│        │                                                  │
│        ├── llm-token-limit                                │
│        │                                                  │
│        ├── llm-emit-token-metric                         │
│        │                                                  │
│        ├── Observability                                 │
│        │                                                  │
│        ├── Cost attribution                              │
│        │                                                  │
│        ├── Backend pool                                  │
│        │                                                  │
│        ├── Circuit breaker                               │
│        │                                                  │
│        └── Managed Identity                              │
│                                                           │
└────────────────────────────┬──────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
        ┌────────────────────┐  ┌────────────────────┐
        │ Microsoft Foundry  │  │ Microsoft Foundry  │
        │ Primary Region     │  │ Secondary Region   │
        │                    │  │                    │
        │ Model Deployment A │  │ Model Deployment B │
        └────────────────────┘  └────────────────────┘
                    │                 │
                    └────────┬────────┘
                             ▼
                    Azure Monitor /
                    Application Insights
                             │
                             ▼
                Agent usage + cost dashboard
```

---

## 35. Decisión resumida

**Adoptar una arquitectura en la que:**

- Squad sea la capa de orquestación multi-agent.
- GitHub Copilot CLI sea el runtime de ejecución de Squad.
- Copilot CLI utilice un proveedor BYOK/OpenAI-compatible cuyo endpoint sea APIM.
- APIM sea el punto único de entrada hacia los modelos.
- Foundry proporcione deployments en dos regiones.
- APIM aplique límites de tokens por agente.
- APIM emita métricas de tokens asociadas al agente.
- El dashboard derive coste estimado por agente.
- APIM utilice Managed Identity para autenticarse frente a Foundry.
- APIM gestione primary/secondary y circuit breaker.
- Squad permanezca agnóstico respecto a regiones, límites y credenciales del backend.

La demo debe probar que **la complejidad de gobernanza se concentra en la plataforma y no se distribuye entre los prompts y agentes**.

---

## 36. Fuentes oficiales consultadas

[1] Squad — GitHub repository  
https://github.com/bradygaster/squad

[2] GitHub Docs — Use your own models in GitHub Copilot CLI  
https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models

[3] Microsoft Learn — Microsoft Foundry / OpenAI-compatible endpoints and authentication  
https://learn.microsoft.com/en-us/azure/foundry/

[4] Microsoft Learn — Azure API Management `llm-token-limit` policy  
https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy

[5] Microsoft Learn — Azure API Management `llm-emit-token-metric` policy  
https://learn.microsoft.com/en-us/azure/api-management/llm-emit-token-metric-policy

[6] Microsoft Learn — Azure API Management managed identity authentication  
https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy

[7] GitHub Docs — GitHub Copilot CLI command reference / provider configuration  
https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

[8] Microsoft Learn — Azure API Management backends, pools and circuit breaker  
https://learn.microsoft.com/en-us/azure/api-management/backends

---

## 37. Nota de revisión

Esta ADR está escrita para una **demo técnica reproducible**, no como una especificación de producción completa.

Las siguientes piezas deben validarse contra las versiones concretas fijadas en el repositorio antes de una ejecución pública:

- versión de Squad;
- versión de GitHub Copilot CLI;
- schema exacto de `providers.json` si se utiliza;
- forma exacta de propagación del `agent-id`;
- endpoint OpenAI-compatible concreto de Foundry;
- capacidades del deployment elegido;
- soporte Terraform de los recursos APIM/Foundry necesarios.

La implementación no debe compensar una incompatibilidad inventando APIs, argumentos Terraform o mecanismos de headers que no existan.

**Criterio de oro:** cada afirmación de capacidad incluida en el README de la demo debe poder demostrarse con una ejecución real.