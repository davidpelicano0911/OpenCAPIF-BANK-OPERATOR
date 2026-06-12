import unittest

from flask import json
from published_apis.models.problem_details import ProblemDetails  # noqa: E501
from published_apis.models.service_api_description import \
    ServiceAPIDescription  # noqa: E501
from published_apis.models.service_api_description_patch import \
    ServiceAPIDescriptionPatch  # noqa: E501
from published_apis.test import BaseTestCase


class TestIndividualAPFPublishedAPIController(BaseTestCase):
    """IndividualAPFPublishedAPIController integration test stubs"""

    def test_modify_ind_apf_pub_api(self):
        """Test case for modify_ind_apf_pub_api

        
        """
        service_api_description_patch = openapi_server.ServiceAPIDescriptionPatch()
        headers = { 
            'Accept': 'application/json',
            'Content-Type': 'application/merge-patch+json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis/{service_api_id}'.format(service_api_id='service_api_id_example', apf_id='apf_id_example'),
            method='PATCH',
            headers=headers,
            data=json.dumps(service_api_description_patch),
            content_type='application/merge-patch+json')
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
