*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Resource            ../../resources/common/basicRequests.robot
Resource            ../../resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${APF_ID_NOT_VALID}             apf-example
${SERVICE_API_ID_NOT_VALID}     not-valid


*** Test Cases ***
Publish API by Authorised API Publisher
    [Tags]    capif_api_publish_service-1    smoke
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Test
    ${request_body}=    Create Service Api Description    service_1
    ${resp}=    Post Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    201    ServiceAPIDescription
    ...    apiName=service_1
    Dictionary Should Contain Key    ${resp.json()}    apiId
    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_PUBLISH_RESOURCE_REGEX}

Publish API by NON Authorised API Publisher
    [Tags]    capif_api_publish_service-2
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${request_body}=    Create Service Api Description
    ${resp}=    Post Request Capif
    ...    /published-apis/v1/${APF_ID_NOT_VALID}/service-apis
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    status=401
    ...    title=Unauthorized
    ...    detail=Please provide an existing APF ID
    ...    cause=Certificate not found for APF

Retrieve all APIs Published by Authorised apfId
    [Tags]    capif_api_publish_service-3    smoke
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Register One Service
    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1
    ${service_api_description_published_2}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_2

    # Retrieve Services published
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription

    List Should Contain Value    ${resp.json()}    ${service_api_description_published_1}
    List Should Contain Value    ${resp.json()}    ${service_api_description_published_2}

Retrieve all APIs Published by NON Authorised apfId
    [Tags]    capif_api_publish_service-4
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Retrieve Services published
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${APF_ID_NOT_VALID}/service-apis
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=Please provide an existing APF ID
    ...    cause=Certificate not found for APF

Retrieve single APIs Published by Authorised apfId
    [Tags]    capif_api_publish_service-5
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1
    ${service_api_description_published_2}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_2

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}
    ${serviceApiId2}=    Set Variable    ${service_api_description_published_2['apiId']}

    # Retrieve Services 1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${serviceApiId1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_1}

    # Retrieve Services 1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${serviceApiId2}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_2}

Retrieve single APIs non Published by Authorised apfId
    [Tags]    capif_api_publish_service-6
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${SERVICE_API_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    detail=User not authorized
    ...    cause=You are not the owner of this resource

Retrieve single APIs Published by NON Authorised apfId
    [Tags]    capif_api_publish_service-7
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish Service API
    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${resp}=    Get Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=User not authorized
    ...    cause=Certificate not authorized

Update API Published by Authorised apfId with valid serviceApiId
    [Tags]    capif_api_publish_service-8
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1

    ${request_body_modified}=    Create Service Api Description    service_1_modified
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${request_body_modified}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1_modified

    # Retrieve Service
    ${resp}=    Get Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1_modified

Update APIs Published by Authorised apfId with invalid serviceApiId
    [Tags]    capif_api_publish_service-9
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1

    ${request_body}=    Create Service Api Description    service_1_modified
    ${resp}=    Put Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${SERVICE_API_ID_NOT_VALID}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    detail=User not authorized
    ...    cause=You are not the owner of this resource

Update APIs Published by NON Authorised apfId
    [Tags]    capif_api_publish_service-10
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${request_body}=    Create Service Api Description    service_1_modified
    ${resp}=    Put Request Capif
    ...    ${resource_url.path}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=User not authorized
    ...    cause=Certificate not authorized

    # Retrieve Service
    ${resp}=    Get Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    ...    apiName=service_1

Delete API Published by Authorised apfId with valid serviceApiId
    [Tags]    capif_api_publish_service-11    smoke
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    first_service

    ${resp}=    Delete Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    ${resp}=    Get Request Capif
    ...    ${resource_url.path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    title=Not Found
    ...    detail=Service API not found
    ...    cause=No Service with specific credentials exists

Delete APIs Published by Authorised apfId with invalid serviceApiId
    [Tags]    capif_api_publish_service-12
    # Register APF
    ${register_user_info}=    Provider Default Registration

    ${resp}=    Delete Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${SERVICE_API_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    detail=User not authorized
    ...    cause=You are not the owner of this resource

Delete APIs Published by NON Authorised apfId
    [Tags]    capif_api_publish_service-13
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Register INVOKER
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    ${resp}=    Delete Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${SERVICE_API_ID_NOT_VALID}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    401    ProblemDetails
    ...    title=Unauthorized
    ...    status=401
    ...    detail=User not authorized
    ...    cause=Certificate not authorized

Check Two Published APIs with different APFs are removed when Provider is deleted
    [Tags]    capif_api_publish_service-14
    # Register APF with 2 APF roles
    ${register_user_info}=    Provider Default Registration    total_apf_roles=2

    # Publish APIs with both APFs
    ${service_api_description_published_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_1
    ${service_api_description_published_2}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    service_2
    ...    apf_username=${APF_PROVIDER_USERNAME}_1

    # Store apiId1
    ${serviceApiId1}=    Set Variable    ${service_api_description_published_1['apiId']}
    ${serviceApiId2}=    Set Variable    ${service_api_description_published_2['apiId']}

    # Retrieve Service1
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis/${serviceApiId1}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_1}

    # Retrieve Service2
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info['apf_roles']['${APF_PROVIDER_USERNAME}_1']['apf_id']}/service-apis/${serviceApiId2}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}_1

    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    Dictionaries Should Be Equal    ${resp.json()}    ${service_api_description_published_2}

    # Get all services present at CCF
    ${services_present_on_ccf_after_publish}=    Get Number Of Services

    # Delete Provider using AMF cert
    ${resp}=    Delete Request Capif
    ...    ${register_user_info['resource_url'].path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${register_user_info['resource_url'].path}

    ${services_present_on_ccf_after_delete_provider}=    Get Number Of Services

    ${services_removed}=   Evaluate    ${services_present_on_ccf_after_publish} - ${services_present_on_ccf_after_delete_provider}

    Run Keyword And Continue On Failure    Should Be Equal    "${services_removed}"    "2"      msg=Not all services removed after delete provider (removed) vs (expected)

    # # Remove service API by superadmin
    # ${resp}=    Delete Request Capif
    # ...    /published-apis/v1/${register_user_info['apf_roles']['${APF_PROVIDER_USERNAME}_1']['apf_id']}/service-apis/${serviceApiId2}
    # ...    server=${CAPIF_HTTPS_URL}
    # ...    verify=ca.crt
    # ...    username=${SUPERADMIN_USERNAME}

    # ${services_present_on_ccf_after_provider_deletion_superadmin}=    Get Number Of Services

    # ${services_removed}=   Evaluate    ${services_present_on_ccf_after_publish} - ${services_present_on_ccf_after_provider_deletion_superadmin}
    
    # Run Keyword And Continue On Failure   Should Be Equal    "${services_removed}"    "2"      msg=Not all services removed after delete provider (removed) vs (expected)


Publish API same apiName but different AEF
    [Tags]    capif_api_publish_service-15  smoke

    # Set API name
    ${api_name}=  Set Variable    testing_robot_service_1

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Create Provider1 with 2 AEF roles and publish API
    ${register_user_info_provider_1}=    Provider Default Registration    total_aef_roles=2
    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable
    ...    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}

    ## Publish API service_1 with aefIds_1
    ${service_api_description_published_1_1}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    ${api_name}
    ...    aef_id=${aef_id_1}

    ## Publish API service_1 with aefIds_2
    ${service_api_description_published_1_2}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info_provider_1}
    ...    ${api_name}
    ...    aef_id=${aef_id_2}

    # Create Provider2 with 1 AEF role and publish API
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_NEW
    ${aef2_id_1}=    Set Variable
    ...    ${register_user_info_provider_2['aef_roles']['${AEF_PROVIDER_USERNAME}_NEW']['aef_id']}

    ## Publish API service_1 with Provider2
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body_2}=    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    ${api_name}
    ...    aef_id=${aef2_id_1}

    # Validation of final scenario.
    ## Check if there are 2 API published with same apiName but different AEFs by retrieving all APIs for provider 1 using APF provider credentials
    ### Retrieve Services published
    ${resp}=    Get Request Capif
    ...    /published-apis/v1/${register_user_info_provider_1['apf_id']}/service-apis
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${APF_PROVIDER_USERNAME}

    ### Validate response and values obtained
    Check Response Variable Type And Values    ${resp}    200    ServiceAPIDescription
    #### Check returned values
    List Should Contain Value    ${resp.json()}    ${service_api_description_published_1_1}
    List Should Contain Value    ${resp.json()}    ${service_api_description_published_1_2}

    ## Check if there are 3 API published with same apiName but different AEFs
    ### Discover API published by retrieving all APIs for Invoker using Invoker credentials
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&api_name=${api_name}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ### Validate response and values obtained
    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs
    #### Check returned values
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    3
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_1_1}
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_1_2}
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_2}

