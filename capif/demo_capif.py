#!/usr/bin/env python3
"""
DEMO CAPIF — Fluxo Completo
Operadora publica SIM Swap API → Banco Itaú descobre e acede

Corre em: ~/capif/
Requer sistema a correr (./run.sh)
"""

import requests
import os
import sys
import urllib3
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography import x509
from cryptography.x509.oid import NameOID

urllib3.disable_warnings()

# ── Configuração ─────────────────────────────────────────────────────
REGISTER  = "https://localhost:8084"
CAPIF     = "https://localhost:443"
ADMIN     = ("admin", "password123")
WORK_DIR  = "/tmp/capif_demo"

os.makedirs(WORK_DIR, exist_ok=True)

# ── Cores para terminal ───────────────────────────────────────────────
G = "\033[92m"   # verde
Y = "\033[93m"   # amarelo
B = "\033[94m"   # azul
R = "\033[91m"   # vermelho
W = "\033[97m"   # branco
E = "\033[0m"    # reset
BOLD = "\033[1m"

def separador(n, titulo):
    print(f"\n{BOLD}{Y}{'━'*62}{E}")
    print(f"{BOLD}{W}  PASSO {n} — {titulo}{E}")
    print(f"{BOLD}{Y}{'━'*62}{E}")
    try:
        input(f"  {B}▶ Prima ENTER para executar...{E}")
    except (KeyboardInterrupt, EOFError):
        print(f"\n{R}Demo interrompida.{E}")
        sys.exit(0)

def ok(msg):     print(f"  {G}✓ {msg}{E}")
def info(msg):   print(f"  {B}ℹ {msg}{E}")
def aviso(msg):  print(f"  {Y}▶ {msg}{E}")
def erro(msg):   print(f"  {R}✗ {msg}{E}")

def mostrar_json(label, data, max_campos=8):
    print(f"\n  {B}[ {label} ]{E}")
    if isinstance(data, dict):
        for i, (k, v) in enumerate(data.items()):
            if i >= max_campos:
                print(f"    ... (+{len(data)-max_campos} campos)")
                break
            val = str(v)
            if len(val) > 90:
                val = val[:87] + "..."
            print(f"    {W}{k}{E}: {val}")
    else:
        print(f"    {str(data)[:200]}")

def gerar_csr(nome_ficheiro, cn="capif"):
    """Gera par de chaves RSA 2048 e devolve CSR em PEM (string)."""
    chave = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    csr = (
        x509.CertificateSigningRequestBuilder()
        .subject_name(x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, cn),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Demo CAPIF"),
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PT"),
        ]))
        .sign(chave, hashes.SHA256())
    )

    caminho_chave = f"{WORK_DIR}/{nome_ficheiro}.key"
    with open(caminho_chave, "wb") as f:
        f.write(chave.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption()
        ))

    return csr.public_bytes(serialization.Encoding.PEM).decode("utf-8")

def guardar(nome, conteudo):
    caminho = f"{WORK_DIR}/{nome}"
    with open(caminho, "w") as f:
        f.write(conteudo)
    return caminho

def cert_pair(nome):
    crt = f"{WORK_DIR}/{nome}.crt"
    key = f"{WORK_DIR}/{nome}.key"
    if os.path.exists(crt) and os.path.exists(key):
        return (crt, key)
    return None

def ca():
    ca_path = f"{WORK_DIR}/ca.crt"
    return ca_path if os.path.exists(ca_path) else False


# ════════════════════════════════════════════════════════════════════
print(f"\n{BOLD}{W}{'═'*62}{E}")
print(f"{BOLD}{W}   DEMO CAPIF — Fluxo Completo   {E}")
print(f"{BOLD}{W}   Operadora 5G  →  CAPIF  →  Banco Itaú   {E}")
print(f"{BOLD}{W}{'═'*62}{E}")
print(f"""
  Cenário:
  • A {W}Operadora 5G{E} tem uma API de detecção de fraude: {G}SIM Swap{E}
  • O {W}Banco Itaú{E} quer usar essa API para proteger os seus clientes
  • O {W}CAPIF{E} é o porteiro — controla quem publica e quem acede

  Vamos fazer os 5 passos em tempo real.
  Os dados ficam visíveis no MongoDB em http://localhost:8082
""")


