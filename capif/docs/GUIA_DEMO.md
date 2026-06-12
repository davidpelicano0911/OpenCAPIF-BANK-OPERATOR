# Guia OpenCAPIF — Fluxo Completo, Demo e Testes

## O que é o OpenCAPIF

O **CAPIF (Common API Framework)** é o standard 3GPP (TS 29.222) que controla o acesso a APIs em redes 5G.
O **OpenCAPIF** é a implementação open-source da ETSI desse standard.

Funciona como um **porteiro de APIs para redes 5G**:
- Fornecedores (**Providers**) publicam APIs no catálogo
- Consumidores (**Invokers**) descobrem e acedem às APIs
- O CAPIF controla autenticação (mTLS + JWT + OAuth2), autorização, logs e políticas

---

## Arquitetura — o que está a correr

```
Tu (script Python / curl)
        │
        ▼
  Register (porta 8084)        ← balcão de login, cria contas e dá tokens JWT
        │
        ▼
  CAPIF Core — nginx (porta 443 HTTPS)
        │
   ┌────┴──────────────────────────────────────────────┐
   ▼           ▼            ▼          ▼         ▼     ▼
Publish     Invoker      Provider   Security   Events  Discover
Service     Mgmt         Mgmt       API        API     Service
   │
   └──────── todos falam com ──────────────┐
                                           ▼
                                    MongoDB (porta 8082)
                                    Redis  (cache/filas)
                                    Vault  (CA e certificados)
                                    mock_server (porta 9100)
```

**23 containers Docker no total:**
- 11 microserviços Flask (Python)
- nginx (proxy reverso + TLS)
- MongoDB + Mongo Express ×2 (CAPIF Core + Register)
- Redis, Vault, Celery, Register, Helper, Mock Server

---

## Como arrancar

### Limpeza total e arranque
```bash
cd ~/capif/services

# Apaga tudo (containers + volumes + dados)
./clean_capif_docker_services.sh -a

# Arranca todos os serviços (~2 min primeira vez, ~30s depois)
./run.sh

# Aguarda e reinicia o Register (SSL issue após arranque a frio)
sleep 30 && docker restart register && sleep 20
```

### Verificar que está tudo a correr
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
# Deve mostrar 23+ containers com status "Up"
```

### URLs úteis
| URL | O que é |
|---|---|
| https://localhost:443 | CAPIF Core (nginx) |
| https://localhost:8084 | Register (login / criar utilizadores) |
| http://localhost:8082 | MongoDB do CAPIF Core (Mongo Express) |
| http://localhost:8083 | MongoDB do Register (Mongo Express) |
| http://localhost:9100 | Mock Server (servidor de teste) |

---

## A demo Python — fluxo completo

### Passo 0 (IMPORTANTE) — Reset antes de cada demo

Cada vez que corres a demo, o Passo 4 **publica uma API nova** no catálogo (não
substitui a anterior). Se correres 3 vezes sem limpar, o Discovery mostra a SIM
Swap API **3 vezes**. Para a demo sair limpa, corre **antes** de apresentar:

```bash
cd ~/capif
./reset_demo.sh
```

Isto apaga só os dados das corridas anteriores (providers, APIs, invokers,
contextos de segurança) e os certificados em `/tmp/capif_demo`. **Não** apaga
containers nem utilizadores — por isso é rápido (1 segundo) e seguro de repetir.
Resultado: o Discovery passa a mostrar **exatamente 1** SIM Swap API.

> Alternativa (mais demorada): `cd services && ./clean_capif_docker_services.sh -a && ./run.sh`
> recria tudo do zero — só vale a pena se quiseres reiniciar o sistema inteiro.

### Correr (a ordem certa dos 2 terminais)
```bash
# Terminal 1 — arranca o servidor AEF da Operadora e DEIXA a correr
cd ~/capif
python3 sim_swap_mock.py