Publish API same apiName and same AEF
    [Tags]    capif_api_publish_service-16  smoke

    # Set API name
    ${api_name}=  Set Variable    testing_robot_service_1

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Create Provider1 with 2 AEF roles
    ${register_user_info_provider_1}=    Provider Default Registration    total_aef_roles=2
    ${aef_id_1}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}']['aef_id']}
    ${aef_id_2}=    Set Variable    ${register_user_info_provider_1['aef_roles']['${AEF_PROVIDER_USERNAME}_1']['aef_id']}
    ${aef_ids}=    Create List    ${aef_id_1}    ${aef_id_2}

    ## Publish API service_1 with aefIds_1
    ${resp}   ${request_body}=    Publish Service Api Request   ${register_user_info_provider_1}    ${api_name}    aef_id=${aef_id_1}

    ### Validate response and values obtained
    Check Response Variable Type And Values    ${resp}    201    ServiceAPIDescription
    Dictionary Should Contain Key    ${resp.json()}    apiId
    ${service_api_description_published_1_1}=   Set Variable    ${resp.json()}

    ## Publish API service_1 with aefIds_1, error expected since same apiName and same AEF
    ${resp}   ${request_body}=    Publish Service Api Request   ${register_user_info_provider_1}    ${api_name}    aef_id=${aef_id_1}

    ### Validate error response and values obtained
    Check Response Variable Type And Values    ${resp}    403    ProblemDetails
    ...    status=403
    ...    title=Forbidden
    ...    detail=Already registered service with same api name and aef id
    ...    cause=Found service with same api name and aef id

    # Create Provider2 with 1 AEF role and publish API
    ${register_user_info_provider_2}=    Provider Default Registration    provider_username=${PROVIDER_USERNAME}_NEW
    ${aef2_id_1}=    Set Variable
    ...    ${register_user_info_provider_2['aef_roles']['${AEF_PROVIDER_USERNAME}_NEW']['aef_id']}

    ## Publish API service_1 with Provider2 aefid_1, since same apiName but different AEF, it should be published successfully
    ${service_api_description_published_2}    ${resource_url_2}    ${request_body_2}=    Publish Service Api
    ...    ${register_user_info_provider_2}
    ...    ${api_name}
    ...    aef_id=${aef2_id_1}

    # Validation of final scenario.
    ## Check if there are 2 API published with same apiName but different AEFs
    ### Discover API published by retrieving all APIs for Invoker using Invoker credentials
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&api_name=${api_name}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    ### Validate response and values obtained
    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs
    #### Check returned values
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    2
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_1_1}
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published_2}



