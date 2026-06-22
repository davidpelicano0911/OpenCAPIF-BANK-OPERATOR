# Explicação detalhada do código — passo a passo

Guia completo dos 3 ficheiros da demo. Para cada função: **(1) o que faz em simples**,
**(2) linha a linha**, **(3) onde é chamada na UI**.

- [capif_flow.py](capif_flow.py) — a **lógica** (cliente que fala com o CAPIF)
- [app.py](app.py) — o **servidor web** (liga os botões às funções)
- [sim_swap_mock.py](../sim_swap_mock.py) — a **API real** da Operadora (o AEF)

---

## 0. Como tudo se liga (o circuito)

```
Browser (botão)  →  app.py (endpoint)  →  capif_flow.py (função)  →  CAPIF / Mock
       ↑                                          │
       └──────────  resposta JSON  ───────────────┘
```

**Mapa botão → endpoint → função:**

| Portal | Botão | Endpoint (app.py) | Função (capif_flow.py) |
|---|---|---|---|
| Operadora | 1 Register | `POST /api/op/register` | `op_register()` |
| Operadora | 2 Publish | `POST /api/op/publish` | `op_publish()` |
| Operadora | 3 Audit | `POST /api/op/audit` | `op_audit()` |
| Banco | 1 Register | `POST /api/bk/register` | `bk_register()` |
| Banco | 2 Discover | `POST /api/bk/discover` | `bk_discover()` |
| Banco | 3 Get token | `POST /api/bk/token` | `bk_token()` |
| Banco | Check | `POST /api/bk/check` | `bk_check(phone)` |
| (ambos) | barra de estado | `GET /api/state` | `snapshot()` |
| (ambos) | Reset system | `POST /api/reset` | recria `CapifFlow` + `reset_demo.sh` |

---

# PARTE A — capif_flow.py

## 1. Configuração no topo (linhas 13–61)

**Simples:** decide com que servidores falar e se valida os certificados.

```python
import os, socket, datetime, requests, urllib3, cryptography...
urllib3.disable_warnings()          # esconde avisos de TLS (modo localhost)
ADMIN = ("admin", "password123")    # user/pass do admin do Register
WORK_DIR = "/tmp/capif_demo"        # pasta onde se guardam chaves e certificados
CA_FILE = f"{WORK_DIR}/ca.crt"      # o certificado da Autoridade (CA)
```

```python
def _hosts_ok(*names):              # os nomes (capifcore/register) resolvem em DNS?
    try:
        for n in names: socket.gethostbyname(n)
        return True
    except Exception: return False
```
- Tenta traduzir cada nome para IP. Se conseguir → estamos num ambiente "a sério".

```python
_SECURE = _hosts_ok("capifcore", "register")
if _SECURE:  REGISTER="https://register:8084";  CAPIF="https://capifcore:443"
else:        REGISTER="https://localhost:8084";  CAPIF="https://localhost:443"
```
- **Modo SECURE:** usa os nomes reais e valida certificados (produção).
- **Modo localhost:** fallback para a demo correr sempre.

```python
def _verify():
    return CA_FILE if (_SECURE and os.path.exists(CA_FILE)) else False
```
- Decide o que passar ao `requests` em `verify=`: o caminho do `ca.crt` (valida) ou `False` (não valida).
- Devolve `False` enquanto o `ca.crt` ainda não existe (1º pedido = bootstrap).

```python
KNOWN_SWAP = "+351911111111"        # número que o mock marca como fraude
```

---

## 2. Funções auxiliares (linhas 64–100)

### `_gen_csr(name, cn)` — gerar chave privada + pedido de certificado
**Simples:** cria uma chave secreta (fica na máquina) e um "pedido de certificado" (CSR) para enviar ao CAPIF.

