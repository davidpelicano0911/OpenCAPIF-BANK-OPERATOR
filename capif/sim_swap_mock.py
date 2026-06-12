#!/usr/bin/env python3
"""
SIM Swap AEF Mock — servidor da Operadora 5G (API Exposing Function)

Representa o servidor REAL da Operadora que expõe a SIM Swap API.
Numa implementação 3GPP completa, o tráfego passaria pelo CAPIF.
Mas o OpenCAPIF (community/ETSI OSG) só implementa o plano de GESTÃO
(onboarding, discovery, emissão de tokens) — NÃO faz proxy de tráfego.

Por isso o Invoker chama o AEF diretamente, e é o AEF que valida o
token OAuth2 emitido pelo CAPIF. É exatamente isso que este mock faz.

Usa só a biblioteca padrão do Python — não precisa de instalar nada.

Correr:  python3 sim_swap_mock.py
Escuta:  http://0.0.0.0:9200/sim-swap/check
"""

import base64
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

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


def decode_jwt_payload(token):
    """Descodifica o payload de um JWT (sem verificar a assinatura).

    Numa Operadora real, o AEF verificaria a ASSINATURA do token contra
    a chave pública do CAPIF. Aqui descodificamos para mostrar os claims
    e validar o scope — suficiente para demonstrar o controlo de acesso.
    """
    try:
        partes = token.split(".")
        if len(partes) != 3:
            return None
        payload_b64 = partes[1]
        # Repor o padding base64url que o JWT remove
        payload_b64 += "=" * (-len(payload_b64) % 4)
        payload = base64.urlsafe_b64decode(payload_b64)
        return json.loads(payload)
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