# Terminal 2 — limpa e corre a demo
cd ~/capif
./reset_demo.sh
python3 demo_capif.py
```

O script para em cada passo e espera que primas ENTER — tempo para mostrar o MongoDB.

---

### Passo 1 — Verificar o sistema

**O que faz:** Dois pings HTTP ao Register (porta 8084) e ao CAPIF Core (porta 443).

**O que ver:** Apenas terminal. Confirma que os 23 containers estão a responder.

**O que dizer:** *"O sistema é composto por 23 containers Docker — 11 microserviços Flask mais nginx, MongoDB, Redis e Vault."*

---

### Passo 2 — Criar utilizadores

**O que faz:**
1. Login como admin no Register → recebe JWT admin
2. Cria utilizador `operadora_5g` (o Provider — quem publica APIs)
3. Cria utilizador `banco_itau` (o Invoker — quem consome APIs)

**HTTP no terminal:**
```
POST /login           → 200 (token admin)
POST /createUser      → 201 ou 409 (se já existe)
POST /createUser      → 201 ou 409
```

**O que ver no browser — http://localhost:8083:**
- Base de dados: `capif_users`
- Collection: `user`
- Dois documentos: `operadora_5g` e `banco_itau`

**O que dizer:** *"O Register é o balcão de entrada — guarda as contas numa BD separada do CAPIF Core."*

---

### Passo 3 — Operadora regista-se como Provider

Este é o passo mais complexo. Acontecem 3 coisas distintas:

**3.1 — Operadora faz login no Register**
```
GET /getauth (com user/password da Operadora)
← JWT token + ca.crt (certificado raiz da CA do CAPIF)
```
O `ca.crt` é guardado em `/tmp/capif_demo/ca.crt` — é o certificado raiz que assina todos os outros.

**3.2 — Script gera chaves RSA localmente** (na tua máquina, nunca saem)
- `APF_operadora_5g.key` — chave privada do API Publishing Function
- `AEF_operadora_5g.key` — chave privada do API Exposing Function
- `AMF_operadora_5g.key` — chave privada do API Management Function
- 3 CSRs (Certificate Signing Requests) — contêm só a chave pública, pedido de assinatura

**3.3 — Envia JWT + 3 CSRs para o CAPIF Core**
```
POST /api-provider-management/v1/registrations
Body: { "regSec": JWT, "apiProvFuncs": [CSR_APF, CSR_AEF, CSR_AMF] }
← HTTP 201 + 3 certificados assinados + APF_ID + AEF_ID
```
O CAPIF Core:
- Valida o JWT
- Assina os 3 CSRs com a sua CA (Vault)
- Guarda o Provider na BD
- Devolve os certificados `.crt` + IDs únicos

**Ficheiros resultantes em `/tmp/capif_demo/`:**
```
ca.crt                 ← veio do Register (CA raiz do CAPIF)
APF_operadora_5g.key   ← gerado localmente (nunca saiu)
APF_operadora_5g.crt   ← veio do CAPIF (assinado pela CA)
AEF_operadora_5g.key   ← gerado localmente
AEF_operadora_5g.crt   ← veio do CAPIF
AMF_operadora_5g.key   ← gerado localmente
AMF_operadora_5g.crt   ← veio do CAPIF
```

**O que ver no browser — http://localhost:8082 → capif → providerenrolmentdetails:**
```json
{
  "api_prov_dom_info": "Operadora 5G Portugal",
  "username": "operadora_5g",
  "api_prov_funcs": [
    { "api_prov_func_role": "APF", "api_prov_func_id": "APFxxx...", "api_prov_cert": "-----BEGIN CERTIFICATE..." },
    { "api_prov_func_role": "AEF", "api_prov_func_id": "AEFxxx...", "api_prov_cert": "-----BEGIN CERTIFICATE..." },
    { "api_prov_func_role": "AMF", "api_prov_func_id": "AMFxxx...", "api_prov_cert": "-----BEGIN CERTIFICATE..." }
  ]
}
```

**O que dizer:** *"O CAPIF não usa passwords para autenticar a Operadora — usa certificados mTLS que ele próprio emite. A chave privada nunca sai do cliente."*

---

### Passo 4 — Operadora publica o SIM Swap API

**O que faz:** A Operadora diz ao CAPIF "tenho uma API chamada SIM Swap, está no endpoint `/sim-swap/check`".

**Autenticação:** mTLS — envia o `APF_operadora_5g.crt` + `.key` (não usa JWT aqui)

```
POST /published-apis/v1/{APF_ID}/service-apis
cert: APF_operadora_5g.crt + .key
Body: { "apiName": "SIM_Swap", "aefProfiles": [...], "supportedFeatures": "0" }
← HTTP 201 + api_id
```

**O que ver no browser — http://localhost:8082 → capif → serviceapidescriptions:**
```json
{
  "api_name": "SIM_Swap",
  "api_id": "f9c1b3...",
  "apf_id": "APF06699...",
  "description": "GSMA SIM Swap API...",
  "aef_profiles": [{
    "aef_id": "AEFc061...",
    "domain_name": "operadora5g.pt",
    "versions": [{ "api_version": "v1", "resources": [{ "uri": "/sim-swap/check", "operations": ["POST"] }] }],
    "security_methods": ["OAUTH"],
    "protocol": "HTTP_1_1"
  }]
}
```

**Nota importante:** Isto é apenas **metadata** (catálogo). O servidor real da SIM Swap API seria da Operadora, fora do CAPIF. O CAPIF guarda a "ficha" da API — onde está, como aceder, que segurança usa.

**O que dizer:** *"O CAPIF é o catálogo e o porteiro — não serve as APIs, controla quem as publica e quem acede."*

---

### Passo 5 — Banco Itaú regista-se e descobre a API

**5.1 — Onboarding do Invoker** (igual ao Passo 3 mas para o Banco)
```
GET /getauth (banco_itau / Itau123)
← JWT token