```python
def _gen_csr(name, cn):
    os.makedirs(WORK_DIR, exist_ok=True)                       # garante a pasta
    key = rsa.generate_private_key(... key_size=2048)          # 1) cria a CHAVE PRIVADA
    csr = (x509.CertificateSigningRequestBuilder()             # 2) cria o CSR
           .subject_name(x509.Name([ CN=cn, O="CAPIF System", C="PT" ]))
           .sign(key, hashes.SHA256()))                        #    assinado com a chave
    with open(f"{WORK_DIR}/{name}.key","wb") as f:             # 3) grava a chave em disco
        f.write(key.private_bytes(...))
    return csr.public_bytes(...).decode("utf-8")               # 4) devolve o CSR (texto PEM)
```
- **Conceito-chave:** a **chave privada NUNCA sai** da máquina. Só viaja o CSR (que tem a chave pública).
- `cn` (Common Name) = o papel: `apf`, `aef`, `amf`, `invoker`.
- **Chamada por:** `op_register` (3×) e `bk_register` (1×).

### `_save(name, content)` — gravar um ficheiro
```python
def _save(name, content):
    os.makedirs(WORK_DIR, exist_ok=True)
    with open(f"{WORK_DIR}/{name}","w") as f: f.write(content)
```
- Grava texto (um certificado, o `ca.crt`) em `/tmp/capif_demo`.

### `_cert(name)` — o par (certificado, chave) para mTLS
```python
def _cert(name):
    crt, key = f"{WORK_DIR}/{name}.crt", f"{WORK_DIR}/{name}.key"
    return (crt, key) if os.path.exists(crt) and os.path.exists(key) else None
```
- Devolve o tuplo que o `requests` espera em `cert=` para autenticar **por certificado (mTLS)**.
- Se faltar um ficheiro → `None`.

### `_log(actor, msg)` — imprimir o traço educativo no terminal
```python
def _log(actor, msg):
    if "->" in msg:                                            # se é um pedido a sair
        msg += "[VERIFY: ...]"  (validado vs ca.crt? ou off)
    print(f"  [{actor:8}] {msg}", flush=True)
```
- Só imprime no terminal do `app.py` quem faz o quê. Não afeta a lógica.

---

## 3. A classe `CapifFlow` — o estado partilhado

### `__init__` (104–110) — a "memória" da demo
```python
self.admin_token = None
self.apf_id = self.aef_id = self.amf_id = self.api_id = None
self.invoker_id = None
self.aef_url = None
self.token = None
```
- Guarda tudo o que vai sendo obtido. **É isto que liga os 2 portais** (há **um só** `CapifFlow` no servidor).

| Atributo | Guarda | Preenchido por |
|---|---|---|
| `admin_token` | JWT de admin | `_ensure_account` |
| `apf_id`/`aef_id`/`amf_id` | IDs das 3 funções da Operadora | `op_register` |
| `api_id` | ID da API publicada | `op_publish` / `bk_discover` |
| `invoker_id` | ID do Banco | `bk_register` |
| `aef_url` | URL real do endpoint | `bk_discover` |
| `token` | token OAuth2 | `bk_token` |

### `snapshot()` (112–127) — a barra de estado
**Simples:** devolve um resumo do estado para a barra no topo dos portais.
```python
return {"operator_registered": bool(self.apf_id),
        "api_published": bool(self.api_id),
        "invoker_registered": bool(self.invoker_id),
        "has_token": bool(self.token), ... ids ...}
```
- `bool(self.apf_id)` → `True` se já tem valor (acende a bolinha verde).
- **Chamado na UI por:** `GET /api/state` (polling de 4s em [portal.js](static/portal.js)).

### `_r(...)` (129–131) — empacotar a resposta para a UI
```python
return {"ok":..., "title":..., "summary":..., "calls":..., "data":..., "mongo":...}
```
- Formato único que o front-end sabe desenhar (cartão com título, resumo, chamadas HTTP, dados).

