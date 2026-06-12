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
Invoker subscribed to SERVICE_API_AVAILABLE, SERVICE_API_UNAVAILABLE and SERVICE_API_UPDATE events filtered by apiIds
    [Tags]    event_filter-1    mockserver

    # Initialize Mock server
    Init Mock Server

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Create Provider1 with 2 AEF roles and publish API
    ${register_user_info_provider_1}=    Provider Default Registration    total_aef_roles=2
    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_empty_list}=    Create List

    ## Publish API service_1 with 2 aefIds
    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_empty_list}
    ...    supported_features=020

    # Create Provider2 with 1 AEF role and publish API
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_NEW
    ${aef2_id_1}=    Set Variable
    ...    ${register_user_info_provider_2['aef_roles']['${AEF_PROVIDER_USERNAME}_NEW']['aef_id']}

    ## Publish API service_2 with Provider2
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body_2}=    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    service_2
    ...    aef_id=${aef2_id_1}
    ...    api_status=${aef2_id_1}
    ...    supported_features=020

    # Discover APIs by Invoker filtering by aefId1 of Provider1
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_1}

    ## Store apiId for further use
    ${api_id}=    Set Variable    ${resp.json()['serviceAPIDescriptions'][0]['apiId']}

    # Subscribe to events and setup event filter with api_id
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE
    ${event_filter}=    Create Capif Event Filter    apiIds=${api_id}
    ${event_filters}=    Create List    ${event_filter}    ${event_filter}    ${event_filter}
    ${subscription_id}=
    ...    Subscribe invoker ${register_user_info_invoker} to events ${events_list} with event filters ${event_filters}

    # Update Request to published API
    ${service_api_description_modified}=    Create Service Api Description
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    supported_features=020
    ...    api_status=${aef_ids}
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${service_api_description_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Contain Key    ${resp.json()}    apiStatus

    # Remove Providers
    ## Remove Provider1
    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}
    Status Should Be    204    ${resp}

    ## Remove Provider2
    ${resp}=    Delete Request Capif
    ...    ${resource_url_2.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}_NEW
    Status Should Be    204    ${resp}

    # Create check Events to ensure all notifications were received
    ## Service API Available event
    ${service_api_available_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_available_resources=${service_api_available_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_modified}
    Log List    ${events_expected}

    ## Service API Update event
    ${events_expected}=    Create Expected Service Update Event
    ...    subscription_id=${subscription_id}
    ...    service_api_resource=${resource_url}
    ...    service_api_descriptions=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    ## Service API Unavailable event
    ${service_api_unavailable_resources}=    Create List    ${resource_url}
    ${events_expected}=    Create Expected Events For Service API Notifications
    ...    subscription_id=${subscription_id}
    ...    service_api_unavailable_resources=${service_api_unavailable_resources}
    ...    event_detail_expected=${TRUE}
    ...    service_api_description_expected=${TRUE}
    ...    service_api_description=${service_api_description_modified}
    ...    events_expected=${events_expected}
    Log List    ${events_expected}

    # Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Invoker subscribed to SERVICE_API_AVAILABLE, SERVICE_API_UNAVAILABLE and SERVICE_API_UPDATE events filtered by not valid filters
    [Tags]    event_filter-2    smoke

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Create Provider1 with 2 AEF roles and publish API
    ${register_user_info_provider_1}=    Provider Default Registration    total_aef_roles=2
    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_empty_list}=    Create List

    ## Publish API service_1 with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_empty_list}
    ...    supported_features=020

    # Create Provider2 and publish API
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_NEW
    ${aef2_id_1}=    Set Variable
    ...    ${register_user_info_provider_2['aef_roles']['${AEF_PROVIDER_USERNAME}_NEW']['aef_id']}

    ## Publish API service_2
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body_2}=    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    service_2
    ...    aef_id=${aef2_id_1}
    ...    api_status=${aef2_id_1}
    ...    supported_features=020

    # Discover APIs by invoker
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${aef_id_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}
    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

    ## Store apiId for further use
    ${api_id}=    Set Variable    ${resp.json()['serviceAPIDescriptions'][0]['apiId']}

    # Event Subscription
    ## Events list
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ## Event filters
    ${event_filter_empty}=    Create Capif Event Filter
    ${event_filter_aef_ids}=    Create Capif Event Filter    aefIds=${aef_ids}
    ${event_filter_api_ids}=    Create Capif Event Filter    apiIds=${service_api_description_published['apiId']}
    ${event_filter_api_invoker_ids}=    Create Capif Event Filter
    ...    apiInvokerIds=${register_user_info_invoker['api_invoker_id']}

    ## Subscription to Events filtering by aefIds SERVICE_API_AVAILABLE event
    ${event_filters}=    Create List    ${event_filter_aef_ids}    ${event_filter_empty}    ${event_filter_empty}
    ${resp}=
    ...    Subscribe ${register_user_info_invoker['api_invoker_id']} with ${register_user_info_invoker['management_cert']} to ${events_list} with ${event_filters}

    ### Check Error Response
    Check not valid ${resp} with event filter aef_ids for event SERVICE_API_AVAILABLE

    ## Subscription to Events filtering by aefIds SERVICE_API_UNAVAILABLE event
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_aef_ids}    ${event_filter_empty}
    ${resp}=
    ...    Subscribe ${register_user_info_invoker['api_invoker_id']} with ${register_user_info_invoker['management_cert']} to ${events_list} with ${event_filters}

    ### Check Error Response
    Check not valid ${resp} with event filter aef_ids for event SERVICE_API_UNAVAILABLE

    ## Subscription to Events filtering by aefIds SERVICE_API_UPDATE event
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_empty}    ${event_filter_aef_ids}
    ${resp}=
    ...    Subscribe ${register_user_info_invoker['api_invoker_id']} with ${register_user_info_invoker['management_cert']} to ${events_list} with ${event_filters}

    ### Check Error Response
    Check not valid ${resp} with event filter aef_ids for event SERVICE_API_UPDATE

    ## Subscription to Events filtering by api invoker ids SERVICE_API_UPDATE event
    ${event_filters}=    Create List
    ...    ${event_filter_empty}
    ...    ${event_filter_empty}
    ...    ${event_filter_api_invoker_ids}
    ${resp}=
    ...    Subscribe ${register_user_info_invoker['api_invoker_id']} with ${register_user_info_invoker['management_cert']} to ${events_list} with ${event_filters}

    ### Check Error Response
    Check not valid ${resp} with event filter api_invoker_ids for event SERVICE_API_UPDATE