# ── PASSO 1 ── Arrancar e verificar o sistema ─────────────────────────
separador(1, "Verificar que o sistema CAPIF está a correr")

def verificar(url, nome, ok_codes):
    """Pinga um serviço; se não responder, dá instruções em vez de crashar."""
    try:
        resp = requests.get(url, verify=False, timeout=5)
    except requests.exceptions.RequestException:
        erro(f"{nome} não responde em {url}")
        aviso("O sistema CAPIF não está a correr. Arranca-o primeiro:")
        aviso("  cd ~/capif/services && ./run.sh && sleep 30 && docker restart register")
        sys.exit(1)
    if resp.status_code in ok_codes:
        ok(f"{nome} responde em {url}")
    else:
        aviso(f"{nome} respondeu HTTP {resp.status_code}")

verificar(f"{REGISTER}/", "Register", [200, 404, 405])
verificar(f"{CAPIF}/test", "CAPIF Core (nginx)", [200, 404])

aviso("Abre o MongoDB: http://localhost:8082 — está vazio agora")
aviso("Sistema composto por 23 containers Docker — 11 microserviços Flask + nginx + MongoDB + Redis + Vault")


# ── PASSO 2 ── Criar utilizadores ──────────────────────────────────────
separador(2, "Registar utilizadores — Operadora 5G e Banco Itaú")

# Login como admin
resp = requests.post(f"{REGISTER}/login", auth=ADMIN, verify=False)
if resp.status_code != 200:
    erro(f"Login falhou ({resp.status_code}): {resp.text[:100]}")
    sys.exit(1)
admin_token = resp.json()["access_token"]
ok("Admin autenticado")

headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}

# Criar Provider
resp_p = requests.post(f"{REGISTER}/createUser", headers=headers, verify=False, json={
    "username": "operadora_5g",
    "password": "Operadora123",
    "enterprise": "Operadora 5G Portugal",
    "country": "PT",
    "email": "apf@operadora5g.pt",
    "purpose": "Fornecedor de APIs 5G"
})

if resp_p.status_code in [201, 409]:
    ok(f"Operadora 5G criada (HTTP {resp_p.status_code})")
    if resp_p.status_code == 201:
        mostrar_json("Utilizador criado no MongoDB", resp_p.json())
else:
    erro(f"Erro ao criar Operadora: {resp_p.text[:150]}")

# Criar Invoker
resp_i = requests.post(f"{REGISTER}/createUser", headers=headers, verify=False, json={
    "username": "banco_itau",
    "password": "Itau123",
    "enterprise": "Banco Itaú",
    "country": "BR",
    "email": "api@itau.com.br",
    "purpose": "Consumidor de APIs — Prevenção de fraude SIM Swap"
})

if resp_i.status_code in [201, 409]:
    ok(f"Banco Itaú criado (HTTP {resp_i.status_code})")
    if resp_i.status_code == 201:
        mostrar_json("Utilizador criado no MongoDB", resp_i.json())
else:
    erro(f"Erro ao criar Banco Itaú: {resp_i.text[:150]}")

aviso("MongoDB → http://localhost:8083 → capif_users → user — vês os 2 utilizadores!")


# ── PASSO 3 ── Provider regista-se no CAPIF Core ──────────────────────
separador(3, "Operadora 5G regista-se no CAPIF Core como Provider")

# Operadora obtém token JWT do Register
resp = requests.get(f"{REGISTER}/getauth", auth=("operadora_5g", "Operadora123"), verify=False)
if resp.status_code != 200:
    erro(f"getauth falhou: {resp.text[:150]}")
    sys.exit(1)

