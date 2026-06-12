import connexion
from typing import Dict
from typing import Tuple
from typing import Union

from visibility_control.models.discovered_apis import DiscoveredAPIs  # noqa: E501
from visibility_control.models.error import Error  # noqa: E501
from visibility_control import util


def decision_invokers_api_invoker_id_discoverable_apis_get(api_invoker_id):  # noqa: E501
    """Get discoverable APIs filter for an invoker (global scope)

    Returns a filtered list of APIs for the API Invoker.  # noqa: E501

    :param api_invoker_id: CAPIF API Invoker identifier
    :type api_invoker_id: str

    :rtype: Union[DiscoveredAPIs, Tuple[DiscoveredAPIs, int], Tuple[DiscoveredAPIs, int, Dict[str, str]]
    """
    return 'do some magic!'
