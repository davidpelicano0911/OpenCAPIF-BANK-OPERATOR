*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             XML
Library             String
Resource            /opt/robot-tests/tests/resources/common/basicRequests.robot
Resource            ../../resources/common.resource

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${API_INVOKER_NOT_REGISTERED}       not-valid
${SUBSCRIBER_ID_NOT_VALID}          not-valid
${SUBSCRIPTION_ID_NOT_VALID}        not-valid


*** Test Cases ***
Creates a new individual CAPIF Event Subscription
    [Tags]    capif_api_events-1    smoke
    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

Creates a new individual CAPIF Event Subscription with Invalid SubscriberId
    [Tags]    capif_api_events-2
    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${SUBSCRIBER_ID_NOT_VALID}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    title=Not Found
    ...    status=404
    ...    detail=Please provide an existing Subscriber ID
    ...    cause=Certificate not found for Invoker or APF or AEF or AMF

Deletes an individual CAPIF Event Subscription
    [Tags]    capif_api_events-3
    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription

    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    ${resp}=    Delete Request Capif
    ...    /capif-events/v1/${subscriber_id}/subscriptions/${subscription_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Status Should Be    204    ${resp}

Deletes an individual CAPIF Event Subscription with invalid SubscriberId
    [Tags]    capif_api_events-4
    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription

    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    ${resp}=    Delete Request Capif
    ...    /capif-events/v1/${SUBSCRIBER_ID_NOT_VALID}/subscriptions/${subscription_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    title=Not Found
    ...    status=404
    ...    detail=Please provide an existing Subscriber ID
    ...    cause=Certificate not found for Invoker or APF or AEF or AMF

Deletes an individual CAPIF Event Subscription with invalid SubscriptionId
    [Tags]    capif_api_events-5

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    201    EventSubscription

    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    ${resp}=    Delete Request Capif
    ...    /capif-events/v1/${subscriber_id}/subscriptions/${SUBSCRIPTION_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    detail=User not authorized
    ...    cause=You are not the owner of this resource

Invoker receives Service API Invocation events
    [Tags]    capif_api_events-6    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish one api
    Publish Service Api    ${register_user_info}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_INVOCATION_SUCCESS    SERVICE_API_INVOCATION_FAILURE
    ${aef_ids}=    Create List    ${register_user_info['aef_id']}
    ${event_filter}=    Create Capif Event Filter    aefIds=${aef_ids}
    ${event_filters}=    Create List    ${event_filter}  ${event_filter}

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    event_filters=${event_filters}
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Create Log Entry, emulate success and failure api invocation
    ${results}=    Create List    200    400
    ${request_body}=    Create Log Entry
    ...    ${register_user_info['aef_id']}
    ...    ${register_user_info_invoker['api_invoker_id']}
    ...    ${api_ids}
    ...    ${api_names}
    ...    results=${results}
    ${resp}=    Post Request Capif
    ...    /api-invocation-logs/v1/${register_user_info['aef_id']}/logs
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    InvocationLog
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_LOGGING_RESOURCE_REGEX}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id}
    ...    ${request_body}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribe to Service API Available and Unavailable events
    [Tags]    capif_api_events-7    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published_1}    ${resource_url_1}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Provider publish new API
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_2

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url_1.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url_2}
    ${service_api_unavailable_resources}=    Create List    ${resource_url_1}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribe to Service API Update
    [Tags]    capif_api_events-8    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ${service_api_id_1}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_UPDATE
    ${api_ids}=    Create List    ${service_api_id_1}
    ${event_filter}=    Create Capif Event Filter    apiIds=${api_ids}
    ${event_filters}=    Create List    ${event_filter}

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    event_filters=${event_filters}
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Update Service API
    ${service_api_description_modified}=    Create Service Api Description    service_1_modified
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1_modified

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Service Update Event
    ...    ${subscription_id}
    ...    ${resource_url}
    ...    ${service_api_description_modified}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider subscribe to API Invoker events
    [Tags]    capif_api_events-9    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Subscribe to events
    ${events_list}=    Create List    API_INVOKER_ONBOARDED    API_INVOKER_UPDATED    API_INVOKER_OFFBOARDED
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Register INVOKER
    ${register_user_info_invoker}    ${invoker_url}    ${request_body}=    Invoker Default Onboarding

    # Update Invoker onboarded information
    ${new_notification_destination}=    Set Variable
    ...    http://${CAPIF_CALLBACK_IP}:${CAPIF_CALLBACK_PORT}/netapp_new_callback
    Set To Dictionary
    ...    ${request_body}
    ...    notificationDestination=${new_notification_destination}
    ${resp}=    Put Request Capif
    ...    ${invoker_url.path}
    ...    ${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Update
    Check Response Variable Type And Values    ${resp}    200    APIInvokerEnrolmentDetails
    ...    notificationDestination=${new_notification_destination}

    # Remove Invoker from CCF
    ${resp}=    Delete Request Capif
    ...    ${invoker_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${invoker_url.path}

    # Check Remove
    Should Be Equal As Strings    ${resp.status_code}    204

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${invoker_urls}=    Create List    ${invoker_url}
    ${events_expected}=    Create Expected Api Invoker Events
    ...    ${subscription_id}
    ...    api_invoker_onboarded_resources=${invoker_urls}
    ...    api_invoker_updated_resources=${invoker_urls}
    ...    api_invoker_offboarded_resources=${invoker_urls}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribed to ACL update event
    [Tags]    capif_api_events-10    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${service_api_id}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UPDATE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_id}?aef-id=${register_user_info_provider['aef_id']}
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

    ${api_invoker_policies}=    Set Variable    ${resp.json()['apiInvokerPolicies']}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id}
    ...    ${service_api_id}
    ...    ${api_invoker_policies}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider receives an ACL unavailable event when invoker remove Security Context.
    [Tags]    capif_api_events-11    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${serviceApiId}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UNAVAILABLE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Remove Security Context by Provider
    ${resp}=    Delete Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Unavailable    ${subscription_id}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker receives an Invoker Authorization Revoked and ACL unavailable event when Provider revoke Invoker Authorization.
    [Tags]    capif_api_events-12    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${serviceApiId}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UNAVAILABLE    API_INVOKER_AUTHORIZATION_REVOKED
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=4
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    ${api_ids}=    Get Api Ids From Discover Response    ${discover_response}

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Revoke Security Context by Provider
    ${request_body}=    Create Security Notification Body
    ...    ${register_user_info_invoker['api_invoker_id']}
    ...    ${api_ids}
    ${resp}=    Post Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}/delete
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Unavailable    ${subscription_id}
    ${events_expected}=    Create Expected Api Invoker Authorization Revoked
    ...    ${subscription_id}
    ...    events_expected=${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Creates a new individual CAPIF Event Subscription without supported features attribute
    [Tags]    capif_api_events-13    smoke
    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Events Subscription    supported_features=${NONE}
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=supportedFeatures not present in request
    ...    cause=supportedFeatures not present

Invoker receives Service API Invocation events without Enhanced Event Report
    [Tags]    capif_api_events-14    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish one api
    Publish Service Api    ${register_user_info}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_INVOCATION_SUCCESS    SERVICE_API_INVOCATION_FAILURE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Create Log Entry, emulate success and failure api invocation
    ${results}=    Create List    200    400
    ${request_body}=    Create Log Entry
    ...    ${register_user_info['aef_id']}
    ...    ${register_user_info_invoker['api_invoker_id']}
    ...    ${api_ids}
    ...    ${api_names}
    ...    results=${results}
    ${resp}=    Post Request Capif
    ...    /api-invocation-logs/v1/${register_user_info['aef_id']}/logs
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    InvocationLog
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_LOGGING_RESOURCE_REGEX}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id}
    ...    ${request_body}
    ...    event_detail_expected=${FALSE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribe to Service API Available and Unavailable events without Enhanced Event Report
    [Tags]    capif_api_events-15    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published_1}    ${resource_url_1}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Provider publish new API
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_2

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url_1.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url_2}
    ${service_api_unavailable_resources}=    Create List    ${resource_url_1}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${FALSE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribe to Service API Update without Enhanced Event Report
    [Tags]    capif_api_events-16    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ${api_ids}    ${api_names}=    Get Api Ids And Names From Discover Response    ${discover_response}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_UPDATE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Update Service API
    ${service_api_description_modified}=    Create Service Api Description    service_1_modified
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1_modified

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Service Update Event
    ...    ${subscription_id}
    ...    ${resource_url}
    ...    ${service_api_description_modified}
    ...    event_detail_expected=${FALSE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider subscribe to API Invoker events without Enhanced Event Report
    [Tags]    capif_api_events-17    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Subscribe to events
    ${events_list}=    Create List    API_INVOKER_ONBOARDED    API_INVOKER_UPDATED    API_INVOKER_OFFBOARDED
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Register INVOKER
    ${register_user_info_invoker}    ${invoker_url}    ${request_body}=    Invoker Default Onboarding

    # Update Invoker onboarded information
    ${new_notification_destination}=    Set Variable
    ...    http://${CAPIF_CALLBACK_IP}:${CAPIF_CALLBACK_PORT}/netapp_new_callback
    Set To Dictionary
    ...    ${request_body}
    ...    notificationDestination=${new_notification_destination}
    ${resp}=    Put Request Capif
    ...    ${invoker_url.path}
    ...    ${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Update
    Check Response Variable Type And Values    ${resp}    200    APIInvokerEnrolmentDetails
    ...    notificationDestination=${new_notification_destination}

    # Remove Invoker from CCF
    ${resp}=    Delete Request Capif
    ...    ${invoker_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${invoker_url.path}

    # Check Remove
    Should Be Equal As Strings    ${resp.status_code}    204

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${invoker_urls}=    Create List    ${invoker_url}
    ${events_expected}=    Create Expected Api Invoker Events
    ...    ${subscription_id}
    ...    api_invoker_onboarded_resources=${invoker_urls}
    ...    api_invoker_updated_resources=${invoker_urls}
    ...    api_invoker_offboarded_resources=${invoker_urls}
    ...    event_detail_expected=${FALSE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribed to ACL update event without Enhanced Event Report
    [Tags]    capif_api_events-18    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${service_api_id}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UPDATE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    ${resp}=    Get Request Capif
    ...    /access-control-policy/v1/accessControlPolicyList/${service_api_id}?aef-id=${register_user_info_provider['aef_id']}
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

    ${api_invoker_policies}=    Set Variable    ${resp.json()['apiInvokerPolicies']}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id}
    ...    ${service_api_id}
    ...    ${api_invoker_policies}
    ...    event_detail_expected=${FALSE}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider receives an ACL unavailable event when invoker remove Security Context without Enhanced Event Report
    [Tags]    capif_api_events-19    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${serviceApiId}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UNAVAILABLE
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_provider['amf_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Remove Security Context by Provider
    ${resp}=    Delete Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Unavailable
    ...    ${subscription_id}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker receives an Invoker Authorization Revoked and ACL unavailable event when Provider revoke Invoker Authorization without Enhanced Event Report
    [Tags]    capif_api_events-20    mockserver

    # Initialize Mock server
    Init Mock Server

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}

    # Store apiId1
    ${serviceApiId}=    Set Variable    ${service_api_description_published['apiId']}

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Subscribe to events
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UNAVAILABLE    API_INVOKER_AUTHORIZATION_REVOKED
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=0
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Test
    ${discover_response}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info_provider['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${discover_response}    200    DiscoveredAPIs

    ${api_ids}=    Get Api Ids From Discover Response    ${discover_response}

    # create Security Context
    ${request_service_security_body}=    Create Service Security From Discover Response
    ...    http://${CAPIF_HOSTNAME}:${CAPIF_HTTP_PORT}/test
    ...    ${discover_response}
    ${resp}=    Put Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}
    ...    json=${request_service_security_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Service Security
    Check Response Variable Type And Values    ${resp}    201    ServiceSecurity
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_SECURITY_RESOURCE_REGEX}

    # Revoke Security Context by Provider
    ${request_body}=    Create Security Notification Body
    ...    ${register_user_info_invoker['api_invoker_id']}
    ...    ${api_ids}
    ${resp}=    Post Request Capif
    ...    /capif-security/v1/trustedInvokers/${register_user_info_invoker['api_invoker_id']}/delete
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AEF_PROVIDER_USERNAME}

    # Check Results
    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create Expected Access Control Policy Unavailable    ${subscription_id}
    ${events_expected}=    Create Expected Api Invoker Authorization Revoked
    ...    ${subscription_id}
    ...    events_expected=${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}
