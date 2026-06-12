*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             Collections
Resource            /opt/robot-tests/tests/resources/common/basicRequests.robot
Resource            ../../resources/common.resource

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${APF_ID_NOT_VALID}             apf-example
${SERVICE_API_ID_NOT_VALID}     not-valid
${API_INVOKER_NOT_VALID}        not-valid
${AEF_ID_NOT_VALID}             not-valid


*** Test Cases ***
Retrieve ACL
    [Tags]    capif_api_acl-1    smoke
    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}

    # Retrieve Services 1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info_provider['apf_id']}/service-apis/${serviceApiId1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_1}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId1}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList
    Sleep    30s
    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    1
    Should Be Equal As Strings
    ...    ${resp.json()['apiInvokerPolicies'][0]['apiInvokerId']}
    ...    ${register_user_info_invoker['api_invoker_id']}

Retrieve ACL with 2 Service APIs published
    [Tags]    capif_api_acl-2
    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ${service_api_description_published_2}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_2

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}
    ${serviceApiId2}=    Set Variable    ${service_api_description_published_2['apiId']}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId1}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList

    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    1
    Should Be Equal As Strings
    ...    ${resp.json()['apiInvokerPolicies'][0]['apiInvokerId']}
    ...    ${register_user_info_invoker['api_invoker_id']}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId2}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList

    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    1
    Should Be Equal As Strings
    ...    ${resp.json()['apiInvokerPolicies'][0]['apiInvokerId']}
    ...    ${register_user_info_invoker['api_invoker_id']}

Retrieve ACL with security context created by two different Invokers
    [Tags]    capif_api_acl-3
    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}

    # Retrieve Services 1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info_provider['apf_id']}/service-apis/${serviceApiId1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_1}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${INVOKER_USERNAME_2}=    Set Variable    ${INVOKER_USERNAME}_2

    # Register another invoker
    ${register_user_info_invoker_2}    ${url}    ${request_body}=    Invoker Default Onboarding
    ...    ${INVOKER_USERNAME_2}

    # Get Published APIs
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Get Published APIs
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker_2['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME_2}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker_2['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME_2}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId1}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList
    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    2

    ${API_INVOKER_1_PRESENT}=    Set Variable    ${False}
    ${API_INVOKER_2_PRESENT}=    Set Variable    ${False}

    FOR    ${policy}    IN    @{resp.json()['apiInvokerPolicies']}
        Log    ${policy}
        IF    "${policy['apiInvokerId']}" == "${register_user_info_invoker['api_invoker_id']}"
            ${API_INVOKER_1_PRESENT}=    Set Variable    ${True}
        ELSE IF    "${policy['apiInvokerId']}" == "${register_user_info_invoker_2['api_invoker_id']}"
            ${API_INVOKER_2_PRESENT}=    Set Variable    ${True}
        END
    END

    Should Be True    ${API_INVOKER_1_PRESENT}==${True}
    Should Be True    ${API_INVOKER_2_PRESENT}==${True}

Retrieve ACL filtered by api-invoker-id
    [Tags]    capif_api_acl-4    smoke
    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}

    # Retrieve Services 1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info_provider['apf_id']}/service-apis/${serviceApiId1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_1}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${INVOKER_USERNAME_2}=    Set Variable    ${INVOKER_USERNAME}_2

    # Register another invoker
    ${register_user_info_invoker_2}    ${url}    ${request_body}=    Invoker Default Onboarding
    ...    ${INVOKER_USERNAME_2}

    # Get Published APIs
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Get Published APIs
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker_2['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME_2}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker_2['api_invoker_id']}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME_2}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId1}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList

    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    1
    Should Be Equal As Strings
    ...    ${resp.json()['apiInvokerPolicies'][0]['apiInvokerId']}
    ...    ${register_user_info_invoker['api_invoker_id']}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${serviceApiId1}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${register_user_info_invoker_2['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList

    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
    Length Should Be    ${resp.json()['apiInvokerPolicies']}    1
    Should Be Equal As Strings
    ...    ${resp.json()['apiInvokerPolicies'][0]['apiInvokerId']}
    ...    ${register_user_info_invoker_2['api_invoker_id']}

Retrieve ACL with aef-id not valid
    [Tags]    capif_api_acl-5
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    # ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}
    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${AEF_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${service_api_description_published['apiId']}, aef_id: ${AEF_ID_NOT_VALID}, invoker: None and supportedFeatures: None
    ...    cause=Wrong id

Retrieve ACL with service-id not valid
    [Tags]    capif_api_acl-6
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${SERVICE_API_ID_NOT_VALID}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${SERVICE_API_ID_NOT_VALID}, aef_id: ${register_user_info_provider['aef_id']}, invoker: None and supportedFeatures: None
    ...    cause=Wrong id

Retrieve ACL with service-api-id and aef-id not valid
    [Tags]    capif_api_acl-7
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${SERVICE_API_ID_NOT_VALID}?aef-id=${AEF_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${SERVICE_API_ID_NOT_VALID}, aef_id: ${AEF_ID_NOT_VALID}, invoker: None and supportedFeatures: None
    ...    cause=Wrong id

Retrieve ACL without SecurityContext created previously by Invoker
    [Tags]    capif_api_acl-8
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration    create_security_context=${False}

    # ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}
    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${service_api_description_published['apiId']}, aef_id: ${register_user_info_provider['aef_id']}, invoker: None and supportedFeatures: None
    ...    cause=Wrong id

Retrieve ACL filtered by api-invoker-id not present
    [Tags]    capif_api_acl-9
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${API_INVOKER_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${service_api_description_published['apiId']}, aef_id: ${register_user_info_provider['aef_id']}, invoker: ${API_INVOKER_NOT_VALID} and supportedFeatures: None
    ...    cause=Wrong id

Retrieve ACL with APF Certificate
    [Tags]    capif_api_acl-10
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${API_INVOKER_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=Role not authorized for this API route
    ...    cause=Certificate not authorized

Retrieve ACL with AMF Certificate
    [Tags]    capif_api_acl-11
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${API_INVOKER_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=Role not authorized for this API route
    ...    cause=Certificate not authorized

Retrieve ACL with Invoker Certificate
    [Tags]    capif_api_acl-12    smoke
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}&api-invoker-id=${API_INVOKER_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=Role not authorized for this API route
    ...    cause=Certificate not authorized

No ACL for invoker after be removed
    [Tags]    capif_api_acl-13
    ${register_user_info_invoker}
    ...    ${register_user_info_provider}
    ...    ${service_api_description_published}=
    ...    Basic ACL registration

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList

    Remove entity    ${INVOKER_USERNAME}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_description_published['apiId']}?aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=No ACLs found for the requested service: ${service_api_description_published['apiId']}, aef_id: ${register_user_info_provider['aef_id']}, invoker: None and supportedFeatures: None
    ...    cause=Wrong id
