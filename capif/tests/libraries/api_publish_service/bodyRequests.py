def create_service_api_description(api_name="service_1",
                                   aef_id="aef_id",
                                   supported_features="000",
                                   vendor_specific_service_api_description=None,
                                   vendor_specific_aef_profile=None,
                                   api_status=None,
                                   security_methods="default",
                                   domain_name=None,
                                   interface_descriptions=None):
    aef_ids = list()
    if isinstance(aef_id, list):
        aef_ids = aef_id
        print("aef_id parameter is a list")
    elif isinstance(aef_id, str):
        print("aef_id parameter is a string")
        aef_ids.append(aef_id)

    security_methods_normalized = list()
    if security_methods is not None:
        if isinstance(security_methods, list):
            print("security_methods parameter is a list")
            if len(security_methods) > 0:
                if isinstance(security_methods[0], list):
                    security_methods_normalized = security_methods
                else:
                    security_methods_normalized.append(security_methods)
        elif isinstance(security_methods, str):
            print("security_methods parameter is a string")
            if security_methods == "default":
                for idx in range(len(aef_ids)):
                    security_methods_normalized.append(["OAUTH"])
            else:
                security_methods_normalized.append([security_methods])
        else:
            print(f"security_methods is {security_methods}")
        print(f"security_methods_normalized: {security_methods_normalized}")
    else:
        print("security_methods parameter is None")

    profiles = create_aef_profiles(
        aef_ids,
        security_methods_normalized,
        domain_name,
        interface_descriptions)

    body = {
        "apiName": api_name,
        "aefProfiles": profiles,
        "description": "ROBOT_TESTING",
        "shareableInfo": {
            "isShareable": True,
            "capifProvDoms": [
                "string"
            ]
        },
        "serviceAPICategory": "string",
        "apiSuppFeats": "fffff",
        "pubApiPath": {
            "ccfIds": [
                "string"
            ]
        },
        "ccfId": "string"
    }

    if vendor_specific_service_api_description is not None:
        if isinstance(vendor_specific_service_api_description, dict):
            for key, value in vendor_specific_service_api_description.items():
                body[key] = value
    if vendor_specific_aef_profile is not None:
        if isinstance(vendor_specific_aef_profile, dict):
            for key, value in vendor_specific_aef_profile.items():
                body["aefProfiles"][0][key] = value
    if supported_features is not None:
        body['supportedFeatures'] = supported_features
    if api_status is not None:
        aef_ids_active = list()
        if isinstance(api_status, list):
            aef_ids_active = api_status
            print("api_status parameter is a list")
        elif isinstance(api_status, str):
            print("api_status parameter is a string")
            aef_ids_active.append(api_status)
        body['apiStatus'] = dict()
        body['apiStatus']['aefIds'] = aef_ids_active

    return body


def create_aef_profiles(
        aef_ids,
        security_methods,
        domain_name=None,
        interface_descriptions=None):
    profiles = list()
    index = 1
    for aef_id in aef_ids:
        security_method = get_value(security_methods, index-1)
        print(f"aef_id: {aef_id}, security_method: {security_method}")
        profiles.append(
            create_aef_profile(
                aef_id,
                "resource_" + str(index),
                security_method,
                domain_name,
                interface_descriptions))
        index = index+1
    return profiles


def create_aef_profile(aef_id,
                       resource_name,
                       security_method=None,
                       domain_name=None,
                       interface_descriptions=None):
    # "mandatory_attributes": {
    #   "aefId": "string",
    #   "versions": "Version"
    # },
    # "optional_attributes": {
    #   "protocol": "Protocol",
    #   "dataFormat": "DataFormat",
    #   "securityMethods": "SecurityMethod",
    #   "grantTypes": "OAuthGrantType",
    #   "domainName": "string",
    #   "interfaceDescriptions": "InterfaceDescription",
    #   "aefLocation": "AefLocation",
    #   "serviceKpis": "ServiceKpis",
    #   "ueIpRange": "IpAddrRange"
    data = {
        "aefId": aef_id,
        "versions": [
            {
                "apiVersion": "v1",
                "expiry": "2021-11-30T10:32:02.004000+00:00",
                "resources": [
                    {
                        "resourceName": resource_name,
                        "commType": "REQUEST_RESPONSE",
                        "uri": "string",
                        "custOpName": "string",
                        "operations": [
                                    "GET"
                        ],
                        "description": "string"
                    }
                ],
            }
        ],
        "protocol": "HTTP_1_1",
        "dataFormat": "JSON",
    }

    if domain_name is not None:
        data['domainName'] = domain_name
    elif interface_descriptions is not None:
        data['interfaceDescriptions'] = interface_descriptions
    elif domain_name is None and interface_descriptions is None:
        data['interfaceDescriptions'] = [
            create_interface_description(
                ipv4_addr="string",
                port=65535,
                security_methods=security_method
            )
        ]

    if security_method is not None:
        data['securityMethods'] = security_method
    return data