Provider subscribed to API_INVOKER_ONBOARDED, API_INVOKER_OFFBOARDED and API_INVOKER_UPDATED events filtered by invokerIds
    [Tags]    event_filter-3    mockserver

    # Initialize Mock server
    Init Mock Server

    # Create Provider1 with 2 AEF roles and publish API
    ## Create Provider with 2 AEF roles
    ${register_user_info_provider_1}=    Provider Default Registration

    # Event Subscription
    ## Event list
    ${events_list}=    Create List    API_INVOKER_ONBOARDED
    ## Event filters
    ${event_filter}=    Create Capif Event Filter
    ## Subscribe API_INVOKER_ONBOARDED event without filters
    ${event_filters}=    Create List    ${event_filter}
    ${subscription_id_1}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    # Default Invokers Registration and Onboarding
    # Default Invoker 1 Registration and Onboarding
    ${register_user_info_invoker_1}    ${invoker_url_1}    ${invoker_request_body_1}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_1
    ${api_invoker_id_1}=    Set Variable    ${register_user_info_invoker_1['api_invoker_id']}

    # Default Invoker 2 Registration and Onboarding
    ${register_user_info_invoker_2}    ${invoker_url_2}    ${invoker_request_body_2}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_2
    ${api_invoker_id_2}=    Set Variable    ${register_user_info_invoker_2['api_invoker_id']}

    # Subscribe to events and setup event filter with api_invoker_id
    ## Events list
    ${events_list}=    Create List    API_INVOKER_ONBOARDED    API_INVOKER_OFFBOARDED    API_INVOKER_UPDATED
    ## Event filters
    ${event_filter_empty}=    Create Capif Event Filter
    ${event_filter_invoker_id_1}=    Create Capif Event Filter    apiInvokerIds=${api_invoker_id_1}
    ${event_filter_invoker_id_2}=    Create Capif Event Filter    apiInvokerIds=${api_invoker_id_2}

    ## Subscribe to Invoker events. API_INVOKER_ONBOARDED event can be filtered by apiInvokerId but is not possible to get it before the invoker is registered
    ${event_filters}=    Create List
    ...    ${event_filter_empty}
    ...    ${event_filter_invoker_id_1}
    ...    ${event_filter_invoker_id_2}
    ${subscription_id_2}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    # Update Invokers
    ## Update Invoker 1
    ${new_notification_destination}=    Set Variable
    ...    http://${CAPIF_CALLBACK_IP}:${CAPIF_CALLBACK_PORT}/netapp_new_callback_1
    Set To Dictionary
    ...    ${invoker_request_body_1}
    ...    notificationDestination=${new_notification_destination}
    ${resp}=    Put Request Capif
    ...    ${invoker_url_1.path}
    ...    ${invoker_request_body_1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}_1
    Check Response Variable Type And Values    ${resp}    200    APIInvokerEnrolmentDetails
    ...    notificationDestination=${new_notification_destination}

    ## Update Invoker 1
    ${new_notification_destination}=    Set Variable
    ...    http://${CAPIF_CALLBACK_IP}:${CAPIF_CALLBACK_PORT}/netapp_new_callback_2
    Set To Dictionary
    ...    ${invoker_request_body_2}
    ...    notificationDestination=${new_notification_destination}
    ${resp}=    Put Request Capif
    ...    ${invoker_url_2.path}
    ...    ${invoker_request_body_2}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}_2
    Check Response Variable Type And Values    ${resp}    200    APIInvokerEnrolmentDetails
    ...    notificationDestination=${new_notification_destination}

    # Remove invokers
    ## Remove Invoker 1
    ${resp}=    Delete Request Capif
    ...    ${invoker_url_1.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}_1
    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${invoker_url_1.path}
    Should Be Equal As Strings    ${resp.status_code}    204

    ## Remove Invoker 2
    ${resp}=    Delete Request Capif
    ...    ${invoker_url_2.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}_2
    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${invoker_url_2.path}
    Should Be Equal As Strings    ${resp.status_code}    204

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ${invoker_urls_both}=    Create List    ${invoker_url_1}    ${invoker_url_2}
    ${invoker_urls_1}=    Create List    ${invoker_url_1}
    ${invoker_urls_2}=    Create List    ${invoker_url_2}
    ${events_expected}=    Create Expected Api Invoker Events
    ...    ${subscription_id_1}
    ...    api_invoker_onboarded_resources=${invoker_urls_both}
    ...    event_detail_expected=${TRUE}
    ${events_expected}=    Create Expected Api Invoker Events
    ...    ${subscription_id_2}
    ...    events_expected=${events_expected}
    ...    api_invoker_updated_resources=${invoker_urls_2}
    ...    api_invoker_offboarded_resources=${invoker_urls_1}
    ...    event_detail_expected=${TRUE}
    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider subscribed to API_INVOKER_ONBOARDED, API_INVOKER_OFFBOARDED and API_INVOKER_UPDATED events filtered by not valid filters
    [Tags]    event_filter-4

    # Register APF
    ${register_user_info_provider_1}=    Provider Default Registration    total_aef_roles=2

    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}
    ${aef_empty_list}=    Create List

    # Publish api with 2 aefIds
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_1
    ...    aef_id=${aef_ids}
    ...    api_status=${aef_empty_list}
    ...    supported_features=020

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker_1}    ${invoker_url_1}    ${invoker_request_body_1}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_1
    ${api_invoker_id_1}=    Set Variable    ${register_user_info_invoker_1['api_invoker_id']}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker_2}    ${invoker_url_2}    ${invoker_request_body_2}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_2
    ${api_invoker_id_2}=    Set Variable    ${register_user_info_invoker_2['api_invoker_id']}

    # Subscribe to events
    ${events_list}=    Create List    API_INVOKER_ONBOARDED    API_INVOKER_OFFBOARDED    API_INVOKER_UPDATED
    ${event_filter_empty}=    Create Capif Event Filter
    ${event_filter_aef_ids}=    Create Capif Event Filter    aefIds=${aef_ids}
    ${event_filter_api_ids}=    Create Capif Event Filter    apiIds=${service_api_description_published['apiId']}
    ${event_filter_invoker_id_2}=    Create Capif Event Filter    apiInvokerIds=${api_invoker_id_2}

    ## Event subscription with event filters by aef_ids
    ${event_filters}=    Create List    ${event_filter_aef_ids}    ${event_filter_empty}    ${event_filter_empty}
    ${resp}=
    ...    Subscribe ${register_user_info_provider_1['amf_id']} with ${register_user_info_provider_1['amf_username']} to ${events_list} with ${event_filters}

    ### Check Results
    Check not valid ${resp} with event filter aef_ids for event API_INVOKER_ONBOARDED

    ## Event subcription API_INVOKER_OFFBOARDED filtered by aef_ids
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_aef_ids}    ${event_filter_empty}
    ${resp}=
    ...    Subscribe ${register_user_info_provider_1['amf_id']} with ${register_user_info_provider_1['amf_username']} to ${events_list} with ${event_filters}

    ### Check Results
    Check not valid ${resp} with event filter aef_ids for event API_INVOKER_OFFBOARDED

    ## Event subcription API_INVOKER_UPDATED filtered by aef_ids
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_empty}    ${event_filter_aef_ids}
    ${resp}=
    ...    Subscribe ${register_user_info_provider_1['amf_id']} with ${register_user_info_provider_1['amf_username']} to ${events_list} with ${event_filters}

    ### Check Results
    Check not valid ${resp} with event filter aef_ids for event API_INVOKER_UPDATED

    ## Event subcription API_INVOKER_UPDATED filtered by api_ids
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_empty}    ${event_filter_api_ids}
    ${resp}=
    ...    Subscribe ${register_user_info_provider_1['amf_id']} with ${register_user_info_provider_1['amf_username']} to ${events_list} with ${event_filters}

    ### Check Results
    Check not valid ${resp} with event filter api_ids for event API_INVOKER_UPDATED