auth_op = resp.json()
token_op = auth_op["access_token"]
guardar("ca.crt", auth_op["ca_root"])
ok("CA root obtido do Register → guardado em ca.crt")
ok(f"Access token JWT obtido: {token_op[:40]}...")
aviso(f"URL de registo fornecido pelo Register: {auth_op.get('ccf_api_onboarding_url')}")

# Gerar CSRs para as 3 funções do Provider (APF, AEF, AMF)
info("A gerar pares de chaves RSA para APF, AEF e AMF (funções do Provider)...")
csr_apf = gerar_csr("APF_operadora_5g", cn="apf")
csr_aef = gerar_csr("AEF_operadora_5g", cn="aef")
csr_amf = gerar_csr("AMF_operadora_5g", cn="amf")
ok("CSRs gerados localmente — prontos para o CAPIF assinar")

body_provider = {
    "regSec": token_op,
    "apiProvFuncs": [
        {"regInfo": {"apiProvPubKey": csr_apf}, "apiProvFuncRole": "APF", "apiProvFuncInfo": "APF_operadora_5g"},
        {"regInfo": {"apiProvPubKey": csr_aef}, "apiProvFuncRole": "AEF", "apiProvFuncInfo": "AEF_operadora_5g"},
        {"regInfo": {"apiProvPubKey": csr_amf}, "apiProvFuncRole": "AMF", "apiProvFuncInfo": "AMF_operadora_5g"},
    ],
    "apiProvDomInfo": "Operadora 5G Portugal",
    "suppFeat": "0"
}

