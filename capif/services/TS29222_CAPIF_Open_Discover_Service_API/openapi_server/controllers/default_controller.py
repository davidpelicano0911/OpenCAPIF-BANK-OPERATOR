from flask import current_app
from flask_jwt_extended import get_jwt_identity, jwt_required
from openapi_server.models.aef_location import AefLocation  # noqa: F401
from openapi_server.models.communication_type import CommunicationType  # noqa: F401
from openapi_server.models.data_format import DataFormat  # noqa: F401
from openapi_server.models.open_discovery_resp import OpenDiscoveryResp  # noqa: F401
from openapi_server.models.problem_details import ProblemDetails  # noqa: F401
from openapi_server.models.protocol import Protocol  # noqa: F401
from openapi_server.models.res_oper_info import ResOperInfo  # noqa: F401
from openapi_server.models.service_kpis import ServiceKpis  # noqa: F401

from ..core.open_discover_operations import OpenDiscoverOperations

open_discover_ops = OpenDiscoverOperations()


@jwt_required()
def service_apis_get(
    api_names=None,
    api_versions=None,
    comm_type=None,
    protocols=None,
    data_format=None,
    api_cats=None,
    preferred_aef_loc=None,
    api_prov_names=None,
    api_supported_features=None,
    api_ids=None,
    service_kpis=None,
    res_ops=None,
    supported_features=None,
):  # noqa: E501
    """service_apis_get

    Enables Open discovery of the currently registered at the CCF and satisfying
    a number of filter criteria.
    """
    identity = get_jwt_identity()
    if isinstance(identity, str) and identity:
        current_app.logger.debug(f"Open discover authorized identity: {identity}")
    else:
        current_app.logger.debug("Open discover authorized identity is empty or non-string")

    query_params = {
        "api_names": api_names,
        "api_versions": api_versions,
        "comm_type": comm_type,
        "protocols": protocols,
        "data_format": data_format,
        "api_cats": api_cats,
        "preferred_aef_loc": preferred_aef_loc,
        "api_prov_names": api_prov_names,
        "api_supported_features": api_supported_features,
        "api_ids": api_ids,
        "service_kpis": service_kpis,
        "res_ops": res_ops,
        "supported_features": supported_features,
    }

    return open_discover_ops.get_open_discovered_apis(query_params)
