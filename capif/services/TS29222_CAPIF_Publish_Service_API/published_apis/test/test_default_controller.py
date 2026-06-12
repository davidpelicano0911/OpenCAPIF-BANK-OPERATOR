import unittest

from flask import json
from published_apis.models.problem_details import ProblemDetails  # noqa: E501
from published_apis.models.service_api_description import \
    ServiceAPIDescription  # noqa: E501
from published_apis.test import BaseTestCase


class TestDefaultController(BaseTestCase):
    """DefaultController integration test stubs"""

    def test_apf_id_service_apis_get(self):
        """Test case for apf_id_service_apis_get

        
        """
        headers = { 
            'Accept': 'application/json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis'.format(apf_id='apf_id_example'),
            method='GET',
            headers=headers)
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))

    def test_apf_id_service_apis_post(self):
        """Test case for apf_id_service_apis_post

        
        """
        service_api_description = {"serviceAPICategory":"serviceAPICategory","ccfId":"ccfId","apiName":"apiName","apiProvName":"apiProvName","supportedFeatures":"supportedFeatures","description":"description","aefProfiles":[{"protocol":"HTTP_1_1","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"ueIpRange":{"ueIpv4AddrRanges":[{"start":"198.51.100.1","end":"198.51.100.1"},{"start":"198.51.100.1","end":"198.51.100.1"}],"ueIpv6AddrRanges":[{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"},{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"}]},"securityMethods":["PSK","PSK"],"versions":[{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"},{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"}],"dataFormat":"JSON","domainName":"domainName","aefLocation":{"dcId":"dcId","geoArea":{"shape":"POINT","point":{"lon":36.988422590534526,"lat":-63.615366350946985}},"civicAddr":{"POBOX":"POBOX","usageRules":"usageRules","country":"country","PRD":"PRD","PLC":"PLC","HNO":"HNO","PRM":"PRM","HNS":"HNS","FLR":"FLR","A1":"A1","A2":"A2","A3":"A3","A4":"A4","STS":"STS","A5":"A5","A6":"A6","RDSEC":"RDSEC","providedBy":"providedBy","LOC":"LOC","UNIT":"UNIT","SEAT":"SEAT","POD":"POD","RDBR":"RDBR","method":"method","LMK":"LMK","POM":"POM","ADDCODE":"ADDCODE","RD":"RD","PC":"PC","PCN":"PCN","NAM":"NAM","BLD":"BLD","ROOM":"ROOM","RDSUBBR":"RDSUBBR"}},"aefId":"aefId","interfaceDescriptions":[{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"}],"serviceKpis":{"avalMem":"avalMem","avalStor":"avalStor","avalComp":"avalComp","conBand":0,"maxRestime":0,"availability":0,"maxReqRate":0,"avalGraComp":"avalGraComp"}},{"protocol":"HTTP_1_1","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"ueIpRange":{"ueIpv4AddrRanges":[{"start":"198.51.100.1","end":"198.51.100.1"},{"start":"198.51.100.1","end":"198.51.100.1"}],"ueIpv6AddrRanges":[{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"},{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"}]},"securityMethods":["PSK","PSK"],"versions":[{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"},{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"}],"dataFormat":"JSON","domainName":"domainName","aefLocation":{"dcId":"dcId","geoArea":{"shape":"POINT","point":{"lon":36.988422590534526,"lat":-63.615366350946985}},"civicAddr":{"POBOX":"POBOX","usageRules":"usageRules","country":"country","PRD":"PRD","PLC":"PLC","HNO":"HNO","PRM":"PRM","HNS":"HNS","FLR":"FLR","A1":"A1","A2":"A2","A3":"A3","A4":"A4","STS":"STS","A5":"A5","A6":"A6","RDSEC":"RDSEC","providedBy":"providedBy","LOC":"LOC","UNIT":"UNIT","SEAT":"SEAT","POD":"POD","RDBR":"RDBR","method":"method","LMK":"LMK","POM":"POM","ADDCODE":"ADDCODE","RD":"RD","PC":"PC","PCN":"PCN","NAM":"NAM","BLD":"BLD","ROOM":"ROOM","RDSUBBR":"RDSUBBR"}},"aefId":"aefId","interfaceDescriptions":[{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"}],"serviceKpis":{"avalMem":"avalMem","avalStor":"avalStor","avalComp":"avalComp","conBand":0,"maxRestime":0,"availability":0,"maxReqRate":0,"avalGraComp":"avalGraComp"}}],"shareableInfo":{"capifProvDoms":["capifProvDoms","capifProvDoms"],"isShareable":True},"netSliceInfo":[{"ensi":"ensi","snssai":{"sd":"sd","sst":237},"nsiId":"nsiId"},{"ensi":"ensi","snssai":{"sd":"sd","sst":237},"nsiId":"nsiId"}],"apiSuppFeats":"apiSuppFeats","apiId":"apiId","apiStatus":{"aefIds":["aefIds","aefIds"]},"pubApiPath":{"ccfIds":["ccfIds","ccfIds"]}}
        headers = { 
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis'.format(apf_id='apf_id_example'),
            method='POST',
            headers=headers,
            data=json.dumps(service_api_description),
            content_type='application/json')
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))

    def test_apf_id_service_apis_service_api_id_delete(self):
        """Test case for apf_id_service_apis_service_api_id_delete

        
        """
        headers = { 
            'Accept': 'application/problem+json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis/{service_api_id}'.format(service_api_id='service_api_id_example', apf_id='apf_id_example'),
            method='DELETE',
            headers=headers)
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))

    def test_apf_id_service_apis_service_api_id_get(self):
        """Test case for apf_id_service_apis_service_api_id_get

        
        """
        headers = { 
            'Accept': 'application/json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis/{service_api_id}'.format(service_api_id='service_api_id_example', apf_id='apf_id_example'),
            method='GET',
            headers=headers)
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))

    def test_apf_id_service_apis_service_api_id_put(self):
        """Test case for apf_id_service_apis_service_api_id_put

        
        """
        service_api_description = {"serviceAPICategory":"serviceAPICategory","ccfId":"ccfId","apiName":"apiName","apiProvName":"apiProvName","supportedFeatures":"supportedFeatures","description":"description","aefProfiles":[{"protocol":"HTTP_1_1","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"ueIpRange":{"ueIpv4AddrRanges":[{"start":"198.51.100.1","end":"198.51.100.1"},{"start":"198.51.100.1","end":"198.51.100.1"}],"ueIpv6AddrRanges":[{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"},{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"}]},"securityMethods":["PSK","PSK"],"versions":[{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"},{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"}],"dataFormat":"JSON","domainName":"domainName","aefLocation":{"dcId":"dcId","geoArea":{"shape":"POINT","point":{"lon":36.988422590534526,"lat":-63.615366350946985}},"civicAddr":{"POBOX":"POBOX","usageRules":"usageRules","country":"country","PRD":"PRD","PLC":"PLC","HNO":"HNO","PRM":"PRM","HNS":"HNS","FLR":"FLR","A1":"A1","A2":"A2","A3":"A3","A4":"A4","STS":"STS","A5":"A5","A6":"A6","RDSEC":"RDSEC","providedBy":"providedBy","LOC":"LOC","UNIT":"UNIT","SEAT":"SEAT","POD":"POD","RDBR":"RDBR","method":"method","LMK":"LMK","POM":"POM","ADDCODE":"ADDCODE","RD":"RD","PC":"PC","PCN":"PCN","NAM":"NAM","BLD":"BLD","ROOM":"ROOM","RDSUBBR":"RDSUBBR"}},"aefId":"aefId","interfaceDescriptions":[{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"}],"serviceKpis":{"avalMem":"avalMem","avalStor":"avalStor","avalComp":"avalComp","conBand":0,"maxRestime":0,"availability":0,"maxReqRate":0,"avalGraComp":"avalGraComp"}},{"protocol":"HTTP_1_1","grantTypes":["CLIENT_CREDENTIALS","CLIENT_CREDENTIALS"],"ueIpRange":{"ueIpv4AddrRanges":[{"start":"198.51.100.1","end":"198.51.100.1"},{"start":"198.51.100.1","end":"198.51.100.1"}],"ueIpv6AddrRanges":[{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"},{"start":"2001:db8:85a3::8a2e:370:7334","end":"2001:db8:85a3::8a2e:370:7334"}]},"securityMethods":["PSK","PSK"],"versions":[{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"},{"apiVersion":"apiVersion","resources":[{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"},{"operations":[null,null],"commType":"REQUEST_RESPONSE","custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"description":"description","resourceName":"resourceName","custOpName":"custOpName","uri":"uri"}],"custOperations":[{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"},{"operations":["GET","GET"],"description":"description","custOpName":"custOpName"}],"expiry":"2000-01-23T04:56:07.000+00:00"}],"dataFormat":"JSON","domainName":"domainName","aefLocation":{"dcId":"dcId","geoArea":{"shape":"POINT","point":{"lon":36.988422590534526,"lat":-63.615366350946985}},"civicAddr":{"POBOX":"POBOX","usageRules":"usageRules","country":"country","PRD":"PRD","PLC":"PLC","HNO":"HNO","PRM":"PRM","HNS":"HNS","FLR":"FLR","A1":"A1","A2":"A2","A3":"A3","A4":"A4","STS":"STS","A5":"A5","A6":"A6","RDSEC":"RDSEC","providedBy":"providedBy","LOC":"LOC","UNIT":"UNIT","SEAT":"SEAT","POD":"POD","RDBR":"RDBR","method":"method","LMK":"LMK","POM":"POM","ADDCODE":"ADDCODE","RD":"RD","PC":"PC","PCN":"PCN","NAM":"NAM","BLD":"BLD","ROOM":"ROOM","RDSUBBR":"RDSUBBR"}},"aefId":"aefId","interfaceDescriptions":[{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"},{"ipv6Addr":"ipv6Addr","grantTypes":[null,null],"securityMethods":[null,null],"fqdn":"fqdn","port":5248,"apiPrefix":"apiPrefix","ipv4Addr":"ipv4Addr"}],"serviceKpis":{"avalMem":"avalMem","avalStor":"avalStor","avalComp":"avalComp","conBand":0,"maxRestime":0,"availability":0,"maxReqRate":0,"avalGraComp":"avalGraComp"}}],"shareableInfo":{"capifProvDoms":["capifProvDoms","capifProvDoms"],"isShareable":True},"netSliceInfo":[{"ensi":"ensi","snssai":{"sd":"sd","sst":237},"nsiId":"nsiId"},{"ensi":"ensi","snssai":{"sd":"sd","sst":237},"nsiId":"nsiId"}],"apiSuppFeats":"apiSuppFeats","apiId":"apiId","apiStatus":{"aefIds":["aefIds","aefIds"]},"pubApiPath":{"ccfIds":["ccfIds","ccfIds"]}}
        headers = { 
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        response = self.client.open(
            '/published-apis/v1/{apf_id}/service-apis/{service_api_id}'.format(service_api_id='service_api_id_example', apf_id='apf_id_example'),
            method='PUT',
            headers=headers,
            data=json.dumps(service_api_description),
            content_type='application/json')
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
