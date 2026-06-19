# Explicação completa — `capif_flow.py`

Guia passo-a-passo do ficheiro [capif_flow.py](capif_flow.py), pensado para quem está a começar.
Explica **o que é o CAPIF**, **a história da demo**, e depois o código **linha a linha, função a função**.

---

## 1. A ideia em 30 segundos

Esta demo simula uma situação real:

- Um **Banco** vai aprovar uma transferência. Mas e se o cartão SIM do cliente foi
  clonado/trocado há pouco tempo (fraude "SIM swap")? O banco quer perguntar à
  **Operadora** móvel: *"este número teve uma troca de SIM recente?"*
- O Banco e a Operadora **não se conhecem diretamente**. No meio está o **CAPIF**
  (*Common API Framework*, normalizado pela 3GPP/GSMA) — uma espécie de **"mercado/catálogo
  de APIs"** seguro onde:
  - a Operadora **publica** a sua API (SIM Swap),
  - o Banco **descobre** essa API e **obtém autorização** para a usar,
  - tudo com **certificados (mTLS)** e **tokens OAuth2**, sem trocar passwords.

> Analogia: o CAPIF é como uma **App Store de APIs**. A Operadora "publica a app",
> o Banco "descarrega a app" e recebe uma "chave" (token) para a usar. Nunca precisam
> de combinar nada por telefone entre si.

### Os intervenientes

| Ator | Papel no CAPIF | O que faz |
|------|----------------|-----------|
| **Operadora** | *Provider* (APF/AEF/AMF) | Regista-se e **publica** a API SIM Swap |
| **Banco** | *Invoker* (consumidor) | **Descobre** a API, pede **token** e **chama** a API |
| **CAPIF Core** (`:443`) | O "mercado" central | Guarda o catálogo, valida, emite tokens |
| **Register** (`:8084`) | Serviço de registo/contas | Cria contas, dá JWTs e o certificado CA raiz |
| **Vault** | Autoridade Certificadora | Assina os certificados (chamado através do Core) |
| **Mock `:9200`** | API real da Operadora (falsa) | Responde ao "este número trocou de SIM?" |

### Os papéis do Provider (a Operadora gera 3)
- **APF** = *API Publishing Function* → o que **publica** APIs no catálogo.
- **AEF** = *API Exposing Function* → o que **expõe/serve** a API ao consumidor.
- **AMF** = *API Management Function* → gestão/monitorização.

---

## 2. Onde encaixa este ficheiro

- [app.py](app.py) é o **servidor web** com dois portais (`/operadora` e `/banco`).
  Cada botão na página chama um endpoint, e cada endpoint chama **um método** deste ficheiro:

  | Botão / Endpoint | Método chamado |
  |---|---|
  | Operadora → "Registar" | `flow.op_register()` |
  | Operadora → "Publicar API" | `flow.op_publish()` |
  | Banco → "Registar" | `flow.bk_register()` |
  | Banco → "Descobrir" | `flow.bk_discover()` |
  | Banco → "Obter token" | `flow.bk_token()` |
  | Banco → "Verificar fraude" | `flow.bk_check(phone)` |

