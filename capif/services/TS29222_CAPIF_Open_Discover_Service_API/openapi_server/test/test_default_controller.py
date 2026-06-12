import unittest

from openapi_server.models.aef_location import AefLocation  # noqa: E501
from openapi_server.models.communication_type import \
    CommunicationType  # noqa: E501
from openapi_server.models.data_format import DataFormat  # noqa: E501
from openapi_server.models.open_discovery_resp import \
    OpenDiscoveryResp  # noqa: E501
from openapi_server.models.problem_details import ProblemDetails  # noqa: E501
from openapi_server.models.protocol import Protocol  # noqa: E501
from openapi_server.models.res_oper_info import ResOperInfo  # noqa: E501
from openapi_server.models.service_kpis import ServiceKpis  # noqa: E501
from openapi_server.test import BaseTestCase


class TestDefaultController(BaseTestCase):
    """DefaultController integration test stubs"""

    def test_service_apis_get(self):
        """Test case for service_apis_get

        
        """
        query_string = [('api-names', ['api_names_example']),
                        ('api-versions', {'key': openapi_server.List[str]()}),
                        ('comm-type', openapi_server.CommunicationType()),
                        ('protocols', [openapi_server.Protocol()]),
                        ('data-format', openapi_server.DataFormat()),
                        ('api-cats', ['api_cats_example']),
                        ('preferred-aef-loc', openapi_server.AefLocation()),
                        ('api-prov-names', ['api_prov_names_example']),
                        ('api-supported-features', {'key': 'api_supported_features_example'}),
                        ('api-ids', ['api_ids_example']),
                        ('service-kpis', openapi_server.ServiceKpis()),
                        ('res-ops', [openapi_server.ResOperInfo()]),
                        ('supported-features', 'supported_features_example')]
        headers = { 
            'Accept': 'application/json',
        }
        response = self.client.open(
            '/open-api-disc/v1/service-apis',
            method='GET',
            headers=headers,
            query_string=query_string)
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
