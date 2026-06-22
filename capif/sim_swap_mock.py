#!/usr/bin/env python3
"""
SIM Swap AEF Mock — servidor da Operadora 5G (API Exposing Function)

Representa o servidor REAL da Operadora que expõe a SIM Swap API.
Numa implementação 3GPP completa, o tráfego passaria pelo CAPIF.
Mas o OpenCAPIF (community/ETSI OSG) só implementa o plano de GESTÃO
(onboarding, discovery, emissão de tokens) — NÃO faz proxy de tráfego.

Por isso o Invoker chama o AEF diretamente, e é o AEF que valida o
token OAuth2 emitido pelo CAPIF. É exatamente isso que este mock faz.

O token é validado a sério: a ASSINATURA RS256 é verificada contra a
chave pública do CAPIF (obtida do certificado TLS servido em :443).
Se o CAPIF estiver inacessível, faz fallback para descodificação-só,
para a demo continuar a correr.

Depende de 'cryptography' (já usada no resto do projeto).

Correr:  python3 sim_swap_mock.py
Escuta:  http://0.0.0.0:9200/sim-swap/check
"""

import base64
import json
import socket
import ssl
from http.server import BaseHTTPRequestHandler, HTTPServer

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding

# Nome da API que este AEF expõe — o scope do token tem de o conter
API_NAME = "SIM_Swap"
PORT = 9200

# Histórico (simulado) de trocas de SIM, indexado por número de telefone.
# Numa operadora real, isto viria da base de dados da rede (HLR/HSS).
#   None  = sem troca recente  → SIM intacto, transação segura
#   data  = trocou há pouco     → possível fraude, transação bloqueada
SWAPS = {
    "+351912345678": None,                     # cliente normal — SIM intacto
    "+351911111111": "2026-06-04T10:00:00Z",   # SIM trocado ontem — possível fraude
}


def _b64url(data):
    """Descodifica uma secção base64url de um JWT, repondo o padding removido."""
    data += "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data)


def decode_jwt_payload(token):
    """Descodifica o payload de um JWT (sem verificar a assinatura)."""
    try:
        partes = token.split(".")
        if len(partes) != 3:
            return None
        return json.loads(_b64url(partes[1]))
    except Exception:
        return None


# Cache da chave pública do CAPIF. O token OAuth2 é assinado em RS256 com a
# server.key do nginx do CAPIF; a chave pública correspondente está no
# certificado TLS que o CAPIF serve em :443. Vamos buscá-lo uma vez por TLS.
_CAPIF_PUBKEY = None
_PUBKEY_TRIED = False


def _capif_public_key():
    """Obtém (e cacheia) a chave pública do servidor CAPIF a partir do cert TLS.

    Tenta 'capifcore' e depois 'localhost' na porta 443. Devolve None se não
    conseguir alcançar o CAPIF (a demo continua a funcionar em modo descodifica-só).
    """
    global _CAPIF_PUBKEY, _PUBKEY_TRIED
    if _PUBKEY_TRIED:
        return _CAPIF_PUBKEY
    _PUBKEY_TRIED = True
    for host in ("capifcore", "localhost"):
        try:
            socket.gethostbyname(host)
        except Exception:
            continue
        try:
            pem = ssl.get_server_certificate((host, 443))
            cert = x509.load_pem_x509_certificate(pem.encode("utf-8"))
            _CAPIF_PUBKEY = cert.public_key()
            print(f"  [AEF] chave pública do CAPIF obtida de {host}:443 (verificação de assinatura ON)")
            return _CAPIF_PUBKEY
        except Exception as e:
            print(f"  [AEF] não consegui obter o cert TLS de {host}:443 ({e})")
    print("  [AEF] CAPIF inacessível — verificação de assinatura OFF (apenas descodificação)")
    return None


