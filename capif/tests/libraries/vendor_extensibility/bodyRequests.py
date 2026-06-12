def create_vendor_specific_service_api_description(vendor_specific_key):
    vendor_dict = {
        vendor_specific_key: {
            "serializer": "JSON",
            "state": "ACTIVE",
            "scopeOfLocality": "MEC_SYSTEM",
            "consumedLocalOnly": "True",
            "isLocal": "True",
            "category": {
                "href": "https://www.location.com",
                "id": "location_1",
                "name": "Location",
                "version": "1.0"
            }
        }
    }
    return vendor_dict


def create_vendor_specific_aef_profile(vendor_specific_key):
    vendor_dict = {
        vendor_specific_key: {
            "name": "trasport1",
            "description": "Transport Info 1",
            "type": "REST_HTTP",
            "protocol": "HTTP",
            "version": "2",
            "security": {
                "grantTypes": "OAUTH2_CLIENT_CREDENTIALS",
                "tokenEndpoint": "https://token-endpoint/"
            }
        }
    }
    return vendor_dict