### `_call(...)` (133–134) — descrever uma chamada HTTP
```python
return {"label":..., "http":..., "ok":..., "detail":...}
```
- Uma linha "chamada feita" para a UI (a badge verde/vermelha com o código).

### `_ensure_account(username, password, **extra)` (136–149) — criar conta no Register
**Simples:** faz login de admin (se preciso) e cria a conta do ator.
```python
if not self.admin_token:                                   # ainda não há token de admin?
    r = requests.post(f"{REGISTER}/login", auth=ADMIN, ...) #   POST /login
    self.admin_token = r.json()["access_token"]            #   guarda o JWT de admin
h = {"Authorization": f"Bearer {self.admin_token}", ...}   # usa o JWT no cabeçalho
body = {"username":..., "password":...}; body.update(extra)# dados da conta
return requests.post(f"{REGISTER}/createUser", ...).status_code  # POST /createUser
```
- `**extra` = argumentos extra (enterprise, country, email...).
- **Chamado por:** `op_register` e `bk_register`.

### `_getauth(username, password)` (151–153) — login do ator
```python
return requests.get(f"{REGISTER}/getauth", auth=(username,password), ...)
```
- Faz login como Operadora/Banco; o Register devolve o **JWT** (e, para a Operadora, o **ca.crt**).

---

## 4. OPERADORA

### `op_register()` (156–212) — registar e obter os 3 certificados
**Simples:** cria a conta, faz login, gera 3 CSRs e o CAPIF devolve 3 certificados (APF/AEF/AMF).

Passo a passo:
```python
self.apf_id = self.aef_id = self.amf_id = self.api_id = None   # reset deste fluxo
self._ensure_account("operadora_5g", ...)                      # 1) conta no Register
r = self._getauth("operadora_5g", "Operadora123")              # 2) login -> JWT + ca_root
_save("ca.crt", auth["ca_root"])                               #    grava o CA (agora valida!)
token = auth["access_token"]                                   #    o JWT da Operadora
csrs = {role: _gen_csr(f"{role}_operadora_5g", role.lower())   # 3) 3 chaves + 3 CSRs
        for role in ("APF","AEF","AMF")}
body = {"regSec": token, "apiProvDomInfo":"Operator", ...,     # 4) monta o pedido
        "apiProvFuncs":[{ regInfo:{apiProvPubKey:csr}, role, info } ...]}
rr = requests.post(f"{CAPIF}/api-provider-management/v1/registrations", ...) # 5) POST
for func in rr.json()["apiProvFuncs"]:                         # 6) lê a resposta
    _save(f"{name}.crt", cert)                                 #    grava cada certificado
    if role=="APF": self.apf_id = ...                          #    guarda os 3 IDs
    if role=="AEF": self.aef_id = ...
    if role=="AMF": self.amf_id = ...
return self._r(True, "Register with CAPIF Core", ..., {ids...}) # 7) resposta p/ UI
```
- **Endpoint CAPIF:** `POST /registrations` (API Provider Management).
- **Resultado:** passa a autenticar por **mTLS** (certificado), sem password.
- **Chamado na UI por:** botão **1 Register** da Operadora → `POST /api/op/register`.

### `op_publish()` (214–245) — publicar a API SIM Swap
**Simples:** com o certificado **APF**, põe a API no catálogo do CAPIF.
```python
if not self.apf_id: return ... "Register first"               # guarda: tem de ter registado
body = {"apiName":"SIM_Swap", ...,                            # descreve a API:
        "aefProfiles":[{ aefId:self.aef_id, "OAUTH",          #   quem expõe + segurança
            interfaceDescriptions:[{ipv4Addr:"127.0.0.1", port:9200}],  # ONDE está
            versions:[{resources:[{uri:"/sim-swap/check", operations:["POST"]}]}]}]}
r = requests.post(f"{CAPIF}/published-apis/v1/{apf_id}/service-apis",
                  json=body, cert=_cert("APF_operadora_5g"), ...)   # mTLS com cert APF
self.api_id = r.json().get("apiId")                           # guarda o api_id
```
- **Endpoint CAPIF:** `POST /service-apis` (Publish Service).
- **Chamado na UI por:** botão **2 Publish** da Operadora → `POST /api/op/publish`.

