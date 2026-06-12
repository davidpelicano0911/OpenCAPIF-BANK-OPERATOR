*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             XML
Library             String
Resource            /opt/robot-tests/tests/resources/common/basicRequests.robot
Resource            ../../resources/common.resource
Resource            ../../resources/common/basicRequests.robot

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${API_INVOKER_NOT_REGISTERED}       not-valid
${SUBSCRIBER_ID_NOT_VALID}          not-valid
${SUBSCRIPTION_ID_NOT_VALID}        not-valid


*** Test Cases ***
Invoker subscribe to Service API Available
    [Tags]    event_req-1    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Create Provider1 with 2 AEF roles and publish API
    ${register_user_info_provider_1}=    Provider Default Registration
    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_empty_list}=    Create List

    # Subscribe to events and setup event filter with api_id
    ${events_list}=    Create List    API_INVOKER_ONBOARDED
    ${event_req}=    Create Event Req    notif_method=PERIODIC   max_report_nbr=${2}   rep_period=${1}

    ${subscription_ids}=   Create List

    FOR    ${counter}    IN RANGE    1    1   1
        Log    ${counter}
        ${subscription_id}=
        ...    Subscribe invoker ${register_user_info_invoker} to events ${events_list} with event req ${event_req}
        Append To List    ${subscription_ids}   ${subscription_id}
    END

    Sleep     5s

    ${resp}=    Get Mock Server Messages

    # ${notification_events_on_mock_server}=    Set Variable    ${resp.json()}

*** Keywords ***
Create Security Context between ${invoker_info} and ${provider_info}
    # Discover APIs by invoker
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${invoker_info['api_invoker_id']}&aef-id=${provider_info['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${invoker_info['management_cert']}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}    ${api_ids}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ...    legacy=${FALSE}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${invoker_info['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${invoker_info['management_cert']}

    Set To Dictionary    ${invoker_info}    security_body=${request_service_security_body}
    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${api_invoker_policies_list}=    Create List

    FOR    ${api_id}    IN    @{api_ids}
        Log    ${api_id}
        ${resp}=    Get Request Capif
        ...    /access-control-policy/v1/accessControlPolicyList/${api_id}?aef-id=${provider_info['aef_id']}
        ...    server=${CAPIF_HTTPS_URL}
        ...    verify=ca.crt
        ...    username=${provider_info['aef_username']}
        Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList
        Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}
        ${api_invoker_policies}=    Set Variable    ${resp.json()['apiInvokerPolicies']}
        ${api_invoker_policies_list}=    Set Variable    ${api_invoker_policies}
    END

    Log List    ${api_invoker_policies_list}

    RETURN    ${api_invoker_policies_list}

Update Security Context between ${invoker_info} and ${provider_info}
    # Discover APIs by invoker
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${invoker_info['api_invoker_id']}&aef-id=${provider_info['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${invoker_info['management_cert']}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}    ${api_ids}=    Update Service Security With Discover Response
    ...    ${invoker_info['security_body']}
    ...    ${discover_response}
    ...    legacy=${FALSE}
    ${resp}=    Post Request Capif
    ...    /capif-security/v1/trustedInvokers/${invoker_info['api_invoker_id']}/update
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${invoker_info['management_cert']}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    200    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${api_invoker_policies_list}=    Create List

    ${api_id}=    Get From List    ${api_ids}    -1
    Log    ${api_id}
    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${api_id}?aef-id=${provider_info['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${provider_info['aef_username']}

    Check Response Variable Type And Values    ${resp}    200    AccessControlPolicyList
    # Check returned values
    Should Not Be Empty    ${resp.json()['apiInvokerPolicies']}

    ${api_invoker_policies}=    Set Variable    ${resp.json()['apiInvokerPolicies']}
    # Append To List    ${api_invoker_policies_list}    ${api_invoker_policies}
    ${api_invoker_policies_list}=    Set Variable    ${api_invoker_policies}

    Log List    ${api_invoker_policies_list}

    RETURN    ${api_invoker_policies_list}

Subscribe provider ${provider_info} to events ${events_list} with event filters ${event_filters}
    ${resp}=
    ...    Subscribe ${provider_info['amf_id']} with ${provider_info['amf_username']} to ${events_list} with ${event_filters}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    RETURN    ${subscription_id}

Subscribe invoker ${invoker_info} to events ${events_list} with event filters ${event_filters}
    ${resp}=
    ...    Subscribe ${invoker_info['api_invoker_id']} with ${invoker_info['management_cert']} to ${events_list} with ${event_filters}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    RETURN    ${subscription_id}

Subscribe invoker ${invoker_info} to events ${events_list} with event req ${event_req}
    ${resp}=
    ...    Subscribe ${invoker_info['api_invoker_id']} with ${invoker_info['management_cert']} to ${events_list} with ${event_req}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    RETURN    ${subscription_id}

Subscribe ${subscriber_id} with ${username} to ${events_list} with ${event_req}
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ...    event_req=${event_req}
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${subscriber_id}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${username}

    RETURN    ${resp}

Send Log Message to CAPIF
    [Arguments]    ${api_id}    ${service_name}    ${invoker_info}    ${provider_info}    @{results}
    ${api_ids}=    Create List    ${api_id}
    ${api_names}=    Create List    ${service_name}
    ${request_body}=    Create Log Entry
    ...    ${provider_info['aef_id']}
    ...    ${invoker_info['api_invoker_id']}
    ...    ${api_ids}
    ...    ${api_names}
    ...    results=@{results}
    ${resp}=    Post Request Capif
    ...    /api-invocation-logs/v1/${provider_info['aef_id']}/logs
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${provider_info['amf_username']}

    Check Response Variable Type And Values    ${resp}    201    InvocationLog
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_LOGGING_RESOURCE_REGEX}

    RETURN    ${request_body}

Check not valid ${resp} with event filter ${attribute_snake_case} for event ${event}
    # Check Results
    ${invalid_param}=    Create Dictionary
    ...    param=eventFilter
    ...    reason=The eventFilter {'${attribute_snake_case}'} for event ${event} are not applicable.
    ${invalid_param_list}=    Create List    ${invalid_param}
    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=Bad Param
    ...    cause=Invalid eventFilter for event ${event}
    ...    invalidParams=${invalid_param_list}
