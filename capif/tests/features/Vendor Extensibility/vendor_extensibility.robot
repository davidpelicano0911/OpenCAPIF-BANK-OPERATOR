*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Resource            /opt/robot-tests/tests/resources/api_invoker_management_requests/apiInvokerManagementRequests.robot
Resource            ../../resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${API_INVOKER_NOT_REGISTERED}       not-valid


*** Test Cases ***
Published API with vendor extensibility
    [Tags]    vendor_extensibility-1    smoke
    ${vendor_specific_service_api_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:service-info
    ${vendor_specific_aef_profile_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:transport-info
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Create Vendor Specific information
    ${vendor_specific_service_api_description}=    Create Vendor Specific Service Api Description
    ...    ${vendor_specific_service_api_key}
    ${vendor_specific_aef_profile}=    Create Vendor Specific Aef Profile
    ...    ${vendor_specific_aef_profile_key}

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=100
    ...    vendor_specific_service_api_description=${vendor_specific_service_api_description}
    ...    vendor_specific_aef_profile=${vendor_specific_aef_profile}

    Dictionary Should Contain Key    ${service_api_description_published}    ${vendor_specific_service_api_key}
    Dictionary Should Contain Key
    ...    ${service_api_description_published['aefProfiles'][0]}
    ...    ${vendor_specific_aef_profile_key}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}&supported-features=2
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

Published API with vendor extensibility and discover with VendSpecQueryParams disabled
    [Tags]    vendor_extensibility-2
    ${vendor_specific_service_api_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:service-info
    ${vendor_specific_aef_profile_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:transport-info
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Create Vendor Specific information
    ${vendor_specific_service_api_description}=    Create Vendor Specific Service Api Description
    ...    ${vendor_specific_service_api_key}
    ${vendor_specific_aef_profile}=    Create Vendor Specific Aef Profile
    ...    ${vendor_specific_aef_profile_key}

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=100
    ...    vendor_specific_service_api_description=${vendor_specific_service_api_description}
    ...    vendor_specific_aef_profile=${vendor_specific_aef_profile}

    Dictionary Should Contain Key    ${service_api_description_published}    ${vendor_specific_service_api_key}
    Dictionary Should Contain Key
    ...    ${service_api_description_published['aefProfiles'][0]}
    ...    ${vendor_specific_aef_profile_key}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}&supported-features=0
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

Publish API with vendorExt active and discover without supported features filter
    [Tags]    vendor_extensibility-3
    ${vendor_specific_service_api_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:service-info
    ${vendor_specific_aef_profile_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:transport-info
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Create Vendor Specific information
    ${vendor_specific_service_api_description}=    Create Vendor Specific Service Api Description
    ...    ${vendor_specific_service_api_key}
    ${vendor_specific_aef_profile}=    Create Vendor Specific Aef Profile
    ...    ${vendor_specific_aef_profile_key}

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=100
    ...    vendor_specific_service_api_description=${vendor_specific_service_api_description}
    ...    vendor_specific_aef_profile=${vendor_specific_aef_profile}

    Dictionary Should Contain Key    ${service_api_description_published}    ${vendor_specific_service_api_key}
    Dictionary Should Contain Key
    ...    ${service_api_description_published['aefProfiles'][0]}
    ...    ${vendor_specific_aef_profile_key}

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    Dictionary Should Not Contain Key
    ...    ${resp.json()['serviceAPIDescriptions'][0]}
    ...    ${vendor_specific_service_api_key}
    Dictionary Should Not Contain Key
    ...    ${resp.json()['serviceAPIDescriptions'][0]['aefProfiles'][0]}
    ...    ${vendor_specific_aef_profile_key}

    ${service_api_description_published_to_check}=    Copy Dictionary
    ...    ${service_api_description_published}
    ...    deepcopy=True
    Remove From Dictionary    ${service_api_description_published_to_check}    ${vendor_specific_service_api_key}
    Remove From Dictionary
    ...    ${service_api_description_published_to_check['aefProfiles'][0]}
    ...    ${vendor_specific_aef_profile_key}

    List Should Contain Value
    ...    ${resp.json()['serviceAPIDescriptions']}
    ...    ${service_api_description_published_to_check}

Publish API with vendorExt active but without vendorSpecifics
    [Tags]    vendor_extensibility-4  smoke
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish API with supported features
    ${request_body}=    Create Service Api Description
    ...    api_name=service_1
    ...    aef_id=${register_user_info['aef_id']}
    ...    supported_features=100
    ${resp}=    Post Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${register_user_info['apf_username']}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=If and only if VendorExt feature is enabled, then vendor-specific fields should be defined
    ...    cause=Vendor extensibility misconfiguration

Publish API with vendorExt inactive but with vendorSpecifics
    [Tags]    vendor_extensibility-5
    ${vendor_specific_service_api_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:service-info
    ${vendor_specific_aef_profile_key}=    Set Variable    vendorSpecific-urn:etsi:mec:capifext:transport-info
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Create Vendor Specific information
    ${vendor_specific_service_api_description}=    Create Vendor Specific Service Api Description
    ...    ${vendor_specific_service_api_key}
    ${vendor_specific_aef_profile}=    Create Vendor Specific Aef Profile
    ...    ${vendor_specific_aef_profile_key}

    # Publish API with supported features
    ${request_body}=    Create Service Api Description
    ...    api_name=service_1
    ...    aef_id=${register_user_info['aef_id']}
    ...    supported_features=000
    ...    vendor_specific_service_api_description=${vendor_specific_service_api_description}
    ...    vendor_specific_aef_profile=${vendor_specific_aef_profile}
    ${resp}=    Post Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${register_user_info['apf_username']}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=If and only if VendorExt feature is enabled, then vendor-specific fields should be defined
    ...    cause=Vendor extensibility misconfiguration

Published API without vendor extensibility discover with VendSpecQueryParams enabled
    [Tags]    vendor_extensibility-6
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=00

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}&supported-features=2
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

Published API without vendor extensibility and discover with vendSpecQueryParams disabled
    [Tags]    vendor_extensibility-7
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=0

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}&supported-features=0
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

Published API without vendor extensibility and discover without supported-features query parameter
    [Tags]    vendor_extensibility-8
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish one api
    ${service_api_description_published}    ${resource_url}    ${request_body}=    Publish Service Api
    ...    ${register_user_info}
    ...    supported_features=000

    # Default Invoker Registration and Onboarding
    ${register_user_info_invoker}    ${url}    ${request_body}=    Invoker Default Onboarding

    # Test
    ${resp}=    Get Request Capif
    ...    ${DISCOVER_URL}${register_user_info_invoker['api_invoker_id']}&aef-id=${register_user_info['aef_id']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${INVOKER_USERNAME}

    Check Response Variable Type And Values    ${resp}    200    DiscoveredAPIs

    # Check Results
    Dictionary Should Contain Key    ${resp.json()}    serviceAPIDescriptions
    Should Not Be Empty    ${resp.json()['serviceAPIDescriptions']}
    Length Should Be    ${resp.json()['serviceAPIDescriptions']}    1
    List Should Contain Value    ${resp.json()['serviceAPIDescriptions']}    ${service_api_description_published}

Publish API without supportedFeatures
    [Tags]    vendor_extensibility-9
    # Register APF
    ${register_user_info}=    Provider Default Registration

    # Publish API without supported features
    ${request_body}=    Create Service Api Description
    ...    api_name=service_1
    ...    aef_id=${register_user_info['aef_id']}
    ...    supported_features=${NONE}
    ${resp}=    Post Request Capif
    ...    /published-apis/v1/${register_user_info['apf_id']}/service-apis
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${register_user_info['apf_username']}

    Check Response Variable Type And Values
    ...    ${resp}
    ...    400
    ...    ProblemDetails
    ...    title=Bad Request
    ...    status=400
    ...    detail=supportedFeatures not present in request
    ...    cause=supportedFeatures not present
