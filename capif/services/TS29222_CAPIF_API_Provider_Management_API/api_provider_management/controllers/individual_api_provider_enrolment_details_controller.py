from functools import wraps
from flask import current_app, request
from cryptography import x509
from cryptography.hazmat.backends import default_backend

from ..core.responses import unauthorized_error

from ..core.provider_enrolment_details_api import ProviderManagementOperations
from ..core.validate_user import ControlAccess
from ..models.api_provider_enrolment_details_patch import \
        APIProviderEnrolmentDetailsPatch  # noqa: E501

provider_management_ops = ProviderManagementOperations()
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

            cert = x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())

            cn = cert.subject.get_attributes_for_oid(x509.OID_COMMON_NAME)[0].value.strip()

            if cn != "superadmin":
                cert_signature = cert.signature.hex()
                result = valid_user.validate_user_cert(args["registrationId"], cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def modify_ind_api_provider_enrolment(registration_id, body):  # noqa: E501
    """modify_ind_api_provider_enrolment

    Modify an individual API provider details. # noqa: E501

    :param registration_id: 
    :type registration_id: str
    :param api_provider_enrolment_details_patch: 
    :type api_provider_enrolment_details_patch: dict | bytes

    :rtype: Union[APIProviderEnrolmentDetails, Tuple[APIProviderEnrolmentDetails, int], Tuple[APIProviderEnrolmentDetails, int, Dict[str, str]]
    """
    current_app.logger.debug("Patch Provider Domain")
    if request.is_json:
        body = APIProviderEnrolmentDetailsPatch.from_dict(request.get_json())  # noqa: E501

    res = provider_management_ops.patch_api_provider_enrolment_details(registration_id, body)

    return res