Provider subscribed to ACCESS_CONTROL_POLICY_UPDATE event filtered by only apiId, only invokerId and both
    [Tags]    event_filter-5    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Create Providers
    ## Default Provider 1 Registration
    ${register_user_info_provider_1}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_1

    ## Publish service_1 API
    ${service_api_description_published_1}
    ...    ${provider_resource_url_1}
    ...    ${provider_request_body_1}=
    ...    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_name=service_1

    ## Default Provider 2 Registration
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_2

    ## Publish service_2 API
    ${service_api_description_published_2}
    ...    ${provider_resource_url_2}
    ...    ${provider_request_body_2}=
    ...    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    service_name=service_2

    ## Store apiId1 and apiId2 for further use
    ${service_api_id_1}=    Set Variable    ${service_api_description_published_1['apiId']}
    ${service_api_id_2}=    Set Variable    ${service_api_description_published_2['apiId']}

    # Register Invokers
    ## Default Invoker1 onboarding
    ${register_user_info_invoker_1}    ${invoker_url_1}    ${request_body_1}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_1

    ## Default Invoker1 onboarding
    ${register_user_info_invoker_2}    ${invoker_url_2}    ${request_body_2}=    Invoker Default Onboarding
    ...    invoke_username=${INVOKER_USERNAME}_2

    ## Store apiInvokerIds for further use
    ${api_invoker_id_1}=    Set Variable    ${register_user_info_invoker_1['api_invoker_id']}
    ${api_invoker_id_2}=    Set Variable    ${register_user_info_invoker_2['api_invoker_id']}

    # Subscribe to events
    ## Events list
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UPDATE

    ## Create Event filters
    ${event_filter_api_invoker_ids}=    Create Capif Event Filter    apiInvokerIds=${api_invoker_id_1}
    ${event_filter_api_ids}=    Create Capif Event Filter    apiIds=${service_api_id_1}
    ${event_filter_api_invoker_ids_and_api_ids}=    Create Capif Event Filter
    ...    apiInvokerIds=${api_invoker_id_2}
    ...    apiIds=${service_api_id_2}

    ## Subscription to Events 1
    ${event_filters}=    Create List    ${event_filter_api_ids}
    ${subscription_id_1}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 2
    ${event_filters}=    Create List    ${event_filter_api_invoker_ids}
    ${subscription_id_2}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 3
    ${event_filters}=    Create List    ${event_filter_api_invoker_ids_and_api_ids}
    ${subscription_id_3}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Create Security Contexts and ACLs
    ${acl_provider_1}=
    ...    Create Security Context between ${register_user_info_invoker_1} and ${register_user_info_provider_1}
    ${acl_provider_1}=
    ...    Create Security Context between ${register_user_info_invoker_2} and ${register_user_info_provider_1}

    ${acl_provider_2}=
    ...    Update Security Context between ${register_user_info_invoker_1} and ${register_user_info_provider_2}
    ${acl_provider_2}=
    ...    Update Security Context between ${register_user_info_invoker_2} and ${register_user_info_provider_2}

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ### Subscription 1 Checks
    ${acl_to_check}=    Create List    ${acl_provider_1[0]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_1}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}

    ${acl_to_check}=    Create List    ${acl_provider_1[1]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_1}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ${acl_to_check}=    Create List    ${acl_provider_1[0]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_1}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ${acl_to_check}=    Create List    ${acl_provider_1[1]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_1}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ### Subscription 2 checks
    ${acl_to_check}=    Create List    ${acl_provider_1[0]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_2}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ${acl_to_check}=    Create List    ${acl_provider_1[0]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_2}
    ...    ${service_api_id_1}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ${acl_to_check}=    Create List    ${acl_provider_2[0]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_2}
    ...    ${service_api_id_2}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    ### Subscription 3 checks
    ${acl_to_check}=    Create List    ${acl_provider_2[1]}
    ${events_expected}=    Create Expected Access Control Policy Update Event
    ...    ${subscription_id_3}
    ...    ${service_api_id_2}
    ...    ${acl_to_check}
    ...    events_expected=${events_expected}

    Log List    ${events_expected}

    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Provider subscribed to ACCESS_CONTROL_POLICY_UPDATE event filtered by aefId
    [Tags]    event_filter-6

    # Create Provider
    ## Default Provider 1 Registration
    ${register_user_info_provider_1}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_1
    ${aef_id_1}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}

    # Publish one api
    ${service_api_description_published_1}
    ...    ${provider_resource_url_1}
    ...    ${provider_request_body_1}=
    ...    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_name=service_1

    # Store apiId1
    ${service_api_id_1}=    Set Variable    ${service_api_description_published_1['apiId']}

    # Subscribe to events
    ## Event lists
    ${events_list}=    Create List    ACCESS_CONTROL_POLICY_UPDATE

    ## Event filters
    ${event_filter_aef_id}=    Create Capif Event Filter    aefIds=${aef_id_1}

    ## Subscription to Events 1
    ${event_filters}=    Create List    ${event_filter_aef_id}
    ${resp}=
    ...    Subscribe ${register_user_info_provider_1['amf_id']} with ${register_user_info_provider_1['amf_username']} to ${events_list} with ${event_filters}

    ### Check Error Response
    Check not valid ${resp} with event filter aef_ids for event ACCESS_CONTROL_POLICY_UPDATE

