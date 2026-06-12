def create_service_security_default_body(
        notification_destination,
        supported_features="0",
        interface_details=None,
        aef_id=None,
        api_id=None,
        authentication_info=None,
        authorization_info=None,
        grant_type=None,
        pref_security_methods=["OAUTH", "PKI", "PSK"],
        sel_security_method=None,
        request_websocket_uri=None,
        websocket_uri=None):
    data = {
        "notificationDestination": notification_destination,
        "supportedFeatures": supported_features
    }
    security_info = list()
    security_info.append(
        create_security_info(aef_id=aef_id,
                             interface_details=interface_details,
                             api_id=api_id,
                             authentication_info=authentication_info,
                             authorization_info=authorization_info,
                             grant_type=grant_type,
                             pref_security_methods=pref_security_methods,
                             sel_security_method=sel_security_method))
    data['securityInfo'] = security_info
    if request_websocket_uri is not None or websocket_uri is not None:
        data['websockNotifConfig'] = create_web_sock_notif_config(
            request_websocket_uri, websocket_uri)
    return data


def create_security_info(
        aef_id=None,
        interface_details=None,
        api_id=None,
        authentication_info=None,
        authorization_info=None,
        grant_type=None,
        pref_security_methods=None,
        sel_security_method=None):
    # aef_id or interface_details must be set.
    # authentication_info, authorization_info, grant_type, sel_security_method
    # only should be present in repsonse from CCF
    data = dict()
    if aef_id is not None:
        data["aefId"] = aef_id
    if interface_details is not None:
        data['interfaceDetails'] = interface_details
    if api_id is not None:
        data['apiId'] = api_id
    if authentication_info is not None:
        data['authenticationInfo'] = authentication_info
    if authorization_info is not None:
        data['authorizationInfo'] = authorization_info
    if grant_type is not None:
        data['grantType'] = grant_type
    if pref_security_methods is not None:
        data['prefSecurityMethods'] = pref_security_methods
    if sel_security_method is not None:
        data['selSecurityMethod'] = sel_security_method

    return data


def create_web_sock_notif_config(request_websocket_uri=None, websocket_uri=None):
    data = dict()
    if request_websocket_uri is not None:
        data['requestWebsocketUri'] = request_websocket_uri
    if websocket_uri is not None:
        data['websocketUri'] = websocket_uri
    return data


def create_service_security_from_discover_response(notification_destination, discover_response, legacy=True):
    data = {
        "notificationDestination": notification_destination,
        "supportedFeatures": "fffffff",
        "securityInfo": [],
        "websockNotifConfig": {
            "requestWebsocketUri": True,
            "websocketUri": "websocketUri"
        },
        "requestTestNotification": True
    }
    api_ids=list()
    service_api_descriptions = discover_response.json()['serviceAPIDescriptions']
    for service_api_description in service_api_descriptions:
        for aef_profile in service_api_description['aefProfiles']:
            data['securityInfo'].append({
                "authenticationInfo": "authenticationInfo",
                "authorizationInfo": "authorizationInfo",
                "prefSecurityMethods": ["PSK", "PKI", "OAUTH"],
                "aefId": aef_profile['aefId'],
                "apiId": service_api_description['apiId']
            })
            api_ids.append(service_api_description['apiId'])
    if legacy:
        return data
    else:
        return data, api_ids


def update_service_security_with_discover_response(security_body, discover_response, legacy=True):
    api_ids = list()
    service_api_descriptions = discover_response.json()['serviceAPIDescriptions']
    for service_api_description in service_api_descriptions:
        for aef_profile in service_api_description['aefProfiles']:
            security_body['securityInfo'].append({
                "authenticationInfo": "authenticationInfo",
                "authorizationInfo": "authorizationInfo",
                "prefSecurityMethods": ["PSK", "PKI", "OAUTH"],
                "aefId": aef_profile['aefId'],
                "apiId": service_api_description['apiId']
            })

    for security_info in security_body['securityInfo']:
        api_ids.append(security_info['apiId'])

    if legacy:
        return security_body
    else:
        return security_body, api_ids


def create_security_notification_body(api_invoker_id, api_ids, cause="OVERLIMIT_USAGE", aef_id=None):
    # cause must be one of [ OVERLIMIT_USAGE, UNEXPECTED_REASON ]
    data = {
        "apiIds": api_ids,
        "apiInvokerId": api_invoker_id,
        "cause": cause
    }

    if isinstance(api_ids, list):
        data['apiIds'] = api_ids
    else:
        data['apiIds'] = [api_ids]

    if aef_id != None:
        data['aefId'] = aef_id

    return data


def create_access_token_req_body(client_id, scope, client_secret=None, grant_type="client_credentials"):
    data = {
        "grant_type": grant_type,
        "client_id": client_id,
        "scope": scope
    }

    if client_secret != None:
        data['client_secret'] = client_secret

    return data


def get_api_ids_from_discover_response(discover_response):
    api_ids = []
    service_api_descriptions = discover_response.json()[
        'serviceAPIDescriptions']
    for service_api_description in service_api_descriptions:
        api_ids.append(service_api_description['apiId'])
    return api_ids
