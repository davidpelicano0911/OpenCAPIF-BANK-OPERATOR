import unittest

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
from service_apis.models.res_oper_info import ResOperInfo  # noqa: E501
from service_apis.models.service_kpis import ServiceKpis  # noqa: E501
from service_apis.test import BaseTestCase


class TestDefaultController(BaseTestCase):
    """DefaultController integration test stubs"""

    def test_all_service_apis_get(self):
        """Test case for all_service_apis_get

        
        """
        query_string = [('api-invoker-id', 'api_invoker_id_example'),
                        ('api-name', 'api_name_example'),
                        ('api-version', 'api_version_example'),
                        ('comm-type', openapi_server.CommunicationType()),
                        ('protocol', openapi_server.Protocol()),
                        ('aef-id', 'aef_id_example'),
                        ('data-format', openapi_server.DataFormat()),
                        ('api-cat', 'api_cat_example'),
                        ('preferred-aef-loc', openapi_server.AefLocation()),
                        ('req-api-prov-name', 'req_api_prov_name_example'),
                        ('api-supported-features', 'api_supported_features_example'),
                        ('ue-ip-addr', openapi_server.IpAddrInfo()),
                        ('service-kpis', openapi_server.ServiceKpis()),
                        ('net-slice-info', [openapi_server.NetSliceId()]),
                        ('grant-types', [openapi_server.OAuthGrantType()]),
                        ('api-ids', ['api_ids_example']),
                        ('res-ops', [openapi_server.ResOperInfo()]),
                        ('supported-features', 'supported_features_example')]
        headers = { 
            'Accept': 'application/json',
        }
        response = self.client.open(
            '/service-apis/v1/allServiceAPIs',
            method='GET',
            headers=headers,
            query_string=query_string)
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