Provider subscribed to SERVICE_API_INVOCATION_SUCCESS and SERVICE_API_INVOCATION_FAILURE filtered by apiId, invokerId, aefId and all of them
    [Tags]    event_filter-7    mockserver    smoke

    # Initialize Mock server
    Init Mock Server

    # Register Providers
    ## Default Provider 1 Registration
    ${register_user_info_provider_1}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_1
    ${aef_id_1}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}

    ## Publish service_1 API
    ${service_api_description_published_1}
    ...    ${provider_resource_url_1}
    ...    ${provider_request_body_1}=
    ...    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    service_name=service_1

    ## Default Provider 2 Registration
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_2
    ${aef_id_2}=    Set Variable
    ...    ${register_user_info_provider_2['aef_roles']['${AEF_PROVIDER_USERNAME}_2']['aef_id']}

    ## Publish service_2 API
    ${service_api_description_published_2}
    ...    ${provider_resource_url_2}
    ...    ${provider_request_body_2}=
    ...    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    service_name=service_2

    ## Store apiId1 and apiId2 for further use
    ${service_api_id_1}=    Set Variable    ${service_api_description_published_1['apiId']}
    ${service_api_id_2}=    Set Variable    ${service_api_description_published_2['apiId']}

    # Register Invokers
    ## Default Invoker 1 Registration and Onboarding
    ${register_user_info_invoker_1}    ${invoker_url_1}    ${request_body_1}=    Invoker Default Onboarding
    ...    invoker_username=${INVOKER_USERNAME}_1

    ## Default Invoker 2 Registration and Onboarding
    ${register_user_info_invoker_2}    ${invoker_url_2}    ${request_body_2}=    Invoker Default Onboarding
    ...    invoke_username=${INVOKER_USERNAME}_2

    ## Store apiInvokerIds for further use
    ${api_invoker_id_1}=    Set Variable    ${register_user_info_invoker_1['api_invoker_id']}
    ${api_invoker_id_2}=    Set Variable    ${register_user_info_invoker_2['api_invoker_id']}

    # Subscribe to events
    ## Event lists
    ${events_list}=    Create List    SERVICE_API_INVOCATION_SUCCESS    SERVICE_API_INVOCATION_FAILURE

    ## Event filters
    ${event_filter_empty}=    Create Capif Event Filter
    ${event_filter_api_invoker_ids}=    Create Capif Event Filter    apiInvokerIds=${api_invoker_id_1}
    ${event_filter_api_ids}=    Create Capif Event Filter    apiIds=${service_api_id_1}
    ${event_filter_aef_ids}=    Create Capif Event Filter    aefIds=${aef_id_2}
    ${event_filter_api_ids_and_aef_ids}=    Create Capif Event Filter
    ...    apiIds=${service_api_id_2}
    ...    aefIds=${aef_id_2}
    ${event_filter_api_ids_and_api_invoker_ids}=    Create Capif Event Filter
    ...    apiInvokerIds=${api_invoker_id_2}
    ...    apiIds=${service_api_id_2}
    ${event_filter_aef_ids_and_api_invoker_ids}=    Create Capif Event Filter
    ...    apiInvokerIds=${api_invoker_id_2}
    ...    aefIds=${aef_id_1}
    ${event_filter_api_ids_aef_ids_and_api_invoker_ids}=    Create Capif Event Filter
    ...    apiInvokerIds=${api_invoker_id_2}
    ...    aefIds=${aef_id_2}
    ...    apiIds=${service_api_id_2}

    ## Subscription to Events 1
    ${event_filters}=    Create List    ${event_filter_api_ids}    ${event_filter_api_ids}
    ${subscription_id_1}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 2
    ${event_filters}=    Create List    ${event_filter_aef_ids}    ${event_filter_aef_ids}
    ${subscription_id_2}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 3
    ${event_filters}=    Create List    ${event_filter_api_invoker_ids}    ${event_filter_api_invoker_ids}
    ${subscription_id_3}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 4
    ${event_filters}=    Create List    ${event_filter_api_ids_and_aef_ids}    ${event_filter_api_ids_and_aef_ids}
    ${subscription_id_4}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 5
    ${event_filters}=    Create List
    ...    ${event_filter_api_ids_and_api_invoker_ids}
    ...    ${event_filter_api_ids_and_api_invoker_ids}
    ${subscription_id_5}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 6
    ${event_filters}=    Create List
    ...    ${event_filter_aef_ids_and_api_invoker_ids}
    ...    ${event_filter_aef_ids_and_api_invoker_ids}
    ${subscription_id_6}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    ## Subscription to Events 7
    ${event_filters}=    Create List
    ...    ${event_filter_api_ids_aef_ids_and_api_invoker_ids}
    ...    ${event_filter_api_ids_aef_ids_and_api_invoker_ids}
    ${subscription_id_7}=
    ...    Subscribe provider ${register_user_info_provider_1} to events ${events_list} with event filters ${event_filters}

    # 1.Log entry for service_1 and invoker_1
    ${request_body_log_1}=    Send Log Message to CAPIF
    ...    ${service_api_id_1}
    ...    service_1
    ...    ${register_user_info_invoker_1}
    ...    ${register_user_info_provider_1}
    ...    200
    ...    400

    # 2.Log entry for service_2 and invoker_1
    ${request_body_log_2}=    Send Log Message to CAPIF
    ...    ${service_api_id_2}
    ...    service_2
    ...    ${register_user_info_invoker_1}
    ...    ${register_user_info_provider_2}
    ...    200

    # 3.Log entry for service_2 and invoker_2
    ${request_body_log_3}=    Send Log Message to CAPIF
    ...    ${service_api_id_2}
    ...    service_2
    ...    ${register_user_info_invoker_2}
    ...    ${register_user_info_provider_2}
    ...    200

    # 4.Log entry for service_1 and invoker_2
    ${request_body_log_4}=    Send Log Message to CAPIF
    ...    ${service_api_id_1}
    ...    service_1
    ...    ${register_user_info_invoker_2}
    ...    ${register_user_info_provider_1}
    ...    400

    # Check Event Notifications
    ## Create check Events to ensure all notifications were received
    ### Subscription 1 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_1}
    ...    ${request_body_log_1}

    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_1}
    ...    ${request_body_log_4}
    ...    events_expected=${events_expected}

    ### Subcription 2 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_2}
    ...    ${request_body_log_2}
    ...    events_expected=${events_expected}

    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_2}
    ...    ${request_body_log_3}
    ...    events_expected=${events_expected}

    # Subscription 3 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_3}
    ...    ${request_body_log_1}
    ...    events_expected=${events_expected}

    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_3}
    ...    ${request_body_log_2}
    ...    events_expected=${events_expected}

    # Subscription 4 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_4}
    ...    ${request_body_log_2}
    ...    events_expected=${events_expected}

    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_4}
    ...    ${request_body_log_3}
    ...    events_expected=${events_expected}

    # Subscription 5 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_5}
    ...    ${request_body_log_3}
    ...    events_expected=${events_expected}

    # Subscription 6 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_6}
    ...    ${request_body_log_4}
    ...    events_expected=${events_expected}

    # Subscription 7 Checks
    ${events_expected}=    Create Events From InvocationLogs
    ...    ${subscription_id_7}
    ...    ${request_body_log_3}
    ...    events_expected=${events_expected}

    Log List    ${events_expected}
    ## Check Events Expected towards received notifications at mock server
    Wait Until Keyword Succeeds    5x    5s    Check Mock Server Notification Events    ${events_expected}

