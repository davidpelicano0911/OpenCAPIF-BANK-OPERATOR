from functools import wraps

from capif_security.models.res_owner_id import ResOwnerId  # noqa: E501
from capif_security.models.security_notification import \
    SecurityNotification  # noqa: E501
from capif_security.models.service_security import \
    ServiceSecurity  # noqa: E501
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import unauthorized_error

from ..core.publisher import Publisher
from ..core.redis_internal_event import RedisInternalEvent
from ..core.servicesecurity import SecurityOperations
from ..core.validate_user import ControlAccess

service_security_ops = SecurityOperations()
publish_ops = Publisher()

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
            current_app.logger.debug(f"CN: {cn}")
            if cn != "superadmin" and "AEF" not in cn:
                cert_signature = cert.signature.hex()

                if "securityId" in args:
                    result = valid_user.validate_user_cert(
                        args["securityId"], cert_signature)
                else:
                    result = valid_user.validate_user_cert(
                        args["apiInvokerId"], cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def securities_security_id_token_post(security_id, body):  # noqa: E501
    """securities_security_id_token_post

     # noqa: E501

    :param security_id: Identifier of an individual API invoker
    :type security_id: str
    :param grant_type: 
    :type grant_type: str
    :param client_id: 
    :type client_id: str
    :param res_owner_id: 
    :type res_owner_id: dict | bytes
    :param client_secret: 
    :type client_secret: str
    :param scope: 
    :type scope: str
    :param auth_code: 
    :type auth_code: str
    :param redirect_uri: 
    :type redirect_uri: str

    :rtype: Union[AccessTokenRsp, Tuple[AccessTokenRsp, int], Tuple[AccessTokenRsp, int, Dict[str, str]]
    """
    current_app.logger.debug("Creating security token")
    if request.is_json:
        res_owner_id = ResOwnerId.from_dict(request.get_json())  # noqa: E501

    # body={"security_id": security_id,
    #       "grant_type": grant_type,
    #       "client_id": client_id,
    #       "res_owner_id": res_owner_id,
    #       "client_secret": client_secret,
    #       "scope": scope,
    #       "auth_code": auth_code,
    #       "redirect_uri": redirect_uri
    #     }
    current_app.logger.debug(body)

    res = service_security_ops.return_token(security_id, body)

    return res

@cert_validation()
def trusted_invokers_api_invoker_id_delete(api_invoker_id):  # noqa: E501
    """trusted_invokers_api_invoker_id_delete

     # noqa: E501

    :param api_invoker_id: Identifier of an individual API invoker
    :type api_invoker_id: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    current_app.logger.debug("Removing security context")
    return service_security_ops.delete_servicesecurity(api_invoker_id)


@cert_validation()
def trusted_invokers_api_invoker_id_delete_post(api_invoker_id, body):  # noqa: E501
    """trusted_invokers_api_invoker_id_delete_post

     # noqa: E501

    :param api_invoker_id: Identifier of an individual API invoker
    :type api_invoker_id: str
    :param security_notification: Revoke the authorization of the API invoker for APIs.
    :type security_notification: dict | bytes

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    if request.is_json:
        body = SecurityNotification.from_dict(request.get_json())  # noqa: E501

    current_app.logger.debug("Revoking permissions")
    res = service_security_ops.revoke_api_authorization(api_invoker_id, body)

    return res

@cert_validation()
def trusted_invokers_api_invoker_id_get(api_invoker_id, authentication_info=None, authorization_info=None):  # noqa: E501
    """trusted_invokers_api_invoker_id_get

     # noqa: E501

    :param api_invoker_id: Identifier of an individual API invoker
    :type api_invoker_id: str
    :param authentication_info: When set to &#39;true&#39;, it indicates the CAPIF core function to send the authentication information of the API invoker. Set to false or omitted otherwise. 
    :type authentication_info: bool
    :param authorization_info: When set to &#39;true&#39;, it indicates the CAPIF core function to send the authorization information of the API invoker. Set to false or omitted otherwise. 
    :type authorization_info: bool

    :rtype: Union[ServiceSecurity, Tuple[ServiceSecurity, int], Tuple[ServiceSecurity, int, Dict[str, str]]
    """
    current_app.logger.debug("Obtaining security context")
    res = service_security_ops.get_servicesecurity(
        api_invoker_id, authentication_info, authorization_info)

    return res

@cert_validation()
def trusted_invokers_api_invoker_id_put(api_invoker_id, body):  # noqa: E501
    """trusted_invokers_api_invoker_id_put

     # noqa: E501

    :param api_invoker_id: Identifier of an individual API invoker
    :type api_invoker_id: str
    :param service_security: create a security context for an API invoker
    :type service_security: dict | bytes

    :rtype: Union[ServiceSecurity, Tuple[ServiceSecurity, int], Tuple[ServiceSecurity, int, Dict[str, str]]
    """
    current_app.logger.debug("Creating security context")

    if request.is_json:
        body = ServiceSecurity.from_dict(request.get_json())  # noqa: E501
    res = service_security_ops.create_servicesecurity(api_invoker_id, body)

    if res.status_code == 201:
        for service_instance in body.security_info:
            if service_instance.api_id is not None:
                RedisInternalEvent("SECURITY-CONTEXT-CREATED",
                                   "securityIds",
                                   {
                                       "api_invoker_id": api_invoker_id,
                                       "api_id": service_instance.api_id
                                   }).send_event()

    return res

@cert_validation()
def trusted_invokers_api_invoker_id_update_post(api_invoker_id, body):  # noqa: E501
    """trusted_invokers_api_invoker_id_update_post

     # noqa: E501

    :param api_invoker_id: Identifier of an individual API invoker
    :type api_invoker_id: str
    :param service_security: Update the security context (e.g. re-negotiate the security methods).
    :type service_security: dict | bytes

    :rtype: Union[ServiceSecurity, Tuple[ServiceSecurity, int], Tuple[ServiceSecurity, int, Dict[str, str]]
    """
    current_app.logger.debug("Updating security context")

    if request.is_json:
        body = ServiceSecurity.from_dict(request.get_json())  # noqa: E501
    res = service_security_ops.update_servicesecurity(api_invoker_id, body)
    return res