### `op_audit()` (247–293) — auditar as invocações (AMF)
**Simples:** com o certificado **AMF**, lê do CAPIF os registos de quem chamou a API.
```python
cert = _cert("AMF_operadora_5g")
if not cert: return ... "Register first"                      # precisa do cert AMF
if not (self.aef_id and self.invoker_id): return ... "no invocations yet"
r = requests.get(f"{CAPIF}/logs/v1/apiInvocationLogs"         # GET Auditing API
                 f"?aef-id={aef_id}&api-invoker-id={invoker_id}", cert=cert, ...)
if r.status_code == 404:                                      # 404 = ainda não há logs
    return ... "No invocations logged yet" ... {logs:[]}      #   (mostra mensagem simpática)
logs = [ {apiName, operation, uri, result, invocationTime} for entry in r.json()["logs"] ]
return self._r(True, "Audit Invocations", ..., {logs})
```
- **Endpoint CAPIF:** `GET /logs/apiInvocationLogs` (Auditing API).
- **Chamado na UI por:** botão **3 Audit** da Operadora → `POST /api/op/audit`.

---

## 5. BANCO

### `bk_register()` (296–338) — registar o Banco como Invoker
**Simples:** igual ao registo da Operadora, mas 1 só certificado (papel `invoker`).
```python
self.invoker_id = self.token = self.aef_url = None            # reset
self._ensure_account("banco_itau", ...)                      # conta no Register
token = self._getauth("banco_itau","Itau123").json()["access_token"]  # JWT do Banco
csr = _gen_csr("banco_itau", "invoker")                      # 1 chave + 1 CSR
body = {"onboardingInformation":{"apiInvokerPublicKey":csr}, ...}
rr = requests.post(f"{CAPIF}/api-invoker-management/v1/onboardedInvokers", ...)
self.invoker_id = rr.json().get("apiInvokerId")             # guarda o invoker_id
_save("banco_itau.crt", cert)                                # grava o certificado
```
- **Endpoint CAPIF:** `POST /onboardedInvokers` (API Invoker Management).
- **Chamado na UI por:** botão **1 Register** do Banco → `POST /api/bk/register`.

### `bk_discover()` (340–374) — descobrir APIs no catálogo
**Simples:** o Banco pergunta ao CAPIF "que APIs existem?" e encontra a SIM_Swap.
```python
if not self.invoker_id: return ... "Register first"
r = requests.get(f"{CAPIF}/service-apis/v1/allServiceAPIs?api-invoker-id={invoker_id}",
                 cert=_cert("banco_itau"), ...)              # mTLS com cert do Banco
apis = r.json().get("serviceAPIDescriptions", [])
for api in apis:                                             # "escava" o JSON da API:
    for p in api["aefProfiles"]:
        self.aef_id = p.get("aefId")                         #   quem expõe
        for v in p["versions"]: for res in v["resources"]: for iface in p["interfaceDescriptions"]:
            host = iface["ipv4Addr"] or iface["fqdn"]; port = iface["port"]
            self.aef_url = f"http://{host}:{port}{...}{res['uri']}"  # URL REAL do endpoint
    self.api_id = api.get("apiId")                           #   qual API
```
- **Endpoint CAPIF:** `GET /allServiceAPIs` (Discover Service).
- Reconstrói o `aef_url` (ex.: `http://127.0.0.1:9200/sim-swap/check`) — guarda-o para o Check.
- **Chamado na UI por:** botão **2 Discover** do Banco → `POST /api/bk/discover`.

