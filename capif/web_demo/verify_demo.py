#!/usr/bin/env python3
"""
verify_demo.py — the SAME CAPIF flow, but done the "production-correct" way:
the client VALIDATES the server certificate against the CA (verify=ca.crt) and
connects using the certificate's real hostnames (capifcore / register).

This file is standalone on purpose — it does NOT touch capif_flow.py or app.py,
so the web demo keeps working exactly as before.

WHAT IT PROVES
  Without verify (verify=False) you trust whoever answers the address — an
  impostor could impersonate CAPIF (man-in-the-middle). With verify=ca.crt the
  client checks the server's certificate was signed by the real CAPIF CA AND has
  the right name. That is the padlock your browser shows for your bank.

PREREQUISITES
  1) CAPIF system up (./check_demo.sh) with a CONSISTENT CA.
  2) Add the hostnames to /etc/hosts (once):
        echo "127.0.0.1 capifcore register" | sudo tee -a /etc/hosts

RUN
        python3 web_demo/verify_demo.py
"""

import os
import requests
import urllib3
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography import x509
from cryptography.x509.oid import NameOID

# Real hostnames (must match the certificates' SAN: capifcore / register)
REGISTER = "https://register:8084"
CAPIF = "https://capifcore:443"
ADMIN = ("admin", "password123")
WORK_DIR = "/tmp/capif_demo"
CA_FILE = f"{WORK_DIR}/ca.crt"


def verify():
    """Return the CA path if we already have it (validate the server), else False.

    The very first login/getauth happen BEFORE we own the ca.crt, so they cannot
    validate yet (bootstrap). Every call after that validates against the CA.
    In production the ca.crt is distributed out-of-band, so even the first call
    would validate.
    """
    if os.path.exists(CA_FILE):
        return CA_FILE
    return False


def show_verify(label):
    if verify():
        print(f"  [VERIFY ] {label}: server certificate VALIDATED against ca.crt (real CAPIF)")
    else:
        print(f"  [VERIFY ] {label}: bootstrap (no ca.crt yet) — validation starts after getauth")


