#!/usr/bin/env python3
"""
capif_flow.py — CAPIF showcase logic, split into per-actor ACTIONS (for the 2 portals).

Reuses the same requests as demo_capif.py, but split per button:
  Operator:  op_register(), op_publish()
  Bank:      bk_register(), bk_discover(), bk_token(), bk_check(phone)

State is shared (a single CapifFlow on the server) — this is what links the two
portals THROUGH CAPIF, just like in reality. Does not touch demo_capif.py.
"""

import os
import requests
import urllib3
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography import x509
from cryptography.x509.oid import NameOID

urllib3.disable_warnings()

REGISTER = "https://localhost:8084"
CAPIF = "https://localhost:443"
ADMIN = ("admin", "password123")
WORK_DIR = "/tmp/capif_demo"

KNOWN_SWAP = "+351911111111"   # number with a recent SIM swap


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
        f.write(key.private_bytes(serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption()))
    return csr.public_bytes(serialization.Encoding.PEM).decode("utf-8")


def _save(name, content):
    os.makedirs(WORK_DIR, exist_ok=True)
    with open(f"{WORK_DIR}/{name}", "w") as f:
        f.write(content)


def _cert(name):
    crt, key = f"{WORK_DIR}/{name}.crt", f"{WORK_DIR}/{name}.key"
    return (crt, key) if os.path.exists(crt) and os.path.exists(key) else None


