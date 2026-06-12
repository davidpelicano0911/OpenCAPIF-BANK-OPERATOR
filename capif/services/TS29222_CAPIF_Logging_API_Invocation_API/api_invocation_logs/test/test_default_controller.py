import unittest

from api_invocation_logs.models.invocation_log import \
    InvocationLog  # noqa: E501
from api_invocation_logs.models.problem_details import \
    ProblemDetails  # noqa: E501
from api_invocation_logs.test import BaseTestCase
from flask import json


class TestDefaultController(BaseTestCase):
    """DefaultController integration test stubs"""

    def test_aef_id_logs_post(self):
        """Test case for aef_id_logs_post

        
        """
        invocation_log = {"supportedFeatures":"supportedFeatures","apiInvokerId":"apiInvokerId","aefId":"aefId","logs":[{"apiName":"apiName","invocationTime":"2000-01-23T04:56:07.000+00:00","srcInterface":{"ipv6Addr":"ipv6Addr","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"securityMethods":["PSK","PSK"],"fqdn":"fqdn","port":39500,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},"fwdInterface":"fwdInterface","resourceName":"resourceName","uri":"uri","inputParameters":"","invocationLatency":0,"result":"result","protocol":"HTTP_1_1","apiVersion":"apiVersion","netSliceInfo":{"ensi":"ensi","snssai":{"sd":"sd","sst":37},"nsiId":"nsiId"},"destInterface":{"ipv6Addr":"ipv6Addr","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"securityMethods":["PSK","PSK"],"fqdn":"fqdn","port":39500,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},"operation":"GET","apiId":"apiId","outputParameters":""},{"apiName":"apiName","invocationTime":"2000-01-23T04:56:07.000+00:00","srcInterface":{"ipv6Addr":"ipv6Addr","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"securityMethods":["PSK","PSK"],"fqdn":"fqdn","port":39500,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},"fwdInterface":"fwdInterface","resourceName":"resourceName","uri":"uri","inputParameters":"","invocationLatency":0,"result":"result","protocol":"HTTP_1_1","apiVersion":"apiVersion","netSliceInfo":{"ensi":"ensi","snssai":{"sd":"sd","sst":37},"nsiId":"nsiId"},"destInterface":{"ipv6Addr":"ipv6Addr","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"securityMethods":["PSK","PSK"],"fqdn":"fqdn","port":39500,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},"operation":"GET","apiId":"apiId","outputParameters":""}]}
        headers = { 
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        response = self.client.open(
            '/api-invocation-logs/v1/{aef_id}/logs'.format(aef_id='aef_id_example'),
            method='POST',
            headers=headers,
            data=json.dumps(invocation_log),
            content_type='application/json')
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
