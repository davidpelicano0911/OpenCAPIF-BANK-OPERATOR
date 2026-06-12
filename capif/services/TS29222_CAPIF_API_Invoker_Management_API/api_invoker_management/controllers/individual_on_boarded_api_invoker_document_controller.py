from functools import wraps

from api_invoker_management.models.api_invoker_enrolment_details_patch import \
    APIInvokerEnrolmentDetailsPatch  # noqa: E501
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import unauthorized_error

from ..core.apiinvokerenrolmentdetails import InvokerManagementOperations
from ..core.validate_user import ControlAccess
from ..models.api_invoker_enrolment_details import \
    APIInvokerEnrolmentDetails  # noqa: E501

invoker_operations = InvokerManagementOperations()
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
                result = valid_user.validate_user_cert(args["onboardingId"], cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def delete_ind_onboarded_api_invoker(onboarding_id):  # noqa: E501
    """Delete an existing Individual On-boarded API Invoker resource.

    Deletes an existing Individual On-boarded API Invoker. # noqa: E501

    :param onboarding_id: 
    :type onboarding_id: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    current_app.logger.debug("Removing invoker")
    res = invoker_operations.remove_apiinvokerenrolmentdetail(onboarding_id)

    return res

@cert_validation()
def modify_ind_api_invoke_enrolment(onboarding_id, body):  # noqa: E501
    """modify_ind_api_invoke_enrolment

     # noqa: E501

    :param onboarding_id: 
    :type onboarding_id: str
    :param api_invoker_enrolment_details_patch: 
    :type api_invoker_enrolment_details_patch: dict | bytes

    :rtype: Union[APIInvokerEnrolmentDetails, Tuple[APIInvokerEnrolmentDetails, int], Tuple[APIInvokerEnrolmentDetails, int, Dict[str, str]]
    """
    current_app.logger.debug("Updating invoker")
    if request.is_json:
        body = APIInvokerEnrolmentDetailsPatch.from_dict(request.get_json())  # noqa: E501

    res = invoker_operations.patch_apiinvokerenrolmentdetail(onboarding_id, body)

    return res

@cert_validation()
def update_ind_onboarded_api_invoker(onboarding_id, body):  # noqa: E501
    """Update an existing Individual On-boarded API Invoker resource.

     # noqa: E501

    :param onboarding_id: 
    :type onboarding_id: str
    :param api_invoker_enrolment_details: 
    :type api_invoker_enrolment_details: dict | bytes

    :rtype: Union[APIInvokerEnrolmentDetails, Tuple[APIInvokerEnrolmentDetails, int], Tuple[APIInvokerEnrolmentDetails, int, Dict[str, str]]
    """
    current_app.logger.debug("Updating invoker")
    if request.is_json:
        body = APIInvokerEnrolmentDetails.from_dict(request.get_json())  # noqa: E501

    res = invoker_operations.update_apiinvokerenrolmentdetail(onboarding_id,body)

    return res