### `bk_token()` (376–405) — obter o token OAuth2
**Simples:** o Banco regista-se como "trusted" e pede o token que prova autorização.
```python
if not (invoker_id and aef_id and api_id): return ... "Run Discovery first"
# 1) tornar-se confiável para esta API
rs = requests.put(f"{CAPIF}/capif-security/v1/trustedInvokers/{invoker_id}",
                  json={securityInfo:[{aefId, apiId, "OAUTH"}]}, cert=_cert("banco_itau"))
# 2) pedir o token (scope identifica a API)
scope = f"3gpp#{aef_id}:SIM_Swap"
rt = requests.post(f"{CAPIF}/capif-security/v1/securities/{invoker_id}/token",
                   data={grant_type:"client_credentials", client_id:invoker_id, scope}, ...)
self.token = rt.json().get("access_token")                  # guarda o token
```
- **Endpoints CAPIF:** `PUT /trustedInvokers` + `POST /token` (Security API).
- **Chamado na UI por:** botão **3 Get token** do Banco → `POST /api/bk/token`.

### `bk_check(phone)` (407–437) — chamar a API real e decidir
**Simples:** com o token, chama a API da Operadora e decide aprovar/bloquear.
```python
if not (self.token and self.aef_url): return ... "Get token first"
r = requests.post(self.aef_url, json={"phoneNumber":phone, "maxAge":24},  # chama o MOCK :9200
                  headers={"Authorization": f"Bearer {self.token}"})       # com o token
d = r.json()
approve = not d.get("swapped")                              # sem swap -> aprova
calls = [self._call("POST /sim-swap/check", r.status_code, approve)]
log_call = self._log_invocation(r.status_code)             # >>> AEF regista a invocação <<<
if log_call: calls.append(log_call)
summary = "APPROVE" se approve senão "BLOCK (fraude)"
return self._r(True, "Fraud Check", summary, calls, {phone, swapped, decision})
```
- **Endpoint:** `POST /sim-swap/check` — **a tua API** (o mock), **não** o CAPIF.
- `try/except`: se o mock não responder, devolve mensagem amigável.
- **Chamado na UI por:** botão **Check** do Banco → `POST /api/bk/check` (com `{phone}`).

### `_log_invocation(result)` (439–467) — o AEF regista a chamada
**Simples:** depois do Check, o AEF escreve no CAPIF "esta chamada aconteceu".
```python
cert = _cert("AEF_operadora_5g")
if not (aef_id and invoker_id and cert): return None        # sem dados -> não regista
body = {"aefId", "apiInvokerId", "supportedFeatures":"0",    # << supportedFeatures obrigatório!
        "logs":[{apiId, apiName:"SIM_Swap", apiVersion, resourceName, uri,
                 protocol:"HTTP_1_1", operation:"POST", result:str(result),
                 invocationTime: agora em UTC}]}
try:
    rl = requests.post(f"{CAPIF}/api-invocation-logs/v1/{aef_id}/logs",
                       json=body, cert=cert, ...)            # POST Logging API (mTLS, cert AEF)
    return self._call("POST api-invocation-logs (AEF mTLS)", rl.status_code, ok)
except Exception: return None                                # falha de log NUNCA quebra o Check
```
- **Endpoint CAPIF:** `POST /api-invocation-logs` (Logging API).
- Tudo dentro de `try/except` porque um erro de log **não pode** estragar o fraud check.
- **Chamado por:** `bk_check` (não tem botão próprio).

---

# PARTE B — app.py (o servidor web)

**Simples:** um servidor HTTP minimalista (sem Flask) que serve as páginas e liga cada endpoint a uma função do `CapifFlow`.

