from functools import wraps
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import request
import connexion
#from ..core.validate_user import ControlAccess

from visibility_control.core.validate_user import ControlAccess
valid_user = ControlAccess()

def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):
            # 1. Get certificate header safely
            # cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            cert_tmp = request.headers.get('X-Ssl-Client-Cert') or request.headers.get('X-SSL-Client-Cert') or request.headers.get('x-ssl-client-cert')
            
            if not cert_tmp:
                return {"title": "Unauthorized", "detail": "Certificate header missing"}, 401

            try:
                # 2. Process certificate
                # cert_raw = cert_tmp.replace('\\t', '')
                cert_raw = cert_tmp.replace('\\t', '').replace('\\n', '\n').replace('\\\\n', '\n').replace('\"', '')
                cert = x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())
                cn = cert.subject.get_attributes_for_oid(x509.OID_COMMON_NAME)[0].value.strip()

                # 3. Store identity for the Core logic
                request.user_cn = cn
                request.cert_signature = cert.signature.hex()

                return f(**kwargs)
            except Exception:
                return {"title": "Unauthorized", "detail": "Invalid certificate format"}, 401
        return __cert_validation
    return _cert_validation

