#!/usr/bin/env python3
"""
provas_seguranca.py — 3 provas de segurança da demo CAPIF, contra o STACK REAL.

  PROVA 1 — Validação do certificado TLS do capifcore (nome + cadeia).
  PROVA 2 — Verificação da ASSINATURA do certificado (mostra os 2 hashes).
  PROVA 3 — O mock (AEF) rejeita um token OAuth2 FORJADO (401).

Vai buscar a cadeia de certificados diretamente à ligação TLS, por isso NÃO
precisa de teres feito "Register" antes — só precisa do stack CAPIF de pé.
A PROVA 3 precisa do mock (sim_swap_mock.py) a correr na :9200 (senão é saltada).

Correr:  python3 capif/web_demo/provas_seguranca.py
"""

import hashlib
import re
import socket
import ssl
import subprocess
import tempfile
import urllib.request
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

HOST, PORT = "capifcore", 443
MOCK = "http://localhost:9200/sim-swap/check"
LINHA = "=" * 70


def titulo(t):
    print(f"\n{LINHA}\n  {t}\n{LINHA}")


def get_chain():
    """Obtém a cadeia de certificados que o servidor apresenta (leaf + CA...)."""
    out = subprocess.run(
        ["openssl", "s_client", "-showcerts", "-servername", HOST,
         "-connect", f"{HOST}:{PORT}"],
        input=b"", capture_output=True, timeout=10).stdout.decode(errors="ignore")
    pems = re.findall(
        r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", out, re.S)
    return [x509.load_pem_x509_certificate(p.encode()) for p in pems]


# ----------------------------------------------------------------------------
chain = get_chain()
if len(chain) < 2:
    print("[!] Não consegui obter a cadeia (leaf + CA) do capifcore:443.")
    print("    O stack CAPIF está de pé? (docker ps | grep nginx)")
    raise SystemExit(1)

leaf, ca = chain[0], chain[1]      # leaf = capifcore ; ca = intermediate authority

# ============================ PROVA 1 ============================
titulo("PROVA 1 — Validação do certificado TLS (nome + cadeia)")
print(f"  Servidor apresenta : {leaf.subject.rfc4514_string()}")
print(f"  Assinado por       : {leaf.issuer.rfc4514_string()}")

# guarda a(s) CA(s) num ficheiro temporário para usar como 'trust anchor'
with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as f:
    for c in chain[1:]:
        f.write(c.public_bytes(serialization.Encoding.PEM).decode())
    ca_file = f.name


def tenta(ctx, nome):
    try:
        with socket.create_connection((HOST, PORT), timeout=5) as s:
            with ctx.wrap_socket(s, server_hostname=nome) as ss:
                return True, ss.version()
    except ssl.SSLError as e:
        return False, getattr(e, "verify_message", None) or str(e.reason)


ctx_ok = ssl.create_default_context(cafile=ca_file)
print("\n  TESTE 1 (CA certa + nome certo):    ", end="")
ok, info = tenta(ctx_ok, HOST);                 print("PASSOU ✅  TLS=" + info if ok else "FALHOU ❌ " + info)
print("  TESTE 2 (CA certa + nome ERRADO):   ", end="")
ok, info = tenta(ctx_ok, "banco-falso.com");    print("FALHOU ❌  " + info if not ok else "PASSOU (mau!) ⚠️")
print("  TESTE 3 (SEM a CA do CAPIF):        ", end="")
ok, info = tenta(ssl.create_default_context(), HOST); print("FALHOU ❌  " + info if not ok else "PASSOU (mau!) ⚠️")
print("\n  => só o TESTE 1 passa. Logo a validação do nome E da cadeia é real.")

# ============================ PROVA 2 ============================
titulo("PROVA 2 — Verificação da ASSINATURA (os 2 hashes comparados)")
assinatura = leaf.signature
conteudo = leaf.tbs_certificate_bytes
nums = ca.public_key().public_numbers()
n, e = nums.n, nums.e

hash_A = hashlib.sha256(conteudo).digest()                       # nós, do conteúdo
k = (n.bit_length() + 7) // 8
recuperado = pow(int.from_bytes(assinatura, "big"), e, n).to_bytes(k, "big")
hash_B = recuperado[-32:]                                        # aberto da assinatura

print(f"  hash A (calculado do conteúdo)   : {hash_A.hex()}")
print(f"  hash B (aberto da assinatura)    : {hash_B.hex()}")
print(f"\n  hash A == hash B ?  ->  {hash_A == hash_B}  " +
      ("✅ VÁLIDA" if hash_A == hash_B else "❌ INVÁLIDA"))
try:
    ca.public_key().verify(assinatura, conteudo, padding.PKCS1v15(), hashes.SHA256())
    print("  cryptography.verify(): OK ✅")
except Exception as ex:
    print(f"  cryptography.verify() FALHOU ❌: {ex}")
# prova de adulteração
adv = bytearray(conteudo); adv[10] ^= 0x01
print(f"  (se mexer 1 byte) hash A bate? -> {hashlib.sha256(bytes(adv)).digest() == hash_B}  (FALHA esperada)")

# ============================ PROVA 3 ============================
titulo("PROVA 3 — O mock rejeita um token OAuth2 FORJADO (401)")
token_falso = ("eyJhbGciOiJSUzI1NiJ9."
               "eyJzY29wZSI6IjNncHAjYWVmOlNJTV9Td2FwIn0.AAAA")  # assinatura inválida
req = urllib.request.Request(
    MOCK, data=b'{"phoneNumber":"+351912345678"}',
    headers={"Authorization": f"Bearer {token_falso}", "Content-Type": "application/json"},
    method="POST")
try:
    urllib.request.urlopen(req, timeout=5)
    print("  Resposta 200 ⚠️ (inesperado — o token forjado foi aceite!)")
except urllib.error.HTTPError as he:
    detalhe = he.read().decode(errors="ignore")
    print(f"  Resposta {he.code} ✅ (token forjado REJEITADO)")
    print(f"  Detalhe do mock: {detalhe[:120]}")
except Exception:
    print("  [saltado] O mock (sim_swap_mock.py) não está a correr na :9200.")

print(f"\n{LINHA}\n  FIM — as 3 provas de segurança.\n{LINHA}")
