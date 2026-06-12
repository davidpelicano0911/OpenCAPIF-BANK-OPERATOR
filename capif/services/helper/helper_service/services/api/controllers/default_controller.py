
from api.models.error_response import ErrorResponse  # noqa: E501
from api.models.paginated_response_event import \
    PaginatedResponseEvent  # noqa: E501
from api.models.paginated_response_invoker import \
    PaginatedResponseInvoker  # noqa: E501
from api.models.paginated_response_provider import \
    PaginatedResponseProvider  # noqa: E501
from api.models.paginated_response_security import \
    PaginatedResponseSecurity  # noqa: E501
from api.models.paginated_response_service import \
    PaginatedResponseService  # noqa: E501

from ..core.helper_operations import HelperOperations

helper_operations = HelperOperations()

def helper_controller_delete_entities(uuid):  # noqa: E501
    """Delete entities by UUID

    Deletes all CAPIF entities (invokers, providers, services, security contexts, events) associated with the given UUID. # noqa: E501

    :param uuid: UUID of the user whose entities are to be deleted.
    :type uuid: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    return helper_operations.remove_entities(uuid)


def helper_controller_get_ccf_id():  # noqa: E501
    """Get CCF ID

    Retrieves the CCF ID of the CAPIF Core Function. # noqa: E501


    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    return helper_operations.get_ccf_id()


def helper_controller_get_events(subscriber_id=None, subscription_id=None, page_size=None, page=None):  # noqa: E501
    """Retrieve CAPIF events

    Returns CAPIF event subscriptions or delivered events. # noqa: E501

    :param subscriber_id: Filter by subscriber identifier.
    :type subscriber_id: str
    :param subscription_id: Filter by subscription identifier.
    :type subscription_id: str
    :param page_size: Page size.
    :type page_size: int
    :param page: Page index (0-based).
    :type page: int

    :rtype: Union[PaginatedResponseEvent, Tuple[PaginatedResponseEvent, int], Tuple[PaginatedResponseEvent, int, Dict[str, str]]
    """
    return helper_operations.get_events(subscriber_id, subscription_id, page_size, page)


def helper_controller_get_invokers(uuid=None, api_invoker_id=None, page_size=None, page=None, sort_order=None):  # noqa: E501
    """Retrieve API invokers

    Returns invoker entries with pagination and optional filters. # noqa: E501

    :param uuid: Filter by invoker UUID.
    :type uuid: str
    :param api_invoker_id: Filter by CAPIF &#x60;apiInvokerId&#x60;.
    :type api_invoker_id: str
    :param page_size: Page size.
    :type page_size: int
    :param page: Page index (0-based).
    :type page: int
    :param sort_order: Sort direction.
    :type sort_order: str

    :rtype: Union[PaginatedResponseInvoker, Tuple[PaginatedResponseInvoker, int], Tuple[PaginatedResponseInvoker, int, Dict[str, str]]
    """
    return helper_operations.get_invokers(uuid, api_invoker_id, page_size, page, sort_order)


def helper_controller_get_providers(uuid=None, api_prov_dom_id=None, page_size=None, page=None, sort_order=None):  # noqa: E501
    """Retrieve providers

    Returns provider domains (CAPIF provider domains / AEF providers) with pagination. # noqa: E501

    :param uuid: Filter by provider UUID.
    :type uuid: str
    :param api_prov_dom_id: Filter by provider domain ID.
    :type api_prov_dom_id: str
    :param page_size: Page size.
    :type page_size: int
    :param page: Page index (0-based).
    :type page: int
    :param sort_order: Sort direction.
    :type sort_order: str

    :rtype: Union[PaginatedResponseProvider, Tuple[PaginatedResponseProvider, int], Tuple[PaginatedResponseProvider, int, Dict[str, str]]
    """
    return helper_operations.get_providers(uuid, api_prov_dom_id, page_size, page, sort_order)


def helper_controller_get_security(invoker_id=None, page_size=None, page=None):  # noqa: E501
    """Retrieve security associations

    Returns security credentials/bindings for a given invoker. # noqa: E501

    :param invoker_id: Filter by invoker identifier.
    :type invoker_id: str
    :param page_size: Page size.
    :type page_size: int
    :param page: Page index (0-based).
    :type page: int

    :rtype: Union[PaginatedResponseSecurity, Tuple[PaginatedResponseSecurity, int], Tuple[PaginatedResponseSecurity, int, Dict[str, str]]
    """
    return helper_operations.get_security(invoker_id, page_size, page)


def helper_controller_get_services(service_id=None, apf_id=None, api_name=None, page_size=None, page=None, sort_order=None):  # noqa: E501
    """Retrieve services

    Returns published APIs/services exposed by providers. # noqa: E501

    :param service_id: Filter by service identifier.
    :type service_id: str
    :param apf_id: Filter by APF identifier.
    :type apf_id: str
    :param api_name: Filter by API name.
    :type api_name: str
    :param page_size: Page size.
    :type page_size: int
    :param page: Page index (0-based).
    :type page: int
    :param sort_order: Sort direction.
    :type sort_order: str

    :rtype: Union[PaginatedResponseService, Tuple[PaginatedResponseService, int], Tuple[PaginatedResponseService, int, Dict[str, str]]
    """
    return helper_operations.get_services(service_id, apf_id, api_name, page_size, page, sort_order)