[gera banco_itau.key localmente]
[gera CSR]

POST /api-invoker-management/v1/onboardedInvokers
Body: { JWT + CSR + "supportedFeatures": "0" }
← HTTP 201 + banco_itau.crt + invoker_id
```

**5.2 — Discovery** (o Banco pergunta "que APIs existem?")
```
GET /service-apis/v1/allServiceAPIs?api-invoker-id={invoker_id}
cert: banco_itau.crt + .key
← HTTP 200 + lista de APIs disponíveis
```

**O que ver no browser — http://localhost:8082 → capif → invokerdetails:**
```json
{
  "api_invoker_id": "INV1d4e1bc...",
  "api_invoker_information": "Banco Itaú...",
  "username": "banco_itau",
  "onboarding_information": { "api_invoker_certificate": "-----BEGIN CERTIFICATE..." }
}
```

**O que dizer:** *"O Banco descobriu a SIM Swap API sem conhecer a Operadora — foi ao catálogo CAPIF e encontrou-a. É como pesquisar na App Store."*

---

### Passo 6 — Token OAuth2 e chamada real à API

Este é o passo que mostra o **controlo de acesso real**.

> **Pré-requisito:** antes de chegar ao Passo 6, arranca o servidor AEF noutro terminal:
> ```bash
> cd ~/capif && python3 sim_swap_mock.py
> ```
> Este `sim_swap_mock.py` representa o servidor real da Operadora (o AEF). Usa só
> a biblioteca padrão do Python — não precisa de instalar nada.

> **Nota de arquitectura (importante para o professor):** o OpenCAPIF community/ETSI
> implementa apenas o **plano de gestão** — onboarding, discovery, emissão de tokens.
> **Não faz proxy de tráfego** como a spec 3GPP completa preveria. Por isso o Invoker
> chama o AEF **diretamente** no URL que o Discovery devolveu, e é o **AEF que valida
> o token** OAuth2 emitido pelo CAPIF. É exactamente isto que o mock faz.

**6.1 — Criar contexto de segurança**
```
PUT /capif-security/v1/trustedInvokers/{invoker_id}
cert: banco_itau.crt + .key
Body: { "securityInfo": [{ "aefId": AEF_ID, "apiId": api_id, "prefSecurityMethods": ["OAUTH"] }] }
← HTTP 201
```
O CAPIF regista: "o Banco quer aceder à SIM Swap API via OAuth2".

**6.2 — Pedir token OAuth2**
```
POST /capif-security/v1/securities/{invoker_id}/token
cert: banco_itau.crt + .key
Content-Type: application/x-www-form-urlencoded
Body: grant_type=client_credentials&client_id={invoker_id}&scope=3gpp#{AEF_ID}:SIM_Swap
← HTTP 200 + { "access_token": "eyJ...", "token_type": "Bearer" }
```
O token é um **JWT assinado pelo CAPIF** — prova que o Banco tem autorização para chamar a SIM Swap API.

**Formato do scope:** `3gpp#{aef_id}:{api_name}` — identifica exactamente qual API e em qual AEF.

**6.3 — Chamar a API com o token** (no URL que o Discovery devolveu)
```
POST http://127.0.0.1:9200/sim-swap/check
Authorization: Bearer eyJ...
Body: { "phoneNumber": "+351912345678", "maxAge": 24 }
← HTTP 200 { "swapped": false, "detail": "Nenhuma troca de SIM detetada..." }
```
O AEF descodifica o token, verifica que o scope contém `SIM_Swap` e autoriza.

