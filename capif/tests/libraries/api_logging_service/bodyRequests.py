def create_log_entry(aefId, apiInvokerId, apiId, apiName, results=['200','500'],api_versions=['v1','v2']):
    data = {
    "aefId": aefId,
    "apiInvokerId": apiInvokerId,
    "logs": [],
    "supportedFeatures": "0"
    }
    if len(results) > 0:
        count=0
        for result in results:
            data['logs'].append(create_log(apiId,apiName,result,api_versions[count]))
            count=count+1
            if count == len(api_versions):
                count=0

    return data 

def create_log_entry_bad_service(aefId, apiInvokerId, result='500'):
    data = {
    "aefId": aefId,
    "apiInvokerId": apiInvokerId,
    "logs": [
        {
        "apiId": "not-exist",
        "apiName": "not-exist",
        "apiVersion": "string",
        "resourceName": "string",
        "uri": "string",
        "protocol": "HTTP_1_1",
        "operation": "GET",
        "result": result,
        "invocationTime": "2023-03-30T10:30:21.408000+00:00",
        "invocationLatency": 0,
        "inputParameters": "string",
        "outputParameters": "string",
        "srcInterface": {
            "ipv4Addr": "192.168.1.1",
            "port": 65535,
            "securityMethods": [
            "PSK",
            "PKI"
            ]
        },
        "destInterface": {
            "ipv4Addr": "192.168.1.23",
            "port": 65535,
            "securityMethods": [
            "PSK",
            "PKI"
            ]
        },
        "fwdInterface": "string"
        }
    ],
    "supportedFeatures": "0"
    }
    return data 

def get_api_ids_and_names_from_discover_response(discover_response):
    api_ids=[]
    api_names=[]
    service_api_descriptions = discover_response.json()['serviceAPIDescriptions']
    for service_api_description in service_api_descriptions:
        api_ids.append(service_api_description['apiId'])
        api_names.append(service_api_description['apiName'])
    return api_ids, api_names


def create_log(apiId, apiName, result, api_version='v1'):
    log= {
        "apiId": apiId[0],
        "apiName": apiName[0],
        "apiVersion": api_version,
        "resourceName": "string",
        "uri": "http://resource/endpoint",
        "protocol": "HTTP_1_1",
        "operation": "GET",
        "result": result,
        "invocationTime": "2023-03-30T10:30:21.408000+00:00",
        "invocationLatency": 0,
        "inputParameters": "string",
        "outputParameters": "string",
        "srcInterface": {
            "ipv4Addr": "192.168.1.1",
            "port": 65535,
            "securityMethods": [
            "PSK",
            "PKI"
            ]
        }
    }
    return log