def verify_jwt_signature(token):
    """Verifica a assinatura RS256 do token contra a chave pública do CAPIF.

    Devolve:
      True  → assinatura válida;
      False → assinatura inválida (token adulterado/forjado) → deve dar 401;
      None  → impossível verificar (CAPIF inacessível ou alg inesperado) → fallback.
    """
    pubkey = _capif_public_key()
    if pubkey is None:
        return None
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
        header = json.loads(_b64url(header_b64))
        if header.get("alg") != "RS256":
            return None
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        pubkey.verify(_b64url(sig_b64), signing_input,
                      padding.PKCS1v15(), hashes.SHA256())
        return True
    except InvalidSignature:
        return False
    except Exception:
        return None


class AEFHandler(BaseHTTPRequestHandler):

    def _responder(self, status, corpo):
        body = json.dumps(corpo).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("  [AEF]", fmt % args)

    def do_GET(self):
        self._responder(200, {
            "service": "SIM Swap AEF (Operadora 5G)",
            "endpoint": "POST /sim-swap/check"
        })

    def do_POST(self):
        if self.path != "/sim-swap/check":
            self._responder(404, {"error": "not_found", "detail": self.path})
            return

        # 1. Sem header Authorization → 401 (controlo de acesso)
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            self._responder(401, {
                "error": "unauthorized",
                "detail": "Falta o token OAuth2 emitido pelo CAPIF"
            })
            return

        token = auth[len("Bearer "):]

        # 2. Token ilegível → 401
        claims = decode_jwt_payload(token)
        if claims is None:
            self._responder(401, {
                "error": "invalid_token",
                "detail": "Token não é um JWT válido"
            })
            return

        # 2b. Verificar a ASSINATURA RS256 contra a chave pública do CAPIF.
        #     None = não foi possível verificar (CAPIF offline) → aceita-se (fallback demo).
        #     False = assinatura inválida (token adulterado/forjado) → 401.
        valid = verify_jwt_signature(token)
        if valid is False:
            print("  [AEF] assinatura INVÁLIDA — token rejeitado")
            self._responder(401, {
                "error": "invalid_token",
                "detail": "Assinatura do token inválida (não foi emitido pelo CAPIF)"
            })
            return

        # 3. O scope do token tem de autorizar ESTA API → senão 403
        scope = claims.get("scope", "")
        if API_NAME not in scope:
            self._responder(403, {
                "error": "insufficient_scope",
                "detail": f"O token não autoriza {API_NAME}. Scope recebido: {scope}"
            })
            return

        # 4. Token válido e com scope correto → executa a lógica da API
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length)) if length else {}
        except Exception:
            body = {}
        phone = body.get("phoneNumber", "desconhecido")

        # Lógica de negócio (simulada): consulta o histórico de trocas de SIM.
        # É isto que dá VALOR à API — o resultado muda a decisão do banco.
        phone_key = phone
        if phone_key and not phone_key.startswith("+") and phone_key != "desconhecido":
            phone_key = "+" + phone_key

        ultima_troca = SWAPS.get(phone_key)
        swapped = ultima_troca is not None
        recomendacao = "BLOQUEAR_TRANSACAO" if swapped else "APROVAR_TRANSACAO"
        if swapped:
            detalhe = f"SIM trocado em {ultima_troca} — risco de fraude, transação bloqueada"
        else:
            detalhe = "Nenhuma troca de SIM nas últimas 24h — transação segura"

        print(f"  [AEF] {phone} | swapped={swapped} | recomendacao={recomendacao} | scope={scope}")

        self._responder(200, {
            "phoneNumber": phone,
            "swapped": swapped,
            "lastSwapTime": ultima_troca,
            "recommendation": recomendacao,
            "detail": detalhe
        })


if __name__ == "__main__":
    print(f"SIM Swap AEF mock a escutar em http://0.0.0.0:{PORT}")
    print(f"  POST /sim-swap/check  (requer header Authorization: Bearer <token CAPIF>)")
    print("  Ctrl+C para parar.")
    HTTPServer(("0.0.0.0", PORT), AEFHandler).serve_forever()