def create_service_api_description_patch(aef_id=None,
                                         description=None,
                                         shareable_info=None,
                                         api_status=None,
                                         service_api_category=None,
                                         api_supp_feats=None,
                                         pub_api_path=None,
                                         ccf_id=None,
                                         security_methods=None,
                                         domain_name=None,
                                         interface_descriptions=None):
    body = dict()

    # aef profiles
    aef_ids = list()
    if aef_id is None:
        aef_ids = None
    elif isinstance(aef_id, list):
        aef_ids = aef_id
        print("aef_id parameter is a list")
    elif isinstance(aef_id, str):
        print("aef_id parameter is a string")
        aef_ids.append(aef_id)

    security_methods_normalized = list()
    if security_methods is not None:
        if isinstance(security_methods, list):
            print("security_methods parameter is a list")
            if len(security_methods) > 0:
                if isinstance(security_methods[0], list):
                    security_methods_normalized = security_methods
                else:
                    security_methods_normalized.append(security_methods)
        elif isinstance(security_methods, str):
            print("security_methods parameter is a string")
            security_methods_normalized.append([security_methods])

    if aef_ids is not None:
        profiles = create_aef_profiles(
            aef_ids,
            security_methods_normalized,
            domain_name,
            interface_descriptions)
        body['aefProfiles'] = profiles

    # description
    if description is not None:
        body['description'] = description

    # shareable info
    if shareable_info is not None:
        body['shareableInfo'] = shareable_info

    # service API Category
    if service_api_category is not None:
        body['serviceAPICategory'] = service_api_category

    # api Supp Feats
    if api_supp_feats is not None:
        body['apiSuppFeats'] = api_supp_feats

    # pub Api Path
    if pub_api_path is not None:
        body['pubApiPath'] = pub_api_path

    # ccf id
    if ccf_id is not None:
        body['ccfId'] = ccf_id

    # api Status
    if api_status is not None:
        aef_ids_active = list()
        if isinstance(api_status, list):
            aef_ids_active = api_status
            print("api_status parameter is a list")
        elif isinstance(api_status, str):
            print("api_status parameter is a string")
            aef_ids_active.append(api_status)
        body['apiStatus'] = dict()
        body['apiStatus']['aefIds'] = aef_ids_active

    return body


def get_value(lst, index):
    return lst[index] if index < len(lst) else None


def create_interface_description(ipv4_addr=None,
                                 ipv6_addr=None,
                                 fqdn=None,
                                 port=None,
                                 api_prefix=None,
                                 security_methods=None,
                                 grant_types=None):
    """
    Create an interface description with the given parameters.
    """
    # Create the interface description dictionary
    data = dict()
    if ipv4_addr is not None:
        data['ipv4Addr'] = ipv4_addr
    elif ipv6_addr is not None:
        data['ipv6Addr'] = ipv6_addr
    elif fqdn is not None:
        data['fqdn'] = fqdn
    else:
        raise ValueError(
            "At least one of ipv4_addr, ipv6_addr, or fqdn must be provided.")

    if port is not None:
        data['port'] = port
    if api_prefix is not None:
        data['apiPrefix'] = api_prefix
    if security_methods is not None:
        data['securityMethods'] = security_methods
    if grant_types is not None:
        data['grantTypes'] = grant_types
    # Return the interface description
    return data