```python
flow = CapifFlow()                       # UM único objeto partilhado (linha 29)

def do_GET(self):
    if path == "/api/state": self._json(200, flow.snapshot())   # a barra de estado
    if path in PAGES: serve o HTML                              # /, /operadora, /banco
    senão serve ficheiros estáticos (css/js)

def do_POST(self):
    if "/api/op/register": self._json(200, flow.op_register())  # cada botão -> uma função
    elif "/api/op/publish": flow.op_publish()
    elif "/api/op/audit":   flow.op_audit()
    elif "/api/bk/register": flow.bk_register()
    elif "/api/bk/discover": flow.bk_discover()
    elif "/api/bk/token":    flow.bk_token()
    elif "/api/bk/check":    flow.bk_check(phone)               # lê {phone} do corpo
    elif "/api/reset":       flow = CapifFlow(); corre reset_demo.sh
```
- **Ponto-chave:** como `flow` é **um só**, o que a Operadora faz fica visível ao Banco — é a ligação **através do CAPIF**.

---

# PARTE C — A interface (static/)

### `portal.js` — a cola do front-end
- `runAction(endpoint, body)` → faz `fetch` POST ao endpoint e devolve o JSON.
- `render(result)` → desenha o cartão (título, resumo, badges das `calls`, `data`, JSON colapsável).
  - trata `d.decision` (APPROVE/BLOCK), `d.apis` (discover), `d.logs` (audit), `d.certificates`, `d.token`.
- `wire(btnId, endpoint, onOk)` → liga um botão a um endpoint; `onOk` desbloqueia o passo seguinte.
- `refreshState()` → vai a `GET /api/state` e pinta a barra (bolinhas verde/cinza); corre a cada 4s.
- `resetAll()` → `POST /api/reset` e recarrega a página.

### `operadora.html` / `banco.html`
- Os botões usam `wire(...)`. Ex. (operadora):
  ```js
  wire("b-register", "/api/op/register", null, () => enable("b-publish"));
  wire("b-publish",  "/api/op/publish",  null, () => enable("b-audit"));
  wire("b-audit",    "/api/op/audit");
  ```
- O `<div id="state-bar">` é onde a barra de estado é desenhada.

---

# PARTE D — sim_swap_mock.py (a API real / AEF)

**Simples:** é o servidor da Operadora que responde "este número trocou de SIM?", e que **valida o token** antes de responder.

### Verificação do token (a parte de segurança)
```python
def _capif_public_key():                 # vai buscar a chave pública do CAPIF
    pem = ssl.get_server_certificate((host, 443))   # cert TLS servido em :443
    return x509.load_pem_x509_certificate(pem).public_key()   # (cacheado)

def verify_jwt_signature(token):
    header.payload.signature = token.split(".")
    pubkey.verify(signature, "header.payload", PKCS1v15(), SHA256())  # RS256
    return True / False / None            # ok / inválido / não deu para verificar
```

### `do_POST` — o controlo de acesso (em camadas)
```python
if not auth.startswith("Bearer "):   -> 401  # 1) sem token
claims = decode_jwt_payload(token)
if claims is None:                   -> 401  # 2) token ilegível
if verify_jwt_signature(token) is False: -> 401  # 2b) assinatura inválida (NOVO)
if API_NAME not in scope:            -> 403  # 3) token não autoriza esta API
# 4) tudo OK -> consulta SWAPS[phone] e responde swapped:true/false
```
- `SWAPS` é o "histórico" simulado: `+351911111111` = trocou (fraude), `+351912345678` = intacto.
- **Chamado por:** `bk_check` (via `self.aef_url`).

---

# Resumo do fluxo completo (uma linha cada)

1. **op_register** → 3 CSRs → CAPIF assina → 3 certificados (APF/AEF/AMF).
2. **op_publish** → [cert APF] publica a SIM_Swap no catálogo.
3. **bk_register** → 1 CSR → CAPIF assina → certificado do Banco.
4. **bk_discover** → [cert Banco] encontra a API + o `aef_url`.
5. **bk_token** → [cert Banco] recebe o token OAuth2.
6. **bk_check** → chama o mock com o token → APPROVE/BLOCK → **_log_invocation** (AEF regista).
7. **op_audit** → [cert AMF] lê os registos das invocações.
```
