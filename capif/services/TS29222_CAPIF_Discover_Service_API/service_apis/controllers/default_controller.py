import json
from functools import wraps

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request
from service_apis.models.aef_location import AefLocation  # noqa: E501
from service_apis.models.communication_type import \
    CommunicationType  # noqa: E501
from service_apis.models.data_format import DataFormat  # noqa: E501
from service_apis.models.discovered_apis import DiscoveredAPIs  # noqa: E501
from service_apis.models.ip_addr_info import IpAddrInfo  # noqa: E501
from service_apis.models.net_slice_id import NetSliceId  # noqa: E501
from service_apis.models.o_auth_grant_type import OAuthGrantType  # noqa: E501
from service_apis.models.problem_details import ProblemDetails  # noqa: E501
from service_apis.models.protocol import Protocol  # noqa: E501

from ..core.responses import unauthorized_error
from service_apis.models.res_oper_info import ResOperInfo  # noqa: E501
from service_apis.models.service_kpis import ServiceKpis  # noqa: E501

from ..core.discoveredapis import (DiscoverApisOperations,
                                   return_negotiated_supp_feat_dict)
from ..core.validate_user import ControlAccess

discover_apis = DiscoverApisOperations()
valid_user = ControlAccess()

def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):

            request.view_args
            cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            
            if not cert_tmp:
                return unauthorized_error("Client certificate required", "X-Ssl-Client-Cert header is missing")
            
            cert_raw = cert_tmp.replace('\t', '')

            cert = x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())

            cn = cert.subject.get_attributes_for_oid(x509.OID_COMMON_NAME)[0].value.strip()

            if cn != "superadmin":
                cert_signature = cert.signature.hex()
                current_app.logger.debug(request.args)
                result = valid_user.validate_user_cert(request.args["api-invoker-id"], cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def all_service_apis_get(api_invoker_id, api_name=None, api_version=None, comm_type=None, protocol=None, aef_id=None, data_format=None, api_cat=None, preferred_aef_loc=None, req_api_prov_name=None, api_supported_features=None, ue_ip_addr=None, service_kpis=None, net_slice_info=None, grant_types=None, api_ids=None, res_ops=None, supported_features=None):  # noqa: E501
    """all_service_apis_get

    Discover published service APIs and retrieve a collection of APIs according to certain filter criteria.  # noqa: E501

    :param api_invoker_id: String identifying the API invoker assigned by the CAPIF core function. It also represents the CCF identifier in the CAPIF-6/6e interface. 
    :type api_invoker_id: str
    :param api_name: Contains the API name set to the value of the \&quot;&lt;apiName&gt;\&quot; placeholder of the API URI as defined in clause 5.2.4 of 3GPP TS 29.122 [14]. 
    :type api_name: str
    :param api_version: API major version the URI (e.g. v1).
    :type api_version: str
    :param comm_type: Communication type used by the API (e.g. REQUEST_RESPONSE).
    :type comm_type: dict | bytes
    :param protocol: Protocol used by the API.
    :type protocol: dict | bytes
    :param aef_id: AEF identifer.
    :type aef_id: str
    :param data_format: Data formats used by the API (e.g. serialization protocol JSON used).
    :type data_format: dict | bytes
    :param api_cat: The service API category to which the service API belongs to.
    :type api_cat: str
    :param preferred_aef_loc: The preferred AEF location.
    :type preferred_aef_loc: dict | bytes
    :param req_api_prov_name: Represents the required API provider name.
    :type req_api_prov_name: str
    :param api_supported_features: Features supported by the discovered service API indicated by api-name parameter. This may only be present if api-name query parameter is present. 
    :type api_supported_features: str
    :param ue_ip_addr: Represents the UE IP address information.
    :type ue_ip_addr: dict | bytes
    :param service_kpis: Contains iInformation about service characteristics provided by the targeted  service API(s). 
    :type service_kpis: dict | bytes
    :param net_slice_info: Contains the identifier(s) of the network slice(s) within which the API shall be available. 
    :type net_slice_info: list | bytes
    :param grant_types: Contains the OAuth grant types that need to be supported.
    :type grant_types: list | bytes
    :param api_ids: Contains the identifier(s) of the targeted service APIs. When this query parameter is present, then all the other query parameters shall be absent except the supported-features and api-invoker-id query parameters. 
    :type api_ids: List[str]
    :param res_ops: Contains the list of supported API resource(s) and service operation(s). 
    :type res_ops: list | bytes
    :param supported_features: Features supported by the NF consumer for the CAPIF Discover Service API.
    :type supported_features: str

    :rtype: Union[DiscoveredAPIs, Tuple[DiscoveredAPIs, int], Tuple[DiscoveredAPIs, int, Dict[str, str]]
    """
    current_app.logger.debug("Discovering service apis")

    query_params = {"api_name": api_name, "api_version": api_version, "comm_type": comm_type,
                    "protocol": protocol, "aef_id": aef_id, "data_format": data_format,
                    "api_cat": api_cat, "api_supported_features": api_supported_features,
                    "supported_features": supported_features}

    if supported_features is not None:
        supp_feat_dict = return_negotiated_supp_feat_dict(supported_features)
        if supp_feat_dict['VendSpecQueryParams']:
            for q_params in request.args:
                if "vend-spec" in q_params:
                    query_params[q_params] = json.loads(request.args[q_params])

    response = discover_apis.get_discoveredapis(api_invoker_id, query_params)
    return response