Event Filter present with Enhanced_event_report feature not active
    [Tags]    event_filter-8    smoke

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Event Subscription
    ## Events list
    ${events_list}=    Create List    SERVICE_API_AVAILABLE    SERVICE_API_UNAVAILABLE    SERVICE_API_UPDATE

    ## Event filters
    ${event_filter_empty}=    Create Capif Event Filter

    ## Subscription to Events filtering by aefIds SERVICE_API_AVAILABLE event
    ${event_filters}=    Create List    ${event_filter_empty}    ${event_filter_empty}    ${event_filter_empty}
    ${resp}=    Subscribe Events    ${register_user_info_invoker['api_invoker_id']}    ${register_user_info_invoker['management_cert']}    ${events_list}    ${event_filters}    0

    ### Check Error Response
    ${invalid_param}=    Create Dictionary
    ...    param=eventFilters
    ...    reason=EnhancedEventReport is not enabled
    ${invalid_param_list}=    Create List    ${invalid_param}
    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=Bad Param
    ...    cause=Event filters provided but EnhancedEventReport is not enabled
    ...    invalidParams=${invalid_param_list}


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

Subscribe ${subscriber_id} with ${username} to ${events_list} with ${event_filters}
    ${supported_features}=    Set Variable    C
    ${resp}=   Subscribe Events    ${subscriber_id}    ${username}    ${events_list}    ${event_filters}    ${supported_features}
    RETURN   ${resp}

Subscribe Events
    [Arguments]    ${subscriber_id}    ${username}    ${events_list}    ${event_filters}=${NONE}    ${supported_features}=0
    ${request_body}=    Create Events Subscription
    ...    events=@{events_list}
    ...    notification_destination=${NOTIFICATION_DESTINATION_URL}/testing
    ...    supported_features=${supported_features}
    ...    event_filters=${event_filters}
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
    ...    username=${provider_info['aef_username']}

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
