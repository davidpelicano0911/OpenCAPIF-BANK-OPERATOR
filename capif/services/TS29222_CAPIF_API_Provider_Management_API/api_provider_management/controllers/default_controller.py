from functools import wraps

from api_provider_management.models.api_provider_enrolment_details import \
    APIProviderEnrolmentDetails  # noqa: E501
from api_provider_management.models.problem_details import \
    ProblemDetails  # noqa: E501
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..core.responses import unauthorized_error

from ..core.provider_enrolment_details_api import ProviderManagementOperations
from ..core.validate_user import ControlAccess

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

@jwt_required()
def registrations_post(body):  # noqa: E501
    """registrations_post

    Registers a new API Provider domain with API provider domain functions profiles. # noqa: E501

    :param api_provider_enrolment_details: 
    :type api_provider_enrolment_details: dict | bytes

    :rtype: Union[APIProviderEnrolmentDetails, Tuple[APIProviderEnrolmentDetails, int], Tuple[APIProviderEnrolmentDetails, int, Dict[str, str]]
    """
    identity = get_jwt_identity()
    username, uuid = identity.split()

    current_app.logger.debug("Registering Provider Domain")

    if request.is_json:
        body = APIProviderEnrolmentDetails.from_dict(request.get_json())  # noqa: E501

    res = provider_management_ops.register_api_provider_enrolment_details(body, username, uuid)

    return res

@cert_validation()
def registrations_registration_id_delete(registration_id):  # noqa: E501
    """registrations_registration_id_delete

    Deregisters API provider domain by deleting API provider domain and functions. # noqa: E501

    :param registration_id: String identifying an registered API provider domain resource.
    :type registration_id: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    current_app.logger.debug("Removing Provider Domain")
    res = provider_management_ops.delete_api_provider_enrolment_details(registration_id)

    return res

@cert_validation()
def registrations_registration_id_put(registration_id, body):  # noqa: E501
    """registrations_registration_id_put

    Updates an API provider domain&#39;s registration details. # noqa: E501

    :param registration_id: String identifying an registered API provider domain resource.
    :type registration_id: str
    :param api_provider_enrolment_details: Representation of the API provider domain registration details to be updated in CAPIF core function. 
    :type api_provider_enrolment_details: dict | bytes

    :rtype: Union[APIProviderEnrolmentDetails, Tuple[APIProviderEnrolmentDetails, int], Tuple[APIProviderEnrolmentDetails, int, Dict[str, str]]
    """
    current_app.logger.debug("Updating Provider Domain")

    if request.is_json:
        body = APIProviderEnrolmentDetails.from_dict(request.get_json())  # noqa: E501

    res = provider_management_ops.update_api_provider_enrolment_details(registration_id,body)

    return res