- **Ponto-chave:** existe **um único objeto** `flow = CapifFlow()` partilhado no servidor
  ([app.py:29](app.py#L29)). É por isso que o que a Operadora faz (publicar a API) fica
  "visível" para o Banco — tal como na vida real eles comunicam **através do CAPIF**, não
  diretamente.

---

## 3. Por onde começar a ler (ordem recomendada)

1. **Topo do ficheiro** → imports, constantes e configuração SECURE/localhost.
2. As **funções auxiliares** (começam por `_`): `_hosts_ok`, `_verify`, `_gen_csr`,
   `_save`, `_cert`, `_log`. São "ferramentas" pequenas usadas por todo o lado.
3. A **classe `CapifFlow`** e o `__init__` (o "estado" que é guardado).
4. Os métodos auxiliares da classe: `_r`, `_call`, `_ensure_account`, `_getauth`.
5. **O fluxo principal, pela ordem em que acontece na demo:**
   `op_register` → `op_publish` → `bk_register` → `bk_discover` → `bk_token` → `bk_check`.

Lê na ordem do ponto 5 que segues a "história" naturalmente.

---

## 4. Topo do ficheiro — linha a linha

```python
#!/usr/bin/env python3
```
**Shebang**: permite correr o ficheiro diretamente (`./capif_flow.py`) usando o Python 3
do sistema. (Aqui o ficheiro é normalmente importado por `app.py`, não corrido sozinho.)

```python
import os        # mexer em ficheiros/pastas e variáveis de ambiente
import socket    # resolver nomes de host (DNS) — usado em _hosts_ok
import requests  # fazer pedidos HTTP/HTTPS (a biblioteca estrela aqui)
import urllib3   # controla avisos de TLS
from cryptography...  # gerar chaves RSA e CSRs (pedidos de certificado)
```
A biblioteca `cryptography` é usada para criar **chaves privadas** e **CSRs**
(*Certificate Signing Requests* — "pedidos de certificado").

```python
urllib3.disable_warnings()
```
Desliga os avisos do tipo *"InsecureRequestWarning"* que apareceriam quando falamos
com HTTPS sem validar o certificado (acontece no modo localhost). Só limpa o output.

```python
ADMIN = ("admin", "password123")
WORK_DIR = "/tmp/capif_demo"
CA_FILE = f"{WORK_DIR}/ca.crt"
```
- `ADMIN`: utilizador/password do administrador do serviço Register (para criar contas).
- `WORK_DIR`: pasta temporária onde se guardam chaves, certificados e o CA.
- `CA_FILE`: caminho do certificado **CA raiz** (a "autoridade" em quem confiamos).

### `_hosts_ok(*names)`
```python
def _hosts_ok(*names):
    try:
        for n in names:
            socket.gethostbyname(n)   # tenta resolver o nome -> IP
        return True
    except Exception:
        return False
```
Verifica se os nomes (`capifcore`, `register`) **resolvem em DNS / /etc/hosts**.
Se resolverem, estamos num ambiente "a sério" e podemos validar certificados.
`*names` significa "aceita vários argumentos". Se **algum** falhar, devolve `False`.

### Escolha do modo SECURE vs localhost
```python
_SECURE = _hosts_ok("capifcore", "register")
if _SECURE:
    REGISTER = "https://register:8084"
    CAPIF = "https://capifcore:443"
else:
    REGISTER = "https://localhost:8084"
    CAPIF = "https://localhost:443"
```
- **Modo SECURE**: os hostnames existem → usamos os nomes reais e **validamos** o
  certificado do servidor contra o CA (como em produção).
- **Modo localhost**: fallback para a demo correr sempre, mesmo sem `/etc/hosts`
  configurado → falamos com `localhost` **sem validar** o certificado.

`REGISTER` e `CAPIF` são as **URLs base** dos dois serviços.

### `_verify()`
```python
def _verify():
    return CA_FILE if (_SECURE and os.path.exists(CA_FILE)) else False
```
Decide **o que passar ao `requests` no parâmetro `verify=`**:
- devolve o **caminho do `ca.crt`** → o `requests` **valida** o certificado do servidor;
- devolve `False` → o `requests` **não valida** (modo demo/bootstrap).

> Detalhe importante: mesmo em modo SECURE, no **primeiro** pedido ainda não temos o
> `ca.crt` (só o recebemos depois). Por isso a condição também testa
> `os.path.exists(CA_FILE)`.

```python
print(f"  [capif_flow] mode: ...", flush=True)
```
Imprime no arranque se está em modo SECURE ou localhost. `flush=True` força a aparecer
já no terminal (sem ficar em buffer).

```python
KNOWN_SWAP = "+351911111111"   # número com SIM swap recente
```
Número "conhecido" que o mock devolve como **fraudulento** (teve troca de SIM).
Útil para testar o caminho "BLOCK".

---

## 5. Funções auxiliares de ficheiros/certificados

### `_gen_csr(name, cn)` — gerar chave privada + CSR
```python
def _gen_csr(name, cn):
    os.makedirs(WORK_DIR, exist_ok=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([
               x509.NameAttribute(NameOID.COMMON_NAME, cn),
               x509.NameAttribute(NameOID.ORGANIZATION_NAME, "CAPIF System"),
               x509.NameAttribute(NameOID.COUNTRY_NAME, "PT")]))
           .sign(key, hashes.SHA256()))
    with open(f"{WORK_DIR}/{name}.key", "wb") as f:
        f.write(key.private_bytes(...))   # grava a chave PRIVADA em disco
    return csr.public_bytes(serialization.Encoding.PEM).decode("utf-8")
```
Passo a passo:
1. Garante que a pasta de trabalho existe (`exist_ok=True` = não dá erro se já existir).
2. Cria uma **chave privada RSA** de 2048 bits.
3. Constrói um **CSR** — um pedido onde dizemos "quero um certificado para este sujeito"
   (`CN` = *Common Name*, organização, país) e **assinamos com a nossa chave privada**.
4. Grava a **chave privada** em `{name}.key`.
5. Devolve o **CSR em texto PEM** para enviar ao CAPIF.

> **Conceito-chave de segurança:** a **chave privada NUNCA sai da máquina**. Só enviamos
> o CSR (que contém a chave **pública**). O CAPIF/Vault assina e devolve um **certificado**.
> `CN` (Common Name) identifica o papel: `apf`, `aef`, `amf`, `invoker`.

### `_save(name, content)`
```python
def _save(name, content):
    os.makedirs(WORK_DIR, exist_ok=True)
    with open(f"{WORK_DIR}/{name}", "w") as f:
        f.write(content)
```
Grava texto (um certificado, o CA, etc.) num ficheiro dentro de `WORK_DIR`.

### `_cert(name)` — par (certificado, chave) para mTLS
```python
def _cert(name):
    crt, key = f"{WORK_DIR}/{name}.crt", f"{WORK_DIR}/{name}.key"
    return (crt, key) if os.path.exists(crt) and os.path.exists(key) else None
```
Devolve o **tuplo `(.crt, .key)`** que o `requests` espera no parâmetro `cert=` para
fazer **mTLS** (autenticação mútua por certificado). Se faltar algum ficheiro, devolve
`None`. É assim que o cliente "se identifica com o certificado em vez de password".

### `_log(actor, msg)` — traço educativo no terminal
```python
def _log(actor, msg):
    if "->" in msg:
        msg += ("   [VERIFY: server validated vs ca.crt]" if _verify()
                else "   [VERIFY: off (verify=False)]")
    print(f"  [{actor:8}] {msg}", flush=True)
```
Só serve para **imprimir no terminal** quem faz o quê. Se a mensagem tem `->`
(é um pedido a sair), acrescenta se o certificado do servidor está a ser validado ou não.
`{actor:8}` alinha o nome do ator em 8 colunas (fica bonito no log).

---

## 6. A classe `CapifFlow`

### `__init__` — o estado partilhado
```python
def __init__(self):
    os.makedirs(WORK_DIR, exist_ok=True)
    self.admin_token = None
    self.apf_id = self.aef_id = self.api_id = None
    self.invoker_id = None
    self.aef_url = None
    self.token = None
```
Guarda tudo o que vai sendo obtido ao longo do fluxo. **É a "memória" que liga os passos:**

| Atributo | O que guarda | Quem o preenche |
|---|---|---|
| `admin_token` | JWT de administrador | `_ensure_account` |
| `apf_id` | ID da função APF da Operadora | `op_register` |
| `aef_id` | ID da função AEF (quem expõe a API) | `op_register` / `bk_discover` |
| `api_id` | ID da API publicada | `op_publish` / `bk_discover` |
| `invoker_id` | ID do Banco como invoker | `bk_register` |
| `aef_url` | URL real do endpoint da API | `bk_discover` |
| `token` | Token OAuth2 para chamar a API | `bk_token` |

### `_r(...)` — empacotar a resposta
```python
def _r(self, ok, title, summary, calls=None, data=None, mongo=None):
    return {"ok": ok, "title": title, "summary": summary,
            "calls": calls or [], "data": data or {}, "mongo": mongo}
```
Cria o **dicionário de resposta** padronizado que vai para o front-end (JSON):
- `ok`: correu bem? (True/False)
- `title`: título do passo,
- `summary`: explicação para mostrar ao utilizador,
- `calls`: lista de chamadas HTTP feitas (para mostrar na UI),
- `data`: dados úteis (ids, certificados...),
- `mongo`: dica de onde ver isto na base de dados do CAPIF.

`calls or []` significa "usa `calls`, mas se for `None`, usa lista vazia".

### `_call(...)` — descrever uma chamada HTTP
```python
def _call(self, label, http, ok, detail=""):
    return {"label": label, "http": http, "ok": ok, "detail": detail}
```
Só formata **uma linha** de "chamada feita" para a UI: rótulo, código HTTP, sucesso, detalhe.

### `_ensure_account(username, password, **extra)` — garantir a conta no Register
```python
def _ensure_account(self, username, password, **extra):
    if not self.admin_token:                       # ainda não temos token de admin?
        r = requests.post(f"{REGISTER}/login", auth=ADMIN, verify=_verify(), timeout=10)
        if r.status_code == 200:
            self.admin_token = r.json()["access_token"]
    h = {"Authorization": f"Bearer {self.admin_token}",
         "Content-Type": "application/json"}
    body = {"username": username, "password": password}
    body.update(extra)                              # junta enterprise/country/email/...
    return requests.post(f"{REGISTER}/createUser", headers=h, verify=_verify(),
                         json=body).status_code
```
1. Se ainda não há `admin_token`, faz **login de admin** (`POST /login`) e guarda o JWT.
2. Usa esse JWT no cabeçalho `Authorization: Bearer ...`.
3. Cria a conta (`POST /createUser`) com username/password e dados extra
   (`**extra` recolhe argumentos nomeados: `enterprise=...`, `country=...`, etc.).
4. Devolve o código HTTP.

> O JWT (*JSON Web Token*) é um "crachá temporário". `Bearer` significa "quem porta este
> token tem acesso".

### `_getauth(username, password)`
```python
def _getauth(self, username, password):
    return requests.get(f"{REGISTER}/getauth", auth=(username, password),
                        verify=_verify(), timeout=10)
```
Faz login como **o ator** (operadora ou banco) e o Register devolve:
- `access_token` (JWT do ator) e, para a operadora, também `ca_root` (o **CA raiz**).
`auth=(user, pass)` envia HTTP Basic Auth. Devolve a **resposta inteira** (o chamador lê o JSON).

---

## 7. Fluxo da OPERADORA

### `op_register()` — registar a Operadora no CAPIF e obter certificados
```python
def op_register(self):
    calls = []
    self.apf_id = self.aef_id = self.api_id = None       # reset deste fluxo
    self._ensure_account("operadora_5g", "Operadora123", enterprise="Operator", ...)
    calls.append(self._call("Create account in Register", 200, True))
    r = self._getauth("operadora_5g", "Operadora123")    # login como operadora
    if r.status_code != 200:
        return self._r(False, ..., "Authentication failed.", ...)
    auth = r.json()
    _save("ca.crt", auth["ca_root"])                     # GUARDA o CA raiz!
    token = auth["access_token"]                          # JWT da operadora
    ...
    csrs = {role: _gen_csr(f"{role}_operadora_5g", role.lower())
            for role in ("APF", "AEF", "AMF")}           # 3 chaves + 3 CSRs
    body = {"regSec": token, "apiProvDomInfo": "Operator", "suppFeat": "0",
            "apiProvFuncs": [{"regInfo": {"apiProvPubKey": csrs[r_]},
                "apiProvFuncRole": r_, "apiProvFuncInfo": f"{r_}_operadora_5g"}
                for r_ in csrs]}
    rr = requests.post(f"{CAPIF}/api-provider-management/v1/registrations",
                       json=body, headers={"Authorization": f"Bearer {token}"}, ...)
    if rr.status_code != 201:
        return self._r(False, ..., f"CAPIF rejected ({rr.status_code}).", ...)
    certs = []
    for func in rr.json().get("apiProvFuncs", []):
        role = func.get("apiProvFuncRole")
        name = func.get("apiProvFuncInfo", role)
        cert = func.get("regInfo", {}).get("apiProvCert", "")
        if cert:
            _save(f"{name}.crt", cert)                    # grava cada certificado
            certs.append(role)
        if role == "APF": self.apf_id = func.get("apiProvFuncId")
        if role == "AEF": self.aef_id = func.get("apiProvFuncId")
    return self._r(True, ..., calls, {"certificates": certs, "apf_id": ..., "aef_id": ...},
                   "capif > providerenrolmentdetails")
```
**O que acontece, por ordem:**
1. Reset dos ids deste fluxo (para poder correr de novo limpo).
2. Garante a conta `operadora_5g` no Register.
3. Faz login → recebe **JWT da operadora** + **`ca_root`** (que é gravado como `ca.crt`).
   👉 A partir daqui, em modo SECURE, já podemos **validar** o servidor.
4. Gera **3 chaves privadas + 3 CSRs** (APF, AEF, AMF) — *dict comprehension*.
5. Monta o `body` da API de registo de provider, com `regSec=token` e os 3 CSRs.
6. `POST /api-provider-management/v1/registrations` → CAPIF Core.
7. Se sucesso (`201`), percorre a resposta e **grava cada certificado assinado** em disco,
   guardando `apf_id` e `aef_id` (precisamos deles a seguir).
8. Devolve resultado para a UI.

> Resultado: a Operadora deixa de usar password e passa a autenticar-se com **certificado (mTLS)**.

### `op_publish()` — publicar a API SIM Swap
```python
def op_publish(self):
    if not self.apf_id:
        return self._r(False, "Publish API", "Register with CAPIF Core first.")
    body = {"apiName": "SIM_Swap", ...,
            "aefProfiles": [{"aefId": self.aef_id, "protocol": "HTTP_1_1",
                "securityMethods": ["OAUTH"],
                "interfaceDescriptions": [{"ipv4Addr": "127.0.0.1", "port": 9200, ...}],
                "versions": [{"apiVersion": "v1", "resources": [{
                    "resourceName": "checkSimSwap", "uri": "/sim-swap/check",
                    "operations": ["POST"], ...}]}]}]}
    r = requests.post(f"{CAPIF}/published-apis/v1/{self.apf_id}/service-apis",
                      json=body, cert=_cert("APF_operadora_5g"), verify=_verify(), ...)
    if r.status_code != 201:
        return self._r(False, "Publish API", f"rejected ({r.status_code}).", ...)
    self.api_id = r.json().get("apiId")
    return self._r(True, "Publish API", ..., {"api_id": self.api_id, ...},
                   "capif > serviceapidescriptions")
```
**Pontos a reter:**
- **Guarda** (`if not self.apf_id`): não dá para publicar sem ter registado antes.
- O `body` descreve a API: nome (`SIM_Swap`), categoria, e o **perfil AEF** que diz
  **onde está o endpoint real** (`127.0.0.1:9200/sim-swap/check`) e que usa **OAUTH**.
- A chamada usa `cert=_cert("APF_operadora_5g")` → **autenticação por certificado APF (mTLS)**,
  já não com password.
- Se `201`, guarda `api_id`. A API fica no **catálogo** do CAPIF, pronta a ser descoberta.

---

## 8. Fluxo do BANCO

### `bk_register()` — registar o Banco como Invoker
```python
def bk_register(self):
    self.invoker_id = self.token = self.aef_url = None   # reset
    self._ensure_account("banco_itau", "Itau123", enterprise="Bank", ...)
    r = self._getauth("banco_itau", "Itau123")           # login do banco -> JWT
    token = r.json()["access_token"]
    csr = _gen_csr("banco_itau", "invoker")              # 1 chave + 1 CSR
    body = {"onboardingInformation": {"apiInvokerPublicKey": csr},
            "notificationDestination": "http://localhost:9999/cb",
            "apiInvokerInformation": "Bank", "supportedFeatures": "0"}
    rr = requests.post(f"{CAPIF}/api-invoker-management/v1/onboardedInvokers",
                       json=body, headers={"Authorization": f"Bearer {token}"}, ...)
    inv = rr.json()
    self.invoker_id = inv.get("apiInvokerId")            # GUARDA o id do invoker
    cert = inv.get("onboardingInformation", {}).get("apiInvokerCertificate", "")
    if cert: _save("banco_itau.crt", cert)               # grava o certificado
    return self._r(True, "Register as Invoker", ..., {"invoker_id": self.invoker_id}, ...)
```
Igual ao registo da operadora, mas para um **consumidor (invoker)**:
1. Conta `banco_itau` no Register, login → JWT.
2. Gera **1 chave + 1 CSR** (papel `invoker`).
3. `POST /onboardedInvokers` → recebe `invoker_id` + **certificado do banco** (gravado).
4. A partir daqui o Banco autentica-se por **mTLS** com `banco_itau.crt/.key`.

### `bk_discover()` — descobrir APIs no catálogo
```python
def bk_discover(self):
    if not self.invoker_id:
        return self._r(False, "Discover APIs", "Register the Invoker first.")
    r = requests.get(
        f"{CAPIF}/service-apis/v1/allServiceAPIs?api-invoker-id={self.invoker_id}",
        cert=_cert("banco_itau"), verify=_verify(), ...)
    apis = r.json().get("serviceAPIDescriptions", [])
    found = []
    for api in apis:
        ep = None
        for p in api.get("aefProfiles", []):
            self.aef_id = p.get("aefId", self.aef_id)          # guarda aef_id
            for v in p.get("versions", []):
                for res in v.get("resources", []):
                    for iface in p.get("interfaceDescriptions", []):
                        host = iface.get("ipv4Addr") or iface.get("fqdn")
                        port = iface.get("port")
                        if host and port:
                            self.aef_url = f"http://{host}:{port}{iface.get('apiPrefix','')}{res.get('uri')}"
                            ep = f"{res.get('operations')} {res.get('uri')}"
        self.api_id = api.get("apiId", self.api_id)            # guarda api_id
        found.append({"name": api.get("apiName"), "description": ..., "endpoint": ep})
    return self._r(True, "Discover APIs", ..., {"apis": found})
```
**O que faz:**
- `GET /allServiceAPIs` (com certificado mTLS do banco) → o CAPIF devolve o **catálogo**.
- Os 4 `for` aninhados "escavam" a estrutura JSON da API até encontrar:
  - `aef_id` (quem expõe), `api_id` (qual API), e o **`aef_url`** — o **URL real** do endpoint
    (reconstruído a partir de host + port + prefixo + uri).
- `host = ipv4 or fqdn` → usa o IP; se não houver, usa o nome DNS.
- Guarda tudo no estado para os passos seguintes.

> Repara: o Banco **descobre a API da Operadora sem nunca ter falado diretamente com ela** —
> é exatamente o objetivo do CAPIF.

### `bk_token()` — obter o token OAuth2
```python
def bk_token(self):
    if not (self.invoker_id and self.aef_id and self.api_id):
        return self._r(False, "Get Access Token", "Run API Discovery (Step 2) first.")
    body = {"securityInfo": [{"aefId": self.aef_id, "apiId": self.api_id,
                              "prefSecurityMethods": ["OAUTH"]}],
            "notificationDestination": "http://localhost:9999/sec", "supportedFeatures": "0"}
    rs = requests.put(f"{CAPIF}/capif-security/v1/trustedInvokers/{self.invoker_id}",
                      json=body, cert=_cert("banco_itau"), ...)      # 1) tornar-se "trusted"
    scope = f"3gpp#{self.aef_id}:SIM_Swap"
    rt = requests.post(
        f"{CAPIF}/capif-security/v1/securities/{self.invoker_id}/token",
        data={"grant_type": "client_credentials", "client_id": self.invoker_id,
              "scope": scope}, cert=_cert("banco_itau"), ...)        # 2) pedir o token
    if rt.status_code != 200:
        return self._r(False, "Get Access Token", f"Token rejected ({rt.status_code}).", ...)
    self.token = rt.json().get("access_token", "")
    return self._r(True, "Get Access Token", ..., {"token": self.token[:50] + "..."}, ...)
```
**Dois passos:**
1. `PUT /trustedInvokers/...` → o Banco **regista-se como confiável** para aquela API
   (diz "quero usar esta `aefId`+`apiId` com OAUTH").
2. `POST .../token` com `grant_type=client_credentials` e um **`scope`** que identifica a
   API (`3gpp#<aef_id>:SIM_Swap`) → o CAPIF devolve o **`access_token` OAuth2**.

> A guarda exige `invoker_id`, `aef_id` e `api_id` — ou seja, **só funciona depois da
> Descoberta**. O token é a "chave" final que prova que o Banco está autorizado.

### `bk_check(phone)` — chamar a API real e decidir
```python
def bk_check(self, phone):
    if not (self.token and self.aef_url):
        return self._r(False, "Fraud Check", "Obtain the access token first.")
    try:
        r = requests.post(self.aef_url, json={"phoneNumber": phone, "maxAge": 24},
                          headers={"Authorization": f"Bearer {self.token}"}, timeout=5)
        d = r.json()
    except Exception:
        return self._r(False, "Fraud Check", "The Operator server (mock) did not respond. ...")
    approve = not d.get("swapped")        # se NÃO houve swap -> aprova
    if approve:
        summary = f"... Response: NO. The bank approves the transaction."
    else:
        summary = f"... Response: YES, on {d.get('lastSwapTime')}. ... blocks the transaction."
    return self._r(True, "Fraud Check", summary,
                   [self._call(f"POST /sim-swap/check ({phone})", r.status_code, approve)],
                   {"phone": phone, "swapped": d.get("swapped"),
                    "decision": "APPROVE" if approve else "BLOCK"})
```
**O momento da verdade:**
- Usa o **`aef_url`** (descoberto) e o **`token`** (obtido) para chamar **diretamente a API
  real da Operadora** (o mock em `:9200`), enviando o número de telefone.
- `try/except`: se o mock não responder, devolve mensagem amigável (lembra de correr
  `sim_swap_mock.py`).
- **Regra de decisão:** `approve = not d.get("swapped")`
  - `swapped == False` → **APPROVE** (sem troca de SIM, transação segura).
  - `swapped == True` → **BLOCK** (houve troca recente → possível fraude).
- Repara que esta chamada **não passa pelo CAPIF Core** — vai direta ao endpoint, mas só é
  aceite porque leva o **token OAuth2** que o CAPIF emitiu. É assim que funciona na realidade.

---

## 9. A história completa, do início ao fim

```
OPERADORA                         CAPIF (Core :443 / Register :8084)            BANCO
─────────                         ───────────────────────────────────          ─────
op_register() ──login/conta────▶  Register dá JWT + ca.crt
              ──3 CSRs──────────▶ Core+Vault assinam ──▶ 3 certificados (APF/AEF/AMF)
op_publish()  ──publica API────▶  Catálogo guarda "SIM_Swap"  ◀── descoberta ── bk_discover()
                                  Register dá JWT ◀── conta ─────────────────── bk_register()
                                  Core assina ──▶ certificado do invoker
                                  emite token OAuth2 ──────────────────────────▶ bk_token()
                                                                                 bk_check(phone)
Mock :9200  ◀────────── POST /sim-swap/check  (token OAuth2) ────────────────── (chamada direta)
            ──────────▶ {"swapped": true/false}  ──▶  APPROVE / BLOCK
```

**Sequência de botões a carregar na demo:**
1. Operadora → **Registar** (`op_register`)
2. Operadora → **Publicar API** (`op_publish`)
3. Banco → **Registar** (`bk_register`)
4. Banco → **Descobrir** (`bk_discover`)
5. Banco → **Obter token** (`bk_token`)
6. Banco → **Verificar fraude** (`bk_check`) — experimenta com `+351911111111` (BLOCK)
   e com outro número qualquer (APPROVE).

---

## 10. Conceitos que aparecem muito (glossário rápido)

- **CSR**: pedido de certificado. Contém a chave **pública**; assinas com a **privada**.
- **mTLS**: TLS mútuo — **cliente e servidor** provam identidade com certificados
  (no `requests` é o parâmetro `cert=(.crt, .key)`).
- **JWT / Bearer token**: "crachá" temporário em texto, enviado no cabeçalho `Authorization`.
- **OAuth2 `client_credentials`**: máquina-a-máquina pede um token sem utilizador humano.
- **`verify=`**: no `requests`, valida (caminho do CA) ou não (`False`) o certificado do servidor.
- **APF / AEF / AMF**: papéis do *provider* (publicar / expor / gerir).
- **Invoker**: o *consumidor* da API (o Banco).

---

## 11. Como correr (resumo prático)

```bash
# 1) Arrancar o mock da API da Operadora (porta 9200)
python3 capif/.../sim_swap_mock.py        # confirma o caminho real no teu repo

# 2) Arrancar os portais web
python3 capif/web_demo/app.py             # abre http://localhost:8090
```
Depois abre `http://localhost:8090/operadora` e `http://localhost:8090/banco`
e carrega nos botões pela ordem da secção 9.

> Para reiniciar tudo: o endpoint `POST /api/reset` recria o `CapifFlow` (limpa o estado)
> e corre `reset_demo.sh` se existir.
```
```

---

### TL;DR — por onde começar
Lê **o topo** (constantes + `_verify`), depois as **funções `_`**, depois segue os métodos
**na ordem da demo**: `op_register → op_publish → bk_register → bk_discover → bk_token → bk_check`.
Cada método: (1) verifica pré-condições, (2) faz 1–2 pedidos HTTP, (3) guarda ids/token no
`self`, (4) devolve um dicionário com `_r(...)` para a UI mostrar.
