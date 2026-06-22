#!/usr/bin/env python3
"""
check_demo.py — Verificação RÁPIDA antes da apresentação ("está tudo pronto?").

Confirma, em segundos, que a demo vai funcionar:
  1. Containers CAPIF essenciais estão Up (nada Restarting/Exited).
  2. capifcore:443 (nginx) responde.
  3. register:8084 faz login (200).
  4. Registo end-to-end VALIDA o certificado (o teste que apanha o erro 500).
  5. (opcional) o mock :9200 está a correr.

Se tudo der ✅, podes apresentar. Se algo der ❌, mostra o que fazer.

Correr:  python3 capif/web_demo/check_demo.py
"""

import os
import socket
import ssl
import subprocess
import urllib.request
import urllib.error

import requests
import urllib3
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography import x509
from cryptography.x509.oid import NameOID

urllib3.disable_warnings()
REG, CAP = "https://register:8084", "https://capifcore:443"
ESSENCIAIS = ["services-nginx-1", "services-redis-1", "services-vault-1",
              "services-capif-security-1", "services-api-provider-management-1",
              "services-api-invoker-management-1", "services-published-apis-1",
              "services-service-apis-1", "services-api-invocation-logs-1",
              "services-logs-1", "services-capif-events-1", "register"]

ok_all = True


def res(nome, ok, dica="", opcional=False):
    global ok_all
    if not opcional:
        ok_all = ok_all and ok
    marca = "✅" if ok else ("⚠️" if opcional else "❌")
    print(f"  [{marca}] {nome}" + ("" if ok else f"   -> {dica}"))


print("=" * 64)
print("  CHECK — a demo CAPIF está pronta para apresentar?")
print("=" * 64)

# 1) containers up
maus = []
for c in ESSENCIAIS:
    st = subprocess.run(["docker", "inspect", "-f",
                         "{{.State.Running}}{{.State.Restarting}}", c],
                        capture_output=True, text=True).stdout.strip()
    if st != "truefalse":
        maus.append(c)
res(f"Containers essenciais Up ({len(ESSENCIAIS)-len(maus)}/{len(ESSENCIAIS)})",
    not maus, f"em baixo/restarting: {', '.join(maus)} | corre: docker start <nome> ; docker restart services-nginx-1")

# 2) capifcore responde
try:
    with socket.create_connection(("capifcore", 443), timeout=5) as s:
        ssl._create_unverified_context().wrap_socket(s, server_hostname="capifcore")
    res("capifcore:443 (nginx) responde", True)
except Exception as e:
    res("capifcore:443 (nginx) responde", False, f"nginx em baixo? ({str(e)[:50]})")

# 3) register login
try:
    r = requests.post(f"{REG}/login", auth=("admin", "password123"), verify=False, timeout=8)
    res("register:8084 login (200)", r.status_code == 200, f"HTTP {r.status_code} — docker restart register")
except Exception as e:
    res("register:8084 login", False, str(e)[:50])

# 4) registo end-to-end valida o certificado (apanha o erro 500 / mismatch de CA)
try:
    W = "/tmp/_check_capif"; os.makedirs(W, exist_ok=True)
    adm = requests.post(f"{REG}/login", auth=("admin", "password123"), verify=False, timeout=10).json()["access_token"]
    h = {"Authorization": f"Bearer {adm}", "Content-Type": "application/json"}
    requests.post(f"{REG}/createUser", headers=h, verify=False, timeout=10,
                  json={"username": "check_op", "password": "Check12345", "enterprise": "Op",
                        "country": "PT", "email": "c@c.pt", "purpose": "check"})
    ga = requests.get(f"{REG}/getauth", auth=("check_op", "Check12345"), verify=False, timeout=10).json()
    open(f"{W}/ca.crt", "w").write(ga["ca_root"]); tok = ga["access_token"]
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = x509.CertificateSigningRequestBuilder().subject_name(
        x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "apf")])).sign(key, hashes.SHA256())
    body = {"regSec": tok, "apiProvDomInfo": "Operator", "suppFeat": "0",
            "apiProvFuncs": [{"regInfo": {"apiProvPubKey": csr.public_bytes(serialization.Encoding.PEM).decode()},
                              "apiProvFuncRole": "APF", "apiProvFuncInfo": "APF_check"}]}
    r = requests.post(f"{CAP}/api-provider-management/v1/registrations", json=body,
                      headers={"Authorization": f"Bearer {tok}"}, verify=f"{W}/ca.crt", timeout=15)
    res("Registo end-to-end valida o certificado (HTTP 201)", r.status_code == 201,
        f"HTTP {r.status_code}: {r.text[:60]}")
except Exception as e:
    msg = str(e)
    dica = ("MISMATCH de CA — corre: cd capif/services && ./clean_capif_docker_services.sh -a && ./run.sh"
            if "CERTIFICATE_VERIFY_FAILED" in msg or "unknown ca" in msg
            else msg[:70])
    res("Registo end-to-end valida o certificado", False, dica)

# 5) mock opcional
try:
    urllib.request.urlopen("http://localhost:9200/", timeout=3)
    res("mock :9200 (sim_swap_mock.py) a correr", True)
except Exception:
    res("mock :9200 (opcional p/ fraud check)", False,
        "arranca: python3 capif/sim_swap_mock.py", opcional=True)

print("=" * 64)
print("  RESULTADO:", "✅ TUDO PRONTO — podes apresentar!" if ok_all
      else "❌ HÁ PROBLEMAS — vê as dicas acima antes de apresentar.")
print("=" * 64)
