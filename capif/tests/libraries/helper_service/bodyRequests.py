def create_visibility_control_rule_body_invalid_dates():
    return {
        "default_access": "ALLOW",
        "enabled": True,
        "startsAt": "2026-01-23T12:00:00Z",
        "endsAt": "2025-01-23T08:00:00Z",
        "providerSelector": {
            "apiName": ["api-test-error"],
            "userName": "AMF_ROBOT_TESTING_PROVIDER"
        }
    }


def create_visibility_control_rule_body():
    return {
        "default_access": "ALLOW",
        "enabled": True,
        "invokerExceptions": {
            "apiInvokerId": ["invk-X77"]
        },
        "providerSelector": {
            "aefId": ["aef-002"],
            "apiId": ["apiId-999"],
            "apiName": ["api-test-cli"],
            "apiProviderId": ["capif-prov-01"],
            "userName": "AMF_ROBOT_TESTING_PROVIDER"
        }
    }

def create_visibility_control_rule_body_2():
    return {
        "default_access": "DENY",
        "enabled": True,
        "invokerExceptions": {
            "apiInvokerId": ["invk-X77"]
        },
        "providerSelector": {
            "aefId": ["aef-002"],
            "apiId": ["apiId-999"],
            "apiName": ["api-test-cli"],
            "apiProviderId": ["capif-prov-01"],
            "userName": "AMF_ROBOT_TESTING_PROVIDER"
        }
    }