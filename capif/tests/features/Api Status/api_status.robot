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
Publish without apiStatus feature receive eventDetails with serviceAPIDescription
    [Tags]    api_status-1    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish without apiStatus feature receive eventDetails without serviceAPIDescription
    [Tags]    api_status-2    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

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

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish without apiStatus feature receive eventDetails without eventDetails (apiMonitoringStatus active)
    [Tags]    api_status-3    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=8
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${FALSE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish without apiStatus feature receive eventDetails without eventDetails
    [Tags]    api_status-4    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

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

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${FALSE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus present but apiStatusMonitoring inactive receive bad Request
    [Tags]    api_status-5    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${resp}    ${request_body}=    Publish Service Api Request
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=000

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed
    ...    cause=apiStatus can't be set if apiStatusMonitoring is inactive

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    title=Not Found
    ...    status=404
    ...    detail=API Invoker ${register_user_info_invoker['api_invoker_id']} has no API Published that accomplish filter conditions
    ...    cause=No API Published accomplish filter conditions

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${events_expected}=    Create List
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus feature active receive eventDetails with serviceAPIDescription
    [Tags]    api_status-6    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus active feature receive eventDetails without serviceAPIDescription
    [Tags]    api_status-7    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

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

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus active feature receive eventDetails without eventDetails with apiStatus (apiMonitoringStatus active)
    [Tags]    api_status-8    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=8
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${FALSE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus active feature receive eventDetails without eventDetails
    [Tags]    api_status-9    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

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

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${FALSE}
    ...    service_api_description_expected=${FALSE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus feature active no aefId active receive eventDetails with serviceAPIDescription with apiStatus empty array
    [Tags]    api_status-10    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_ids_empty_array}=    Create List

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_ids_empty_array}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Publish with apiStatus not present but apiStatusMonitoring feature active receive eventDetails with serviceAPIDescription without apiStatus
    [Tags]    api_status-11    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${NONE}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Update published API without apiStatus and apiStatusMonitoring inactive
    [Tags]    api_status-12    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=000
    ...    api_status=${NONE}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Not Contain Key    ${resp.json()}    apiStatus

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Update published API with apiStatus empty and apiStatusMonitoring inactive
    [Tags]    api_status-13    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${aef_empty_list}=    Create List
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=000
    ...    api_status=${aef_empty_list}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed
    ...    cause=apiStatus can't be set if apiStatusMonitoring is inactive

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Update published API with apiStatus empty and apiStatusMonitoring active
    [Tags]    api_status-14    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_empty_list}=    Create List

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=020
    ...    api_status=${aef_empty_list}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Update published API with apiStatus only aef2 and apiStatusMonitoring active
    [Tags]    api_status-15    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=020
    ...    api_status=${aef_id_2}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Published API without aefs available updated to one aef available
    [Tags]    api_status-16    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_empty_list}=    Create List

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_empty_list}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Contain Key    ${resp.json()['serviceAPIDescriptions'][0]}    apiStatus

    # Update Request to published API
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=020
    ...    api_status=${aef_id_2}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    # Provider Remove service_1 published API
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Patch published (apiStatusMonitoring active) API with apiStatus only aefId2
    [Tags]    api_status-17    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${aef_empty_list}=    Create List
    ${service_api_description_patch}=    Create Service Api Description Patch
    ...    api_status=${aef_id_2}
    Check Variable    ${service_api_description_patch}    ServiceAPIDescriptionPatch
    ${resp}=    Patch Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_patch}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    ${service_api_to_check}=    Copy Dictionary    ${service_api_description_published}    deepcopy=${True}
    ${aef_ids_expected}=    Create List    ${aef_id_2}
    ${api_status_expected}=    Create dictionary    aefIds=${aef_ids_expected}
    Set To Dictionary    ${service_api_to_check}    apiStatus=${api_status_expected}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1

    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    Dictionaries Should Be Equal    ${resp.json()['apiStatus']}    ${service_api_description_patch['apiStatus']}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_to_check}
    ...    events_expected=${events_expected}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Patch published (apiStatusMonitoring active) API with apiStatus aef1 and aef2
    [Tags]    api_status-18    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    # Update Request to published API
    ${aef_empty_list}=    Create List
    ${service_api_description_patch}=    Create Service Api Description Patch
    ...    api_status=${aef_ids}
    ${resp}=    Patch Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_patch}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    ${service_api_to_check}=    Copy Dictionary    ${service_api_description_published}    deepcopy=${True}
    ${api_status_expected}=    Create dictionary    aefIds=${aef_ids}
    Set To Dictionary    ${service_api_to_check}    apiStatus=${api_status_expected}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1

    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    Dictionaries Should Be Equal    ${resp.json()['apiStatus']}    ${service_api_description_patch['apiStatus']}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}

    Log List    ${events_expected}
    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_to_check}
    ...    events_expected=${events_expected}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Patch published (apiStatusMonitoring inactive) API with apiStatus aefId1 and aefId2
    [Tags]    api_status-19    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${resp}    ${request_body}=    Publish Service Api Request
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_id_1}
    ...    supported_features=000

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed
    ...    cause=apiStatus can't be set if apiStatusMonitoring is inactive

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    404
    ...    ProblemDetails
    ...    title=Not Found
    ...    status=404
    ...    detail=API Invoker ${register_user_info_invoker['api_invoker_id']} has no API Published that accomplish filter conditions
    ...    cause=No API Published accomplish filter conditions

    # Check Event Notifications
    ${events_expected}=    Create List
    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Patch published without aefs available API with apiStatus only aef2
    [Tags]    api_status-20    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Register APF
    ${register_user_info_provider}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_ids_empty_array}=    Create List

    # Subscribe to events
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=C
    ${resp}=    Post Request Capif
    ...    /capif-events/v1/${register_user_info_invoker['api_invoker_id']}/subscriptions
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    EventSubscription
    ${subscriber_id}    ${subscription_id}=    Check Event Location Header    ${resp}

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_ids_empty_array}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}
    Dictionary Should Not Contain Key    ${resp.json()}    apiStatus

    # Update Request to published API
    ${service_api_description_patch}=    Create Service Api Description Patch
    ...    api_status=${aef_ids}
    ${resp}=    Patch Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_patch}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    ${service_api_to_check}=    Copy Dictionary    ${service_api_description_published}    deepcopy=${True}
    ${api_status_expected}=    Create dictionary    aefIds=${aef_ids}
    Set To Dictionary    ${service_api_to_check}    apiStatus=${api_status_expected}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1

    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    Dictionaries Should Be Equal    ${resp.json()['apiStatus']}    ${service_api_description_patch['apiStatus']}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_published}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_to_check}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_to_check}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}
