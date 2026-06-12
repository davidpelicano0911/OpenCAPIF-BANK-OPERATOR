from functools import wraps

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import bad_request_error, unauthorized_error
from published_apis.models.problem_details import ProblemDetails  # noqa: E501
from published_apis.vendor_specific import (find_attribute_in_body,
                                            vendor_specific_key_n_value)

from ..core.responses import bad_request_error
from ..core.serviceapidescriptions import (PublishServiceOperations,
                                           return_negotiated_supp_feat_dict)
from ..core.validate_user import ControlAccess
from ..models.service_api_description import \
    ServiceAPIDescription  # noqa: E501

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
def apf_id_service_apis_get(apf_id):  # noqa: E501
    """apf_id_service_apis_get

    Retrieve all published APIs. # noqa: E501

    :param apf_id: 
    :type apf_id: str

    :rtype: Union[List[ServiceAPIDescription], Tuple[List[ServiceAPIDescription], int], Tuple[List[ServiceAPIDescription], int, Dict[str, str]]
    """
    current_app.logger.debug("Obtainig all service published")
    res = service_operations.get_serviceapis(apf_id)

    return res

@cert_validation()
def apf_id_service_apis_post(apf_id, body):  # noqa: E501
    """apf_id_service_apis_post

    Publish a new API. # noqa: E501

    :param apf_id: 
    :type apf_id: str
    :param service_api_description: 
    :type service_api_description: dict | bytes

    :rtype: Union[ServiceAPIDescription, Tuple[ServiceAPIDescription, int], Tuple[ServiceAPIDescription, int, Dict[str, str]]
    """
    current_app.logger.debug("Publishing service")

    if 'supportedFeatures' not in body:
        return bad_request_error(
            detail="supportedFeatures not present in request",
            cause="supportedFeatures not present",
            invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
        )

    supp_feat_dict = return_negotiated_supp_feat_dict(
        body['supportedFeatures'])

    vendor_specific = []
    vendor_specific_fields = find_attribute_in_body(body, '')

    if supp_feat_dict['VendorExt'] ^ bool(vendor_specific_fields):
        return bad_request_error(
            detail="If and only if VendorExt feature is enabled, then vendor-specific fields should be defined",
            cause="Vendor extensibility misconfiguration",
            invalid_params=[{"param": "vendor extensibility", "reason": "wrong definition"}]
        )

    if request.is_json:
        if supp_feat_dict['VendorExt']:
            vendor_specific = vendor_specific_key_n_value(vendor_specific_fields, body)
        body = ServiceAPIDescription.from_dict(request.get_json())

    res = service_operations.add_serviceapidescription(
        apf_id, body, vendor_specific)

    return res

@cert_validation()
def apf_id_service_apis_service_api_id_delete(service_api_id, apf_id):  # noqa: E501
    """apf_id_service_apis_service_api_id_delete

    Unpublish a published service API. # noqa: E501

    :param service_api_id: 
    :type service_api_id: str
    :param apf_id: 
    :type apf_id: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    current_app.logger.debug("Removing service published")
    res = service_operations.delete_serviceapidescription(
        service_api_id, apf_id)

    return res

@cert_validation()
def apf_id_service_apis_service_api_id_get(service_api_id, apf_id):  # noqa: E501
    """apf_id_service_apis_service_api_id_get

    Retrieve a published service API. # noqa: E501

    :param service_api_id: 
    :type service_api_id: str
    :param apf_id: 
    :type apf_id: str

    :rtype: Union[ServiceAPIDescription, Tuple[ServiceAPIDescription, int], Tuple[ServiceAPIDescription, int, Dict[str, str]]
    """
    current_app.logger.debug("Obtaining service api with id: " + service_api_id)
    res = service_operations.get_one_serviceapi(service_api_id, apf_id)

    return res

@cert_validation()
def apf_id_service_apis_service_api_id_put(service_api_id, apf_id, body):  # noqa: E501
    """apf_id_service_apis_service_api_id_put

    Update a published service API. # noqa: E501

    :param service_api_id: 
    :type service_api_id: str
    :param apf_id: 
    :type apf_id: str
    :param service_api_description: 
    :type service_api_description: dict | bytes

    :rtype: Union[ServiceAPIDescription, Tuple[ServiceAPIDescription, int], Tuple[ServiceAPIDescription, int, Dict[str, str]]
    """
    current_app.logger.debug(
        "Updating service api id with id: " + service_api_id)

    if 'supportedFeatures' not in body:
        return bad_request_error(
            detail="supportedFeatures not present in request",
            cause="supportedFeatures not present",
            invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
        )

    if request.is_json:
        body = ServiceAPIDescription.from_dict(request.get_json())  # noqa: E501

    response = service_operations.update_serviceapidescription(
        service_api_id, apf_id, body)

    return response