**6.4 — Chamar SEM token → bloqueado**
```
POST http://127.0.0.1:9200/sim-swap/check   (sem header Authorization)
← HTTP 401 { "error": "unauthorized" }
```
Esta é a prova do controlo de acesso: sem o token OAuth2 do CAPIF, o AEF rejeita.

**O que ver no browser — http://localhost:8082 → capif → serviceapisecurity:**
O contexto de segurança criado pelo Banco para a SIM Swap API.

**O que dizer:** *"Três camadas de segurança: JWT para login, mTLS para registo, OAuth2 para cada chamada à API. Com token → 200. Sem token → 401. O AEF valida o token que o CAPIF emitiu."*

---

## Resumo do que fica em cada BD

| Momento | BD | Collection | O que aparece |
|---|---|---|---|
| Passo 2 | http://localhost:8083 `capif_users` | `user` | `operadora_5g` + `banco_itau` |
| Passo 3 | http://localhost:8082 `capif` | `providerenrolmentdetails` | Operadora + certificados APF/AEF/AMF |
| Passo 4 | http://localhost:8082 `capif` | `serviceapidescriptions` | SIM Swap API com endpoint e segurança |
| Passo 5 | http://localhost:8082 `capif` | `invokerdetails` | Banco Itaú + certificado |
| Passo 6 | http://localhost:8082 `capif` | `serviceapisecurity` | Contexto OAuth2 do Banco para a SIM Swap |

---

## Ficheiros gerados pela demo

Ficam em `/tmp/capif_demo/` — apagados ao reiniciar o sistema:

```
ca.crt                    ← CA raiz do CAPIF (serve para verificar todos os certs)
APF_operadora_5g.key      ← chave privada APF (gerada localmente)
APF_operadora_5g.crt      ← certificado APF (assinado pelo CAPIF)
AEF_operadora_5g.key      ← chave privada AEF (gerada localmente)
AEF_operadora_5g.crt      ← certificado AEF (assinado pelo CAPIF)
AMF_operadora_5g.key      ← chave privada AMF (gerada localmente)
AMF_operadora_5g.crt      ← certificado AMF (assinado pelo CAPIF)
banco_itau.key            ← chave privada do Invoker (gerada localmente)
banco_itau.crt            ← certificado do Invoker (assinado pelo CAPIF)
```

---

## Testar manualmente com curl

### Login como admin
```bash
curl -k -X POST https://localhost:8084/login -u "admin:password123"
# Guarda o access_token
TOKEN="eyJ..."
```

### Criar utilizador
```bash
curl -k -X POST https://localhost:8084/createUser \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"nokia","password":"Nokia123","enterprise":"Nokia","country":"PT","email":"test@nokia.com","purpose":"Provider"}'
```

### Ver APIs publicadas no catálogo (requer cert do Invoker)
```bash
curl -k \
  --cert /tmp/capif_demo/banco_itau.crt \
  --key /tmp/capif_demo/banco_itau.key \
  "https://localhost:443/service-apis/v1/allServiceAPIs?api-invoker-id=INV_ID_AQUI"
```

### Ver logs em tempo real
```bash
docker logs services-capif-security-1 --follow --tail 30
docker logs services-published-apis-1 --follow --tail 30
docker logs services-nginx-1 --follow --tail 30
```

---

## Testes automatizados (Robot Framework)

### Pré-requisito: criar utilizador de teste
```bash
cd ~/capif/services
./create_users.sh -u testuser -p TestPass123
```

### Correr todos os 167 testes
```bash
ulimit -n 65536 && ./run_capif_tests.sh --include all
```

### Correr uma suite específica
```bash
# Segurança OAuth2 (28 testes)
ulimit -n 65536 && ./run_capif_tests.sh --suite "CAPIF Security*"

# Publicação de APIs (16 testes)
ulimit -n 65536 && ./run_capif_tests.sh --suite "CAPIF Api Publish*"

# Mais rápidos (smoke tests)
ulimit -n 65536 && ./run_capif_tests.sh --include smoke
```

### Ver o relatório
```bash
xdg-open ~/capif/results/$(ls ~/capif/results/ | tail -1)/report.html
```

