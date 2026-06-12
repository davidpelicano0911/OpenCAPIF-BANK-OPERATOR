def sign_csr_body(username, public_key):
    data = {
        "csr":  public_key.decode("utf-8"),
        "mode":  "client",
        "filename": username
    }
    return data


def vault_sign_superadmin_certificate_body(csr_request):
    data = {
        "format": "pem_bundle",
        "ttl": "43000h",
        "csr": csr_request.decode("utf-8"),
        "common_name": "superadmin"
    }
    return data
