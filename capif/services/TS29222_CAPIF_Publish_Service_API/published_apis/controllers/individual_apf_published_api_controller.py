from functools import wraps

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import unauthorized_error
from published_apis.models.service_api_description_patch import \
    ServiceAPIDescriptionPatch  # noqa: E501

from ..core.serviceapidescriptions import PublishServiceOperations
from ..core.validate_user import ControlAccess

service_operations = PublishServiceOperations()
valid_user = ControlAccess()

def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):

            args = request.view_args
            cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            
            if not cert_tmp:
                return unauthorized_error("Client certificate required", "X-Ssl-Client-Cert header is missing")
            
            cert_raw = cert_tmp.replace('\t', '')

            cert = x509.load_pem_x509_certificate(
                str.encode(cert_raw), default_backend())

            cn = cert.subject.get_attributes_for_oid(
                x509.OID_COMMON_NAME)[0].value.strip()

            if cn != "superadmin":
                cert_signature = cert.signature.hex()
                service_api_id = None
                if 'serviceApiId' in args:
                    service_api_id = args["serviceApiId"]
                result = valid_user.validate_user_cert(
                    args["apfId"], cert_signature, service_api_id)

                if result is not None:
                    return result

                result = service_operations.check_apf(args["apfId"])

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def modify_ind_apf_pub_api(service_api_id, apf_id, body):  # noqa: E501
    """modify_ind_apf_pub_api

    Modify an existing published service API. # noqa: E501

    :param service_api_id: 
    :type service_api_id: str
    :param apf_id: 
    :type apf_id: str
    :param service_api_description_patch: 
    :type service_api_description_patch: dict | bytes

    :rtype: Union[ServiceAPIDescription, Tuple[ServiceAPIDescription, int], Tuple[ServiceAPIDescription, int, Dict[str, str]]
    """
    current_app.logger.debug(
        "Patching service api id with id: " + service_api_id)
    if request.is_json:
        body = ServiceAPIDescriptionPatch.from_dict(request.get_json())  # noqa: E501

    response = service_operations.patch_serviceapidescription(
        service_api_id, apf_id, body)
    
    return response
