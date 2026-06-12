from functools import wraps

from capif_acl.models.access_control_policy_list import \
    AccessControlPolicyList  # noqa: E501
from capif_acl.models.problem_details import ProblemDetails  # noqa: E501
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import unauthorized_error

from ..core.accesscontrolpolicyapi import accessControlPolicyApi


def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):

            request.view_args
            cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            
            if not cert_tmp:
                return unauthorized_error("Client certificate required", "X-Ssl-Client-Cert header is missing")
            
            cert_raw = cert_tmp.replace('\t', '')

            x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())


            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def access_control_policy_list_service_api_id_get(service_api_id, aef_id, api_invoker_id=None, supported_features=None):  # noqa: E501
    """access_control_policy_list_service_api_id_get

    Retrieves the access control policy list. # noqa: E501

    :param service_api_id: Identifier of a published service API
    :type service_api_id: str
    :param aef_id: Identifier of the AEF
    :type aef_id: str
    :param api_invoker_id: Identifier of the API invoker
    :type api_invoker_id: str
    :param supported_features: To filter irrelevant responses related to unsupported features
    :type supported_features: str

    :rtype: Union[AccessControlPolicyList, Tuple[AccessControlPolicyList, int], Tuple[AccessControlPolicyList, int, Dict[str, str]]
    """
    current_app.logger.debug("Obtaining service ACLs")
    return accessControlPolicyApi().get_acl(service_api_id, aef_id, api_invoker_id, supported_features)

