#!/usr/bin/env python3
"""
verify_tls_demo.py — Mostra, com prints, o "diálogo" TLS entre o teu código e o
nginx (capifcore): o servidor apresenta o certificado e o teu código verifica-o
contra o ca.crt. Isto é o que normalmente acontece ESCONDIDO dentro do
`requests(..., verify=ca.crt)`.

Pré-requisito: ter feito o "Register" na demo pelo menos uma vez, para existir
/tmp/capif_demo/ca.crt. Se não existir, o script avisa.

Correr:  python3 capif/web_demo/verify_tls_demo.py
"""

import os
import socket
import ssl
from cryptography import x509

HOST, PORT = "capifcore", 443
CA = "/tmp/capif_demo/ca.crt"


def diga(quem, msg):
    print(f"\n{quem:8} {msg}")


print("=" * 64)
print("  DEMONSTRAÇÃO: handshake TLS e verificação do certificado CAPIF")
print("=" * 64)

if not os.path.exists(CA):
    print(f"\n[!] Não encontrei {CA}.")
    print("    Faz primeiro o 'Register' no portal da Operadora (gera o ca.crt) e repete.")
    raise SystemExit(1)

# 1) O teu código quer falar com o capifcore
diga("Código:", f'"Olá nginx ({HOST}:{PORT}), quero falar contigo."')

# 2) O servidor apresenta o certificado (buscamos sem validar, só para mostrar)
pem = ssl.get_server_certificate((HOST, PORT))
cert = x509.load_pem_x509_certificate(pem.encode("utf-8"))
nb = getattr(cert, "not_valid_before_utc", None) or cert.not_valid_before
na = getattr(cert, "not_valid_after_utc", None) or cert.not_valid_after

diga("nginx:", '"Olá! Aqui está o meu cartão de identidade:"')
print(f"         - Nome (subject):  {cert.subject.rfc4514_string()}")
print(f"         - Assinado por:    {cert.issuer.rfc4514_string()}")
print(f"         - Válido de:       {nb}")
print(f"         - Válido até:      {na}")

# --------------------------------------------------------------------------
# A validação REAL é feita por UMA linha: ctx.wrap_socket(...). Ela faz o
# handshake TLS e verifica (a) a cadeia contra o ca.crt e (b) o nome (hostname).
# Se algo falhar, LANÇA exceção. Os prints só servem de legenda.
# Abaixo fazemos 3 testes para PROVAR que a verificação é real (e não prints):
#   TESTE 1: ca.crt certo + nome certo   -> deve PASSAR
#   TESTE 2: ca.crt certo + nome ERRADO  -> deve FALHAR (prova a verificação do nome)
#   TESTE 3: SEM o ca.crt + nome certo   -> deve FALHAR (prova a verificação da cadeia)
# --------------------------------------------------------------------------

def tenta_validar(contexto, nome_servidor):
    """Faz a ligação TLS com validação. Devolve (True, versao) ou (False, motivo)."""
    try:
        with socket.create_connection((HOST, PORT), timeout=5) as sock:
            with contexto.wrap_socket(sock, server_hostname=nome_servidor) as ssock:
                return True, ssock.version()
    except ssl.SSLCertVerificationError as e:
        return False, e.verify_message or str(e.reason)
    except ssl.SSLError as e:
        return False, str(e.reason)


diga("Código:", '"Deixa-me verificar este cartão..."')

# TESTE 1 — tudo certo: confia só no ca.crt e usa o nome verdadeiro
ctx_ok = ssl.create_default_context(cafile=CA)
ok, info = tenta_validar(ctx_ok, HOST)
print(f"\n  TESTE 1 (ca.crt certo + nome '{HOST}'):")
print(f"     -> {'PASSOU ✅  TLS=' + info if ok else 'FALHOU ❌  ' + info}")

# TESTE 2 — mesmo ca.crt, mas MENTIMOS no nome -> deve falhar (prova o check do nome)
ok2, info2 = tenta_validar(ctx_ok, "banco-falso.com")
print(f"\n  TESTE 2 (ca.crt certo + nome ERRADO 'banco-falso.com'):")
print(f"     -> {'PASSOU ✅ (mau!)' if ok2 else 'FALHOU ❌  ' + info2}")
print("        => prova que a verificação do NOME é real (não é só um print).")

# TESTE 3 — nome certo, mas SEM o ca.crt -> deve falhar (prova o check da cadeia)
ctx_sem_ca = ssl.create_default_context()   # CAs do sistema, NÃO inclui o do CAPIF
ok3, info3 = tenta_validar(ctx_sem_ca, HOST)
print(f"\n  TESTE 3 (SEM o ca.crt + nome '{HOST}'):")
print(f"     -> {'PASSOU ✅ (mau!)' if ok3 else 'FALHOU ❌  ' + info3}")
print("        => prova que a verificação da ASSINATURA (cadeia) é real.")

print("\n  Conclusão: só o TESTE 1 passa. Mudar o nome OU tirar o ca.crt faz")
print("  a verificação falhar -> logo, há validação a sério, não são só prints.")
print("\n" + "=" * 64)