resp = requests.post(
    f"{CAPIF}/api-provider-management/v1/registrations",
    json=body_provider,
    headers={"Authorization": f"Bearer {token_op}"},
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  POST /api-provider-management/v1/registrations")

if resp.status_code == 201:
    ok("Operadora registada no CAPIF Core!")
    reg = resp.json()
    apf_id = aef_id = None

    for func in reg.get("apiProvFuncs", []):
        role = func.get("apiProvFuncRole")
        func_id = func.get("apiProvFuncId")
        cert = func.get("regInfo", {}).get("apiProvCert", "")
        nome = func.get("apiProvFuncInfo", role)
        if cert:
            guardar(f"{nome}.crt", cert)
            ok(f"Certificado {role} assinado pelo CAPIF → {nome}.crt")
        if role == "APF": apf_id = func_id
        if role == "AEF": aef_id = func_id

    ok(f"APF ID obtido: {apf_id}")
    ok(f"AEF ID obtido: {aef_id}")
    aviso("MongoDB → http://localhost:8082 → capif → providerenrolmentdetails")
else:
    erro(f"Registo falhou ({resp.status_code}): {resp.text[:300]}")
    sys.exit(1)


# ── PASSO 4 ── Provider publica o SIM Swap API ────────────────────────
separador(4, "Operadora publica o SIM Swap API no catálogo CAPIF")

body_api = {
    "apiName": "SIM_Swap",
    "aefProfiles": [{
        "aefId": aef_id,
        "interfaceDescriptions": [{
            "ipv4Addr": "127.0.0.1",
            "port": 9200,
            "securityMethods": ["OAUTH"]
        }],
        "versions": [{
            "apiVersion": "v1",
            "resources": [{
                "resourceName": "checkSimSwap",
                "commType": "REQUEST_RESPONSE",
                "uri": "/sim-swap/check",
                "operations": ["POST"],
                "description": "Verifica se o SIM foi trocado recentemente — detecta fraude bancária"
            }]
        }],
        "protocol": "HTTP_1_1",
        "securityMethods": ["OAUTH"]
    }],
    "description": "GSMA SIM Swap API — o banco verifica se o SIM foi trocado antes de aprovar transacções",
    "shareableInfo": {"isShareable": True},
    "serviceAPICategory": "Security",
    "supportedFeatures": "0",
    "apiSuppFeats": "fffff"
}

publish_url = f"{CAPIF}/published-apis/v1/{apf_id}/service-apis"
info(f"POST {publish_url}")
info("A usar certificado mTLS do APF (assinado pelo CAPIF no passo anterior)")

resp = requests.post(
    publish_url,
    json=body_api,
    cert=cert_pair("APF_operadora_5g"),
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  POST /published-apis/v1/{apf_id}/service-apis")

if resp.status_code == 201:
    ok("SIM Swap API publicada no catálogo CAPIF!")
    api_resp = resp.json()
    api_id = api_resp.get("apiId")
    ok(f"API ID: {api_id}")
    ok(f"API Name: {api_resp.get('apiName')}")
    aviso("MongoDB → http://localhost:8082 → capif → serviceapidescriptions — vês a SIM Swap API!")
else:
    erro(f"Publicação falhou ({resp.status_code}): {resp.text[:300]}")
    sys.exit(1)


# ── PASSO 5 ── Invoker regista-se e descobre a API ───────────────────
separador(5, "Banco Itaú regista-se como Invoker e descobre a SIM Swap API")

# Banco obtém token JWT do Register
resp = requests.get(f"{REGISTER}/getauth", auth=("banco_itau", "Itau123"), verify=False)
if resp.status_code != 200:
    erro(f"getauth falhou: {resp.text[:150]}")
    sys.exit(1)

auth_inv = resp.json()
token_inv = auth_inv["access_token"]
ok(f"Banco Itaú obteve token JWT do Register")

# Gerar CSR para o Invoker
csr_inv = gerar_csr("banco_itau", cn="invoker")
ok("CSR do Banco Itaú gerado — pronto para o CAPIF assinar")

body_invoker = {
    "onboardingInformation": {"apiInvokerPublicKey": csr_inv},
    "notificationDestination": "http://localhost:9999/itau_callback",
    "apiInvokerInformation": "Banco Itaú — Consumer SIM Swap para prevenção de fraude em Portugal/Brasil",
    "supportedFeatures": "0"
}

resp = requests.post(
    f"{CAPIF}/api-invoker-management/v1/onboardedInvokers",
    json=body_invoker,
    headers={"Authorization": f"Bearer {token_inv}"},
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  POST /api-invoker-management/v1/onboardedInvokers")

if resp.status_code == 201:
    ok("Banco Itaú registado como Invoker no CAPIF!")
    inv_resp = resp.json()
    invoker_id = inv_resp.get("apiInvokerId")
    inv_cert = inv_resp.get("onboardingInformation", {}).get("apiInvokerCertificate", "")
    if inv_cert:
        guardar("banco_itau.crt", inv_cert)
        ok(f"Certificado do Invoker assinado pelo CAPIF → banco_itau.crt")
    ok(f"Invoker ID: {invoker_id}")
    aviso("MongoDB → http://localhost:8082 → capif → invokerdetails — vês o Banco Itaú!")
else:
    erro(f"Onboarding falhou ({resp.status_code}): {resp.text[:300]}")
    sys.exit(1)

# Discovery
print(f"\n  {B}[ Discovery ]{E}")
info(f"Banco Itaú pergunta ao CAPIF: 'que APIs existem?'")
info("A usar certificado mTLS do Invoker (assinado pelo CAPIF)")

resp = requests.get(
    f"{CAPIF}/service-apis/v1/allServiceAPIs?api-invoker-id={invoker_id}",
    cert=cert_pair("banco_itau"),
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  GET /service-apis/v1/allServiceAPIs?api-invoker-id={invoker_id}")

aef_url = None  # URL real do AEF, extraído do Discovery (usado no Passo 6)

if resp.status_code == 200:
    ok("Discovery bem-sucedida!")
    apis = resp.json().get("serviceAPIDescriptions", [])
    ok(f"APIs encontradas: {len(apis)}")
    for api in apis:
        print(f"\n    {G}► {api.get('apiName')}{E}")
        print(f"      Descrição: {api.get('description', 'N/A')[:100]}")
        for perfil in api.get("aefProfiles", []):
            for v in perfil.get("versions", []):
                for r in v.get("resources", []):
                    print(f"      Endpoint: {r.get('operations', [])} {r.get('uri')}")
                    # Construir o URL real do AEF a partir do que o Discovery devolveu
                    if api.get("apiId") == api_id:
                        for iface in perfil.get("interfaceDescriptions", []):
                            host = iface.get("ipv4Addr") or iface.get("fqdn")
                            port = iface.get("port")
                            if host and port:
                                prefix = iface.get("apiPrefix", "")
                                aef_url = f"http://{host}:{port}{prefix}{r.get('uri')}"
    if aef_url:
        ok(f"URL do AEF descoberto: {aef_url}")
else:
    erro(f"Discovery falhou ({resp.status_code}): {resp.text[:300]}")


# ── PASSO 6 ── Banco Itaú obtém token OAuth2 e chama a API ───────────
separador(6, "Banco Itaú obtém token OAuth2 e chama o SIM Swap (mock)")

# 6.1 — Criar contexto de segurança no CAPIF
info("Banco Itaú regista contexto de segurança para a SIM Swap API...")

body_security = {
    "securityInfo": [{
        "aefId": aef_id,
        "apiId": api_id,
        "prefSecurityMethods": ["OAUTH"]
    }],
    "notificationDestination": "http://localhost:9999/sec_callback",
    "supportedFeatures": "0"
}

resp = requests.put(
    f"{CAPIF}/capif-security/v1/trustedInvokers/{invoker_id}",
    json=body_security,
    cert=cert_pair("banco_itau"),
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  PUT /capif-security/v1/trustedInvokers/{invoker_id}")

if resp.status_code in [200, 201]:
    ok("Contexto de segurança criado!")
    aviso("MongoDB → http://localhost:8082 → capif → serviceapisecurity — vês o contexto!")
else:
    erro(f"Contexto falhou ({resp.status_code}): {resp.text[:200]}")
    sys.exit(1)

# 6.2 — Pedir token OAuth2 ao CAPIF
info(f"Banco Itaú pede token OAuth2 ao CAPIF (scope = SIM_Swap no AEF da Operadora)...")

scope = f"3gpp#{aef_id}:SIM_Swap"

resp = requests.post(
    f"{CAPIF}/capif-security/v1/securities/{invoker_id}/token",
    data={
        "grant_type": "client_credentials",
        "client_id": invoker_id,
        "scope": scope
    },
    cert=cert_pair("banco_itau"),
    verify=False
)

print(f"\n  HTTP {resp.status_code}  →  POST /capif-security/v1/securities/{invoker_id}/token")

if resp.status_code == 200:
    token_data = resp.json()
    oauth_token = token_data.get("access_token", "")
    ok("Token OAuth2 emitido pelo CAPIF!")
    ok(f"Token (primeiros 60 chars): {oauth_token[:60]}...")
    ok(f"Tipo: {token_data.get('token_type', 'Bearer')}")
    info("Este token é um JWT assinado pelo CAPIF — prova que o Banco tem autorização")
else:
    erro(f"Token falhou ({resp.status_code}): {resp.text[:300]}")
    sys.exit(1)

# 6.3 — Chamar o AEF real (mock) com o token, no URL que o Discovery devolveu
# NOTA: O OpenCAPIF (community/ETSI OSG) implementa só o plano de GESTÃO
# (onboarding, discovery, tokens). NÃO faz proxy de tráfego — por isso o
# Invoker chama o AEF diretamente, e é o AEF que valida o token do CAPIF.
print(f"\n  {B}[ Chamada real à API — com token ]{E}")

if aef_url is None:
    erro("Não foi possível obter o URL do AEF no Discovery — arranca o sim_swap_mock.py")
    sys.exit(1)

info("(o sim_swap_mock.py representa o servidor real da Operadora)")

def chamar_sim_swap(phone, etiqueta):
    """Chama o AEF com o token e mostra a decisão de negócio do banco."""
    try:
        r = requests.post(
            aef_url,
            json={"phoneNumber": phone, "maxAge": 24},
            headers={"Authorization": f"Bearer {oauth_token}"},
            timeout=5
        )
    except requests.exceptions.ConnectionError:
        erro(f"Não consegui ligar a {aef_url}")
        aviso("Arranca o servidor AEF noutro terminal:  python3 sim_swap_mock.py")
        sys.exit(1)
    print(f"\n  HTTP {r.status_code}  →  POST {aef_url}  ({etiqueta})")
    if r.status_code == 200:
        dados = r.json()
        if dados.get("swapped"):
            erro(f"swapped=True → {dados.get('recommendation')}")
        else:
            ok(f"swapped=False → {dados.get('recommendation')}")
        info(dados.get("detail", ""))
    else:
        aviso(f"AEF respondeu {r.status_code}: {r.text[:120]}")
    return r

# Cliente normal — SIM intacto → o banco APROVA a transação
info("Banco verifica o cliente +351912345678 (SIM intacto)...")
chamar_sim_swap("+351912345678", "cliente seguro")

# Cliente com SIM trocado ontem → o banco BLOQUEIA a transação
info("Banco verifica o cliente +351911111111 (SIM trocado ontem)...")
chamar_sim_swap("+351911111111", "cliente suspeito")

# 6.4 — Mostrar que SEM token o AEF recusa → HTTP 401
print(f"\n  {B}[ Sem token → bloqueado ]{E}")
info("A tentar chamar o mesmo endpoint SEM token...")

no_token_resp = requests.post(
    aef_url,
    json={"phoneNumber": "+351912345678"},
    timeout=5
)

print(f"\n  HTTP {no_token_resp.status_code}  →  POST {aef_url} (sem token)")

if no_token_resp.status_code == 401:
    ok("Bloqueado! HTTP 401 — sem token OAuth2 do CAPIF não há acesso.")
    info("Isto é o controlo de acesso do CAPIF em ação: o AEF rejeita pedidos não autorizados")
else:
    aviso(f"Esperava 401 mas recebi {no_token_resp.status_code}")


# ── RESULTADO FINAL ──────────────────────────────────────────────────
print(f"\n{BOLD}{G}{'═'*62}{E}")
print(f"{BOLD}{G}   DEMO CONCLUÍDA — FLUXO CAPIF COMPLETO{E}")
print(f"{BOLD}{G}{'═'*62}{E}")
print(f"""
  O que o CAPIF fez nesta demo:

  {G}✓{E} Passo 1  Sistema a correr — 23 containers, 11 microserviços
  {G}✓{E} Passo 2  2 utilizadores criados no Register (MongoDB)
  {G}✓{E} Passo 3  Operadora registada como Provider com certificados mTLS
  {G}✓{E} Passo 4  SIM Swap API publicada no catálogo CAPIF
  {G}✓{E} Passo 5  Banco Itaú descobriu a API através do Discovery
  {G}✓{E} Passo 6  Token OAuth2 emitido → API chamada com autenticação real

  Ficheiros gerados em {WORK_DIR}/:
    ca.crt                    CA raiz do CAPIF
    APF_operadora_5g.crt/key  Certificado do API Publishing Function
    AEF_operadora_5g.crt/key  Certificado do API Exposing Function
    banco_itau.crt/key        Certificado do Invoker (Banco Itaú)

  {G}Fluxo de segurança completo:{E}
    JWT (login) → mTLS (registo) → OAuth2 (acesso) → API call
    Três camadas de segurança — o que o CAPIF garante em 5G.
""")
