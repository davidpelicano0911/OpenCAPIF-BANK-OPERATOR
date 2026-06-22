#!/usr/bin/env python3
"""
verify_signature_debug.py — Mostra, byte a byte, a verificação de uma ASSINATURA
de certificado: revela os DOIS hashes que são comparados.

  - hash A: calculado por NÓS a partir do conteúdo do certificado
  - hash B: "aberto" da assinatura usando a chave pública do CA (RSA cru)
  Se A == B -> assinatura válida (conteúdo intacto + foi mesmo o CA).

MODO REAL:   se o capifcore:443 responder E existir /tmp/capif_demo/ca.crt,
             usa o certificado verdadeiro do nginx.
MODO LOCAL:  caso contrário, gera um mini-CA + certificado próprios e demonstra
             a MESMA matemática (corre sempre, sem precisar do Docker).

Correr:  python3 capif/web_demo/verify_signature_debug.py
"""

import datetime
import hashlib
import os
import ssl
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa

HOST, PORT = "capifcore", 443
CA = "/tmp/capif_demo/ca.crt"


def get_real():
    """Tenta obter (leaf, public_key_do_CA) reais do CAPIF. Devolve None se não der."""
    if not os.path.exists(CA):
        return None
    try:
        leaf = x509.load_pem_x509_certificate(
            ssl.get_server_certificate((HOST, PORT)).encode())
        ca = x509.load_pem_x509_certificate(open(CA, "rb").read())
        return leaf, ca.public_key(), "REAL (certificado do capifcore + ca.crt)"
    except Exception:
        return None


def make_local():
    """Gera um mini-CA e um certificado 'servidor' assinado por ele (autossuficiente)."""
    # 1) chave do CA + certificado autoassinado do CA
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "demo CA")])
    now = datetime.datetime.now(datetime.timezone.utc)
    ca_cert = (x509.CertificateBuilder()
               .subject_name(ca_name).issuer_name(ca_name)
               .public_key(ca_key.public_key())
               .serial_number(x509.random_serial_number())
               .not_valid_before(now).not_valid_after(now + datetime.timedelta(days=1))
               .add_extension(x509.BasicConstraints(ca=True, path_length=None), True)
               .sign(ca_key, hashes.SHA256()))
    # 2) chave do 'servidor' + certificado ASSINADO PELO CA
    srv_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    srv_cert = (x509.CertificateBuilder()
                .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "demo-server")]))
                .issuer_name(ca_name)                       # emitido pelo CA
                .public_key(srv_key.public_key())
                .serial_number(x509.random_serial_number())
                .not_valid_before(now).not_valid_after(now + datetime.timedelta(days=1))
                .sign(ca_key, hashes.SHA256()))             # << ASSINA com a chave do CA
    return srv_cert, ca_cert.public_key(), "LOCAL (mini-CA gerado agora — mesma matemática)"


real = get_real()
leaf, ca_pub, modo = real if real else make_local()

print("=" * 70)
print(f"  MODO: {modo}")
print(f"  Certificado a verificar : {leaf.subject.rfc4514_string()}")
print(f"  Assinado por (issuer)   : {leaf.issuer.rfc4514_string()}")
print(f"  Algoritmo               : {leaf.signature_hash_algorithm.name}")
print("=" * 70)

# Os 3 ingredientes
assinatura = leaf.signature                # a ASSINATURA (posta pelo CA)
conteudo   = leaf.tbs_certificate_bytes    # o CONTEÚDO assinado (tbsCertificate)
nums = ca_pub.public_numbers()
n, e = nums.n, nums.e                        # chave pública do CA: módulo n, expoente e

print(f"\n  Assinatura : {len(assinatura)} bytes")
print(f"  Conteúdo   : {len(conteudo)} bytes (nome, chave pública, validade, ...)")
print(f"  Chave pub. : RSA {n.bit_length()} bits, e={e}")

# HASH A — calculado POR NÓS do conteúdo
hash_A = hashlib.sha256(conteudo).digest()

# HASH B — "abrir" a assinatura com a chave pública: m = assinatura^e mod n
k = (n.bit_length() + 7) // 8
recuperado = pow(int.from_bytes(assinatura, "big"), e, n).to_bytes(k, "big")
# Formato PKCS#1 v1.5:  00 01 FF...FF 00 || DigestInfo || hash(32 bytes)
hash_B = recuperado[-32:]

print("\n  --- Bloco recuperado da assinatura (PKCS#1 v1.5) ---")
print(f"  início: {recuperado[:5].hex()}...   (00 01 ff ff = padding)")
print(f"  fim   : ...{recuperado[-37:].hex()}")
print("          (os últimos 32 bytes = o hash que o CA assinou)")

print("\n  ===================== A COMPARAÇÃO =====================")
print(f"  hash A (nós, do conteúdo)      : {hash_A.hex()}")
print(f"  hash B (aberto da assinatura)  : {hash_B.hex()}")
print(f"\n  hash A == hash B ?  ->  {hash_A == hash_B}")
print("  ✅ IGUAIS -> assinatura VÁLIDA" if hash_A == hash_B
      else "  ❌ DIFERENTES -> INVÁLIDA")

# Confirmação com a biblioteca (faz isto tudo internamente)
try:
    ca_pub.verify(assinatura, conteudo, padding.PKCS1v15(), hashes.SHA256())
    print("\n  cryptography.verify(): OK (sem exceção) ✅")
except Exception as ex:
    print(f"\n  cryptography.verify() FALHOU: {ex} ❌")

# PROVA: mexer 1 byte no conteúdo faz o hash A mudar -> deixa de bater
adulterado = bytearray(conteudo); adulterado[10] ^= 0x01
hash_A2 = hashlib.sha256(bytes(adulterado)).digest()
print("\n  --- Prova: e se adulterarem 1 byte do certificado? ---")
print(f"  hash A novo : {hash_A2.hex()[:40]}...")
print(f"  bate com B? -> {hash_A2 == hash_B}  (FALHA, como esperado)")
print("=" * 70)