### Suites e o que testam
| Suite | Testes | O que valida |
|---|---|---|
| CAPIF Security Api | 28 | Tokens OAuth2, certificados mTLS, autorização |
| CAPIF Api Publish Service | 16 | Publicar, actualizar, apagar APIs |
| CAPIF Api Events | 20 | Subscrições de notificações (webhooks) |
| Api Status | 20 | Monitorização de estado das APIs |
| CAPIF Api Access Control Policy | 13 | Regras de quem acede a quê |
| CAPIF Api Invoker Management | 9 | Registo de consumidores |
| CAPIF Api Provider Management | 9 | Registo de fornecedores |
| Vendor Extensibility | 9 | Campos customizados por fabricante |
| CAPIF Api Discover Service | 6 | Pesquisa de APIs |
| CAPIF Api Logging Service | 5 | Logs de invocação |
| CAPIF Api Auditing Service | 5 | Auditoria e histórico |
| **TOTAL** | **167** | |

---

## Adaptações feitas para correr localmente

O projecto original usa o registry privado da ETSI (`labs.etsi.org:5050`) inacessível sem VPN.

| Ficheiro | Alteração | Motivo |
|---|---|---|
| 13 Dockerfiles de serviços | `labs.etsi.org/.../python` → `python:3-slim-bullseye` | Imagem pública equivalente |
| `nginx/Dockerfile` | `labs.etsi.org/.../nginx-ocf-patched` → `nginx:1.27.1` | Imagem pública |
| `nginx/nginx.conf` | Comentado `$sslkeylog_mk` | Módulo TLS customizado inexistente no nginx público |
| 3 scripts `.sh` | `docker images\|grep` → `docker image inspect` | Correcção de bug no grep com URLs longas |

---

## A vulnerabilidade corrigida (branch staging)

### O que era o problema

No branch anterior, vários microserviços tinham um padrão **fail-open** na validação de utilizadores:

```python
# CÓDIGO VULNERÁVEL (antes da correcção)
def validar_utilizador(cert):
    try:
        resultado = verificar_certificado(cert)
        if resultado["valido"]:
            return True
    except Exception:
        pass  # ← se a verificação falhar, deixa passar!
    return True  # ← fail-open: sempre retorna True
```

**Consequência:** se o serviço de validação estivesse em baixo ou respondesse com erro, **qualquer pedido era aceite** sem autenticação. Um atacante podia publicar APIs ou aceder ao catálogo sem credenciais.

### Como foi corrigido

```python
# CÓDIGO CORRIGIDO (no branch staging)
def validar_utilizador(cert):
    try:
        resultado = verificar_certificado(cert)
        return resultado["valido"]
    except Exception:
        return False  # ← fail-closed: em caso de dúvida, rejeita
```

### Serviços corrigidos
- API Publish Service
- API Events
- API Discover Service
- API Invoker Management
- API Provider Management
- API Security

### Como demonstrar ao professor
```bash
# Ver os commits de correcção
git log --oneline | grep "fail-open\|authorization-bypass"

# Ver a diferença no código
git show 1cb917a --stat
git show 878d51a --stat
```

---

## O que fazer durante o próximo mês

### Semana 1 — consolidar
- Demo Python a correr limpa do início ao fim
- Perceber cada pedido HTTP e o que o CAPIF faz
- Preparar diagrama do fluxo (Provider → Publish → Invoker → Discover → Token → Call)

### Semana 2 — atacar o sistema
- Tentar chamar APIs sem token → ver HTTP 401
- Tentar registar Provider com certificado inválido → ver rejeição
- Mostrar o diff da vulnerabilidade corrigida (antes/depois)
- Testar com certificado expirado

### Semana 3 — features avançadas
- **Events API:** subscrever a eventos (`SERVICE_API_AVAILABLE`, `API_INVOKER_ONBOARDED`)
- **Logging API:** ver logs de cada chamada à SIM Swap API
- **Access Control Policy:** criar regra "só IPs do Brasil acedem à SIM Swap"

### Semana 4 — apresentação
- Script demo limpo e sem erros
- Slides com o diagrama de fluxo
- Correr ao vivo mostrando MongoDB a crescer passo a passo

---

## Pontos-chave para o professor

1. **Standard real:** TS 29.222 (3GPP Rel-17) — o que as operadoras reais implementam
2. **Três camadas de segurança:** JWT (login) → mTLS (registo com certificados) → OAuth2 (cada chamada à API)
3. **Adaptação do ambiente:** 14 ficheiros modificados para correr fora da infraestrutura ETSI
4. **Vulnerabilidade corrigida:** fail-open pattern em 6 microserviços (branch `staging`, commits `OCF193`)
5. **167 testes a passar:** Robot Framework, cobre todo o protocolo CAPIF
6. **Demo ao vivo:** fluxo completo Operadora → Publicar → Banco → Descobrir → Token → Chamar
