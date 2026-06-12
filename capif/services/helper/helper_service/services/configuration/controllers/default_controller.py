
import connexion
from configuration.models.capif_configuration import \
    CapifConfiguration  # noqa: E501
from configuration.models.config_category_create_request import \
    ConfigCategoryCreateRequest  # noqa: E501
from configuration.models.config_param_update_request import \
    ConfigParamUpdateRequest  # noqa: E501
from configuration.models.generic_error import GenericError  # noqa: E501

from ..core.configuration_operations import ConfigurationOperations

config_operations = ConfigurationOperations()

def configuration_controller_get_configuration():  # noqa: E501
    """Read full configuration

    Returns the entire CAPIF configuration document. # noqa: E501


    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    return config_operations.get_configuration()


def dynamic_config_controller_add_new_config_setting(body):  # noqa: E501
    """Add new config setting at path

    Adds a new key/value inside an existing category using \&quot;param_path\&quot; and \&quot;new_value\&quot;. # noqa: E501

    :param config_param_update_request: 
    :type config_param_update_request: dict | bytes

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    config_param_update_request = body
    if connexion.request.is_json:
        config_param_update_request = ConfigParamUpdateRequest.from_dict(connexion.request.get_json())  # noqa: E501
    return config_operations.add_new_config_setting(
        config_param_update_request.param_path,
        config_param_update_request.new_value
    )


def dynamic_config_controller_add_new_configuration(body):  # noqa: E501
    """Add new configuration category

    Adds a brand new top-level category. # noqa: E501

    :param config_category_create_request: 
    :type config_category_create_request: dict | bytes

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    config_category_create_request = body
    if connexion.request.is_json:
        config_category_create_request = ConfigCategoryCreateRequest.from_dict(connexion.request.get_json())  # noqa: E501
    return config_operations.add_new_configuration(
        config_category_create_request.category_name,
        config_category_create_request.category_values
    )


def dynamic_config_controller_remove_config_category(config_path):  # noqa: E501
    """Remove configuration category

    Deletes an entire top-level category by name. # noqa: E501

    :param config_path: Configuration path to remove
    :type config_path: str

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    return config_operations.remove_config_category(config_path)


def dynamic_config_controller_remove_config_param(param_path):  # noqa: E501
    """Remove config parameter

    Deletes a leaf parameter by dotted path. # noqa: E501

    :param param_path: Parameter path to remove
    :type param_path: str

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    return config_operations.remove_config_param(param_path)


def dynamic_config_controller_replace_configuration(body):  # noqa: E501
    """Replace entire configuration

    Replaces the configuration document with a new one. # noqa: E501

    :param capif_configuration: 
    :type capif_configuration: dict | bytes

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    capif_configuration = body
    if connexion.request.is_json:
        capif_configuration = CapifConfiguration.from_dict(connexion.request.get_json())  # noqa: E501
    return config_operations.replace_configuration(capif_configuration.to_dict())


def dynamic_config_controller_update_config_param(body):  # noqa: E501
    """Update single config parameter

    Updates a single setting inside the configuration using a dotted path selector. # noqa: E501

    :param config_param_update_request: 
    :type config_param_update_request: dict | bytes

    :rtype: Union[CapifConfiguration, Tuple[CapifConfiguration, int], Tuple[CapifConfiguration, int, Dict[str, str]]
    """
    config_param_update_request = body
    if connexion.request.is_json:
        config_param_update_request = ConfigParamUpdateRequest.from_dict(connexion.request.get_json())  # noqa: E501
    return config_operations.update_config_param(
        config_param_update_request.param_path,
        config_param_update_request.new_value
    )   