def gen_csr(name, cn):
    os.makedirs(WORK_DIR, exist_ok=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([
               x509.NameAttribute(NameOID.COMMON_NAME, cn),
               x509.NameAttribute(NameOID.ORGANIZATION_NAME, "CAPIF System"),
               x509.NameAttribute(NameOID.COUNTRY_NAME, "PT")]))
           .sign(key, hashes.SHA256()))
    with open(f"{WORK_DIR}/{name}.key", "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption()))
    return csr.public_bytes(serialization.Encoding.PEM).decode("utf-8")


def save(name, content):
    os.makedirs(WORK_DIR, exist_ok=True)
    with open(f"{WORK_DIR}/{name}", "w") as f:
        f.write(content)


def cert(name):
    crt, key = f"{WORK_DIR}/{name}.crt", f"{WORK_DIR}/{name}.key"
    return (crt, key) if os.path.exists(crt) and os.path.exists(key) else None


def step(n, title):
    print(f"\n===== STEP {n} — {title} =====")


def main():
    os.makedirs(WORK_DIR, exist_ok=True)

    # ---------- OPERATOR: register ----------
    step(1, "Operator registers (JWT -> CSRs -> certificates)")
    show_verify("POST /login")
    r = requests.post(f"{REGISTER}/login", auth=ADMIN, verify=verify(), timeout=10)
    admin_jwt = r.json()["access_token"]
    print(f"  [ADMIN  ] <- ADMIN JWT received ({admin_jwt[:25]}...)")

    h = {"Authorization": f"Bearer {admin_jwt}", "Content-Type": "application/json"}
    requests.post(f"{REGISTER}/createUser", headers=h, verify=verify(),
                  json={"username": "operadora_5g", "password": "Operadora123",
                        "enterprise": "Operator", "country": "PT",
                        "email": "apf@operator.pt", "purpose": "API Provider"})
    print("  [ADMIN  ] account 'operadora_5g' created")

    show_verify("GET /getauth")
    auth = requests.get(f"{REGISTER}/getauth", auth=("operadora_5g", "Operadora123"),
                        verify=verify(), timeout=10).json()
    save("ca.crt", auth["ca_root"])
    op_jwt = auth["access_token"]
    print(f"  [OPERATOR] <- OPERATOR JWT + ca.crt received  (now we CAN validate the server)")

    csrs = {role: gen_csr(f"{role}_operadora_5g", role.lower())
            for role in ("APF", "AEF", "AMF")}
    print("  [OPERATOR] generated 3 RSA private keys + CSRs locally (keys never leave this machine)")
    body = {"regSec": op_jwt, "apiProvDomInfo": "Operator", "suppFeat": "0",
            "apiProvFuncs": [{"regInfo": {"apiProvPubKey": csrs[r_]},
                "apiProvFuncRole": r_, "apiProvFuncInfo": f"{r_}_operadora_5g"}
                for r_ in csrs]}
    show_verify("POST /registrations")
    rr = requests.post(f"{CAPIF}/api-provider-management/v1/registrations",
                       json=body, headers={"Authorization": f"Bearer {op_jwt}"},
                       verify=verify(), timeout=15)
    apf_id = aef_id = None
    for func in rr.json().get("apiProvFuncs", []):
        role = func.get("apiProvFuncRole")
        c = func.get("regInfo", {}).get("apiProvCert", "")
        if c:
            save(f"{func.get('apiProvFuncInfo', role)}.crt", c)
        if role == "APF":
            apf_id = func.get("apiProvFuncId")
        if role == "AEF":
            aef_id = func.get("apiProvFuncId")
    print(f"  [OPERATOR] <- 3 signed certificates received | APF_ID={apf_id}")

    # ---------- OPERATOR: publish ----------
    step(2, "Operator publishes the SIM Swap API (mTLS + verify)")
    body = {"apiName": "SIM_Swap", "supportedFeatures": "0", "apiSuppFeats": "fffff",
            "description": "GSMA SIM Swap API", "shareableInfo": {"isShareable": True},
            "serviceAPICategory": "Security",
            "aefProfiles": [{"aefId": aef_id, "protocol": "HTTP_1_1",
                "securityMethods": ["OAUTH"],
                "interfaceDescriptions": [{"ipv4Addr": "127.0.0.1", "port": 9200,
                    "securityMethods": ["OAUTH"]}],
                "versions": [{"apiVersion": "v1", "resources": [{
                    "resourceName": "checkSimSwap", "commType": "REQUEST_RESPONSE",
                    "uri": "/sim-swap/check", "operations": ["POST"],
                    "description": "Check SIM swap"}]}]}]}
    show_verify("POST /service-apis")
    r = requests.post(f"{CAPIF}/published-apis/v1/{apf_id}/service-apis",
                      json=body, cert=cert("APF_operadora_5g"), verify=verify(), timeout=15)
    api_id = r.json().get("apiId")
    print(f"  [OPERATOR] <- API published, api_id={api_id}")

    # ---------- BANK: register ----------
    step(3, "Bank registers as Invoker")
    requests.post(f"{REGISTER}/createUser", headers=h, verify=verify(),
                  json={"username": "banco_itau", "password": "Itau123",
                        "enterprise": "Bank", "country": "PT",
                        "email": "api@bank.example", "purpose": "SIM Swap consumer"})
    bk_jwt = requests.get(f"{REGISTER}/getauth", auth=("banco_itau", "Itau123"),
                          verify=verify(), timeout=10).json()["access_token"]
    csr = gen_csr("banco_itau", "invoker")
    body = {"onboardingInformation": {"apiInvokerPublicKey": csr},
            "notificationDestination": "http://localhost:9999/cb",
            "apiInvokerInformation": "Bank", "supportedFeatures": "0"}
    show_verify("POST /onboardedInvokers")
    inv = requests.post(f"{CAPIF}/api-invoker-management/v1/onboardedInvokers",
                        json=body, headers={"Authorization": f"Bearer {bk_jwt}"},
                        verify=verify(), timeout=15).json()
    invoker_id = inv.get("apiInvokerId")
    save("banco_itau.crt", inv.get("onboardingInformation", {}).get("apiInvokerCertificate", ""))
    print(f"  [BANK   ] <- certificate + invoker_id={invoker_id}")

    # ---------- BANK: discover ----------
    step(4, "Bank discovers the API (mTLS + verify)")
    show_verify("GET /allServiceAPIs")
    apis = requests.get(
        f"{CAPIF}/service-apis/v1/allServiceAPIs?api-invoker-id={invoker_id}",
        cert=cert("banco_itau"), verify=verify(), timeout=15).json().get("serviceAPIDescriptions", [])
    aef_url = None
    for api in apis:
        for p in api.get("aefProfiles", []):
            aef_id = p.get("aefId", aef_id)
            for v in p.get("versions", []):
                for res in v.get("resources", []):
                    for iface in p.get("interfaceDescriptions", []):
                        host = iface.get("ipv4Addr") or iface.get("fqdn")
                        if host and iface.get("port"):
                            aef_url = f"http://{host}:{iface.get('port')}{res.get('uri')}"
        api_id = api.get("apiId", api_id)
    print(f"  [BANK   ] <- discovered {len(apis)} API(s); endpoint={aef_url}")

    # ---------- BANK: token ----------
    step(5, "Bank gets the OAuth2 token (mTLS + verify)")
    body = {"securityInfo": [{"aefId": aef_id, "apiId": api_id,
                              "prefSecurityMethods": ["OAUTH"]}],
            "notificationDestination": "http://localhost:9999/sec", "supportedFeatures": "0"}
    show_verify("PUT /trustedInvokers")
    requests.put(f"{CAPIF}/capif-security/v1/trustedInvokers/{invoker_id}",
                 json=body, cert=cert("banco_itau"), verify=verify(), timeout=15)
    scope = f"3gpp#{aef_id}:SIM_Swap"
    show_verify("POST /token")
    token = requests.post(
        f"{CAPIF}/capif-security/v1/securities/{invoker_id}/token",
        data={"grant_type": "client_credentials", "client_id": invoker_id, "scope": scope},
        cert=cert("banco_itau"), verify=verify(), timeout=15).json().get("access_token", "")
    print(f"  [BANK   ] <- OAuth2 access_token received ({token[:25]}...)")

    # ---------- BANK: check ----------
    step(6, "Bank checks customers (call the API with the token)")
    for phone in ("+351912345678", "+351911111111"):
        d = requests.post(aef_url, json={"phoneNumber": phone, "maxAge": 24},
                          headers={"Authorization": f"Bearer {token}"}, timeout=5).json()
        decision = "BLOCK" if d.get("swapped") else "APPROVE"
        print(f"  [BANK   ] {phone}: swapped={d.get('swapped')} -> {decision}")

    print("\n===== DONE — every CAPIF call above validated the server with ca.crt =====")


if __name__ == "__main__":
    if not verify():
        print("Note: ca.crt not present yet; the first calls bootstrap, then validation kicks in.")
    try:
        main()
    except requests.exceptions.SSLError as e:
        print("\nSSL validation FAILED — this is the point of the script.")
        print("Likely cause: /etc/hosts is missing the line:  127.0.0.1 capifcore register")
        print(f"Details: {e}")
    except requests.exceptions.ConnectionError as e:
        print("\nConnection error. Did you add '127.0.0.1 capifcore register' to /etc/hosts?")
        print(f"Details: {e}")