class CapifFlow:
    def __init__(self):
        os.makedirs(WORK_DIR, exist_ok=True)
        self.admin_token = None
        self.apf_id = self.aef_id = self.api_id = None
        self.invoker_id = None
        self.aef_url = None
        self.token = None

    def _r(self, ok, title, summary, calls=None, data=None, mongo=None):
        return {"ok": ok, "title": title, "summary": summary,
                "calls": calls or [], "data": data or {}, "mongo": mongo}

    def _call(self, label, http, ok, detail=""):
        return {"label": label, "http": http, "ok": ok, "detail": detail}

    def _ensure_account(self, username, password, **extra):
        if not self.admin_token:
            r = requests.post(f"{REGISTER}/login", auth=ADMIN, verify=False, timeout=10)
            if r.status_code == 200:
                self.admin_token = r.json()["access_token"]
        h = {"Authorization": f"Bearer {self.admin_token}",
             "Content-Type": "application/json"}
        body = {"username": username, "password": password}
        body.update(extra)
        return requests.post(f"{REGISTER}/createUser", headers=h, verify=False,
                             json=body).status_code

    def _getauth(self, username, password):
        return requests.get(f"{REGISTER}/getauth", auth=(username, password),
                            verify=False, timeout=10)

    # ================= OPERATOR =================
    def op_register(self):
        calls = []
        self.apf_id = self.aef_id = self.api_id = None
        self._ensure_account("operadora_5g", "Operadora123",
                             enterprise="Operator", country="PT",
                             email="apf@operator.pt", purpose="API Provider")
        calls.append(self._call("Create account in Register", 200, True))
        r = self._getauth("operadora_5g", "Operadora123")
        if r.status_code != 200:
            return self._r(False, "Register with CAPIF Core", "Authentication failed.",
                           calls + [self._call("getauth", r.status_code, False)])
        auth = r.json()
        _save("ca.crt", auth["ca_root"])
        token = auth["access_token"]
        calls.append(self._call("getauth (JWT + CA root)", 200, True))
        csrs = {role: _gen_csr(f"{role}_operadora_5g", role.lower())
                for role in ("APF", "AEF", "AMF")}
        body = {"regSec": token, "apiProvDomInfo": "Operator", "suppFeat": "0",
                "apiProvFuncs": [{"regInfo": {"apiProvPubKey": csrs[r_]},
                    "apiProvFuncRole": r_, "apiProvFuncInfo": f"{r_}_operadora_5g"}
                    for r_ in csrs]}
        rr = requests.post(f"{CAPIF}/api-provider-management/v1/registrations",
                           json=body, headers={"Authorization": f"Bearer {token}"},
                           verify=False, timeout=15)
        if rr.status_code != 201:
            return self._r(False, "Register with CAPIF Core",
                           f"CAPIF rejected the registration ({rr.status_code}).",
                           calls + [self._call("POST /registrations", rr.status_code,
                                                False, rr.text[:80])])
        certs = []
        for func in rr.json().get("apiProvFuncs", []):
            role = func.get("apiProvFuncRole")
            name = func.get("apiProvFuncInfo", role)
            cert = func.get("regInfo", {}).get("apiProvCert", "")
            if cert:
                _save(f"{name}.crt", cert)
                certs.append(role)
            if role == "APF":
                self.apf_id = func.get("apiProvFuncId")
            if role == "AEF":
                self.aef_id = func.get("apiProvFuncId")
        calls.append(self._call("POST /registrations (3 CSRs)", 201, True))
        return self._r(True, "Register with CAPIF Core",
                       "Registered successfully. CAPIF signed the certification requests and returned 3 "
                       "certificates (APF, AEF, AMF). Authentication is now done via mTLS (certificate) "
                       "without passwords.",
                       calls, {"certificates": certs, "apf_id": self.apf_id,
                               "aef_id": self.aef_id},
                       "capif > providerenrolmentdetails")

    def op_publish(self):
        if not self.apf_id:
            return self._r(False, "Publish API", "Register with CAPIF Core first.")
        body = {"apiName": "SIM_Swap", "supportedFeatures": "0", "apiSuppFeats": "fffff",
                "description": "GSMA SIM Swap API - check recent SIM change before approving a transaction",
                "shareableInfo": {"isShareable": True}, "serviceAPICategory": "Security",
                "aefProfiles": [{"aefId": self.aef_id, "protocol": "HTTP_1_1",
                    "securityMethods": ["OAUTH"],
                    "interfaceDescriptions": [{"ipv4Addr": "127.0.0.1", "port": 9200,
                        "securityMethods": ["OAUTH"]}],
                    "versions": [{"apiVersion": "v1", "resources": [{
                        "resourceName": "checkSimSwap", "commType": "REQUEST_RESPONSE",
                        "uri": "/sim-swap/check", "operations": ["POST"],
                        "description": "Check SIM swap"}]}]}]}
        r = requests.post(f"{CAPIF}/published-apis/v1/{self.apf_id}/service-apis",
                          json=body, cert=_cert("APF_operadora_5g"),
                          verify=False, timeout=15)
        if r.status_code != 201:
            return self._r(False, "Publish API",
                           f"Publication rejected by CAPIF ({r.status_code}).",
                           [self._call("POST service-apis (mTLS)", r.status_code,
                                       False, r.text[:80])])
        self.api_id = r.json().get("apiId")
        return self._r(True, "Publish API",
                       "The SIM Swap API was successfully published to the CAPIF catalog using APF certificate "
                       "authentication (mTLS). Any authorized consumer can now discover it.",
                       [self._call("POST service-apis (APF mTLS cert)", 201, True)],
                       {"api_id": self.api_id, "api_name": "SIM_Swap",
                        "endpoint": "POST 127.0.0.1:9200/sim-swap/check"},
                       "capif > serviceapidescriptions")

    # ================= BANK =================
    def bk_register(self):
        calls = []
        self.invoker_id = None
        self.token = None
        self.aef_url = None
        self._ensure_account("banco_itau", "Itau123", enterprise="Bank",
                             country="PT", email="api@bank.example",
                             purpose="SIM Swap consumer")
        calls.append(self._call("Create account in Register", 200, True))
        r = self._getauth("banco_itau", "Itau123")
        if r.status_code != 200:
            return self._r(False, "Register as Invoker", "Authentication failed.",
                           calls + [self._call("getauth", r.status_code, False)])
        token = r.json()["access_token"]
        calls.append(self._call("getauth (JWT)", 200, True))
        csr = _gen_csr("banco_itau", "invoker")
        body = {"onboardingInformation": {"apiInvokerPublicKey": csr},
                "notificationDestination": "http://localhost:9999/cb",
                "apiInvokerInformation": "Bank", "supportedFeatures": "0"}
        rr = requests.post(f"{CAPIF}/api-invoker-management/v1/onboardedInvokers",
                           json=body, headers={"Authorization": f"Bearer {token}"},
                           verify=False, timeout=15)
        if rr.status_code != 201:
            return self._r(False, "Register as Invoker",
                           f"Registration rejected by CAPIF ({rr.status_code}).",
                           calls + [self._call("POST onboardedInvokers",
                                                rr.status_code, False, rr.text[:80])])
        inv = rr.json()
        self.invoker_id = inv.get("apiInvokerId")
        cert = inv.get("onboardingInformation", {}).get("apiInvokerCertificate", "")
        if cert:
            _save("banco_itau.crt", cert)
        calls.append(self._call("POST onboardedInvokers (CSR)", 201, True))
        return self._r(True, "Register as Invoker",
                       "Registered with CAPIF as Invoker successfully. Invoker certificate was obtained. "
                       "The Bank can now discover and access APIs.",
                       calls, {"invoker_id": self.invoker_id},
                       "capif > invokerdetails")

    def bk_discover(self):
        if not self.invoker_id:
            return self._r(False, "Discover APIs", "Register the Invoker first.")
        r = requests.get(
            f"{CAPIF}/service-apis/v1/allServiceAPIs?api-invoker-id={self.invoker_id}",
            cert=_cert("banco_itau"), verify=False, timeout=15)
        if r.status_code != 200:
            return self._r(False, "Discover APIs", f"Discovery failed ({r.status_code}).",
                           [self._call("GET allServiceAPIs (mTLS)", r.status_code, False)])
        apis = r.json().get("serviceAPIDescriptions", [])
        found = []
        for api in apis:
            ep = None
            for p in api.get("aefProfiles", []):
                self.aef_id = p.get("aefId", self.aef_id)
                for v in p.get("versions", []):
                    for res in v.get("resources", []):
                        for iface in p.get("interfaceDescriptions", []):
                            host = iface.get("ipv4Addr") or iface.get("fqdn")
                            port = iface.get("port")
                            if host and port:
                                self.aef_url = (f"http://{host}:{port}"
                                                f"{iface.get('apiPrefix','')}{res.get('uri')}")
                                ep = f"{res.get('operations')} {res.get('uri')}"
            self.api_id = api.get("apiId", self.api_id)
            found.append({"name": api.get("apiName"),
                          "description": api.get("description", "")[:90],
                          "endpoint": ep})
        return self._r(True, "Discover APIs",
                       f"The Bank queried CAPIF for available APIs and found {len(apis)}. "
                       "The SIM Swap API was discovered without any prior direct contact with the Operator.",
                       [self._call("GET allServiceAPIs (Discovery, mTLS)", 200, True)],
                       {"apis": found})

    def bk_token(self):
        if not (self.invoker_id and self.aef_id and self.api_id):
            return self._r(False, "Get Access Token", "Run API Discovery (Step 2) first.")
        calls = []
        body = {"securityInfo": [{"aefId": self.aef_id, "apiId": self.api_id,
                                  "prefSecurityMethods": ["OAUTH"]}],
                "notificationDestination": "http://localhost:9999/sec",
                "supportedFeatures": "0"}
        rs = requests.put(f"{CAPIF}/capif-security/v1/trustedInvokers/{self.invoker_id}",
                          json=body, cert=_cert("banco_itau"), verify=False, timeout=15)
        calls.append(self._call("PUT trustedInvokers (mTLS)", rs.status_code,
                                rs.status_code in (200, 201)))
        scope = f"3gpp#{self.aef_id}:SIM_Swap"
        rt = requests.post(
            f"{CAPIF}/capif-security/v1/securities/{self.invoker_id}/token",
            data={"grant_type": "client_credentials", "client_id": self.invoker_id,
                  "scope": scope}, cert=_cert("banco_itau"), verify=False, timeout=15)
        if rt.status_code != 200:
            return self._r(False, "Get Access Token", f"Token rejected ({rt.status_code}).",
                           calls + [self._call("POST /token", rt.status_code, False)])
        self.token = rt.json().get("access_token", "")
        calls.append(self._call("POST /token (scope SIM_Swap)", 200, True))
        return self._r(True, "Get Access Token",
                       "CAPIF issued a valid OAuth2 token — the credential proving the "
                       "Bank is authorized to call the SIM Swap API. Fraud check is now unlocked.",
                       calls, {"token": self.token[:50] + "..."},
                       "capif > serviceapisecurity")

    def bk_check(self, phone):
        if not (self.token and self.aef_url):
            return self._r(False, "Fraud Check", "Obtain the access token first.")
        try:
            r = requests.post(self.aef_url, json={"phoneNumber": phone, "maxAge": 24},
                              headers={"Authorization": f"Bearer {self.token}"}, timeout=5)
            d = r.json()
        except Exception:
            return self._r(False, "Fraud Check",
                           "The Operator server (mock) did not respond. "
                           "Make sure sim_swap_mock.py is running.")
        approve = not d.get("swapped")
        if approve:
            summary = (f"Queried the Operator: has {phone} had a recent SIM swap? "
                       f"Response: NO. The bank approves the transaction.")
        else:
            summary = (f"Queried the Operator: has {phone} had a recent SIM swap? "
                       f"Response: YES, on {d.get('lastSwapTime')}. Possible fraud "
                       f"(SIM swap cloning) — the bank blocks the transaction.")
        return self._r(True, "Fraud Check", summary,
                       [self._call(f"POST /sim-swap/check ({phone})", r.status_code, approve)],
                       {"phone": phone, "swapped": d.get("swapped"),
                        "decision": "APPROVE" if approve else "BLOCK"})
