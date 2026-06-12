*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Resource            ../../resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             Process
Library             Collections

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${API_PROVIDER_NOT_REGISTERED}      notValid


*** Test Cases ***
Register Api Provider
    [Tags]    capif_api_provider_management-1
    # Register Provider User An create Certificates for each function
    ${register_user_info}=    Register User At Jwt Auth Provider
    ...    username=${PROVIDER_USERNAME}

    # Create provider Registration Body
    ${apf_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['apf_username']}
    ...    ${register_user_info['apf_csr_request']}
    ...    APF
    ${aef_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['aef_username']}
    ...    ${register_user_info['aef_csr_request']}
    ...    AEF
    ${amf_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['amf_username']}
    ...    ${register_user_info['amf_csr_request']}
    ...    AMF
    ${api_prov_funcs}=    Create List    ${apf_func_details}    ${aef_func_details}    ${amf_func_details}

    ${request_body}=    Create Api Provider Enrolment Details Body
    ...    ${register_user_info['access_token']}
    ...    ${api_prov_funcs}

    # Register Provider
    ${resp}=    Post Request Capif
    ...    /api-provider-management/v1/registrations
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    access_token=${register_user_info['access_token']}

    # Check Results
    Check Response Variable Type And Values    ${resp}    201    APIProviderEnrolmentDetails

    ${url}=    Parse Url    ${resp.headers['Location']}
    Call Method    ${CAPIF_USERS}    update_capif_users_dicts    ${url.path}    ${register_user_info['amf_username']}

    ${resource_url}=    Check Location Header    ${resp}    ${LOCATION_PROVIDER_RESOURCE_REGEX}

    FOR    ${prov}    IN    @{resp.json()['apiProvFuncs']}
        Log Dictionary    ${prov}
        Store In File    ${prov['apiProvFuncInfo']}.crt    ${prov['regInfo']['apiProvCert']}
    END

Register Api Provider Already registered
    [Tags]    capif_api_provider_management-2
    ${register_user_info}=    Provider Default Registration

    ${resp}=    Post Request Capif
    ...    /api-provider-management/v1/registrations
    ...    json=${register_user_info['provider_enrollment_details']}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    access_token=${register_user_info['access_token']}

    # Check Results
    Check Response Variable Type And Values    ${resp}    403    ProblemDetails
    ...    status=403
    ...    title=Forbidden
    ...    detail=Provider already registered
    ...    cause=Identical provider reg sec

Update Registered Api Provider
    [Tags]    capif_api_provider_management-3   smoke
    ${register_user_info}=    Provider Default Registration

    ${request_body}=    Set Variable    ${register_user_info['provider_enrollment_details']}

    Set To Dictionary    ${request_body}    apiProvDomInfo=ROBOT_TESTING_MOD

    ${resp}=    Put Request Capif
    ...    ${register_user_info['resource_url'].path}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    FOR    ${prov}    IN    @{resp.json()['apiProvFuncs']}
        Log Dictionary    ${prov}
        Store In File    ${prov['apiProvFuncInfo']}.crt    ${prov['regInfo']['apiProvCert']}
        IF    "${prov['apiProvFuncRole']}" == "APF"
            Set To Dictionary    ${register_user_info}    apf_id=${prov['apiProvFuncId']}
        ELSE IF    "${prov['apiProvFuncRole']}" == "AEF"
            Set To Dictionary    ${register_user_info}    aef_id=${prov['apiProvFuncId']}
        ELSE IF    "${prov['apiProvFuncRole']}" == "AMF"
            Set To Dictionary    ${register_user_info}    amf_id=${prov['apiProvFuncId']}
        ELSE
            Fail    "${prov['apiProvFuncRole']} is not valid role"
        END
    END

    # Check Results
    Check Response Variable Type And Values    ${resp}    200    APIProviderEnrolmentDetails
    ...    apiProvDomInfo=ROBOT_TESTING_MOD

Update Not Registered Api Provider
    [Tags]    capif_api_provider_management-4
    ${register_user_info}=    Provider Default Registration

    ${request_body}=    Set Variable    ${register_user_info['provider_enrollment_details']}

    ${resp}=    Put Request Capif
    ...    /api-provider-management/v1/registrations/${API_PROVIDER_NOT_REGISTERED}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=Please provide an existing API Provider ID
    ...    cause=API Provider ID does not exist

# Partially Update Registered Api Provider
#    [Tags]    capif_api_provider_management-5
#    ${register_user_info}=    Provider Default Registration

#    ${request_body}=    Create Api Provider Enrolment Details Patch Body    ROBOT_TESTING_MOD

#    ${resp}=    Patch Request Capif
#    ...    ${register_user_info['resource_url'].path}
#    ...    json=${request_body}
#    ...    server=${CAPIF_HTTPS_URL}
#    ...    verify=ca.crt
#    ...    username=${AMF_PROVIDER_USERNAME}

#    Call Method    ${CAPIF_USERS}    update_capif_users_dicts    ${register_user_info['resource_url'].path}    ${register_user_info['amf_username']}


#    # Check Results
#    Check Response Variable Type And Values    ${resp}    200    APIProviderEnrolmentDetails
#    ...    apiProvDomInfo=ROBOT_TESTING_MOD

Partially Update Not Registered Api Provider
    [Tags]    capif_api_provider_management-6  smoke
    ${register_user_info}=    Provider Default Registration

    ${request_body}=    Create Api Provider Enrolment Details Patch Body

    ${resp}=    Patch Request Capif
    ...    /api-provider-management/v1/registrations/${API_PROVIDER_NOT_REGISTERED}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=Please provide an existing API Provider ID
    ...    cause=API Provider ID does not exist

Delete Registered Api Provider
    [Tags]    capif_api_provider_management-7
    ${register_user_info}=    Provider Default Registration

    ${resp}=    Delete Request Capif
    ...    ${register_user_info['resource_url'].path}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Call Method    ${CAPIF_USERS}    remove_capif_users_entry    ${register_user_info['resource_url'].path}

    # Check Results
    Status Should Be    204    ${resp}

Delete Not Registered Api Provider
    [Tags]    capif_api_provider_management-8
    ${register_user_info}=    Provider Default Registration

    ${resp}=    Delete Request Capif
    ...    /api-provider-management/v1/registrations/${API_PROVIDER_NOT_REGISTERED}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    404    ProblemDetails
    ...    status=404
    ...    title=Not Found
    ...    detail=Please provide an existing API Provider ID
    ...    cause=API Provider ID does not exist

Onboard provider without supported_features
    [Tags]    capif_api_provider_management-9
    # Default Provider Registration and Onboarding
    ${register_user_info}=    Register User At Jwt Auth Provider
    ...    username=${PROVIDER_USERNAME}

    # Create provider Registration Body
    ${apf_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['apf_username']}
    ...    ${register_user_info['apf_csr_request']}
    ...    APF
    ${aef_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['aef_username']}
    ...    ${register_user_info['aef_csr_request']}
    ...    AEF
    ${amf_func_details}=    Create Api Provider Function Details
    ...    ${register_user_info['amf_username']}
    ...    ${register_user_info['amf_csr_request']}
    ...    AMF
    ${api_prov_funcs}=    Create List    ${apf_func_details}    ${aef_func_details}    ${amf_func_details}

    ${request_body}=    Create Api Provider Enrolment Details Body
    ...    ${register_user_info['access_token']}
    ...    ${api_prov_funcs}
    ...    suppFeat=${None}

    # Register Provider
    ${resp}=    Post Request Capif
    ...    /api-provider-management/v1/registrations
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    access_token=${register_user_info['access_token']}

    # Check Results
    Check Response Variable Type And Values    ${resp}    400    ProblemDetails
    ...    status=400
    ...    title=Bad Request
    ...    detail=suppFeat not present in request
    ...    cause=suppFeat not present

Update Registered Api Provider Without SuppFeat field
    [Tags]    capif_api_provider_management-10
    ${register_user_info}=    Provider Default Registration

    ${request_body}=    Set Variable    ${register_user_info['provider_enrollment_details']}

    Set To Dictionary    ${request_body}    apiProvDomInfo=ROBOT_TESTING_MOD

    Remove From Dictionary
    ...    ${request_body}
    ...    suppFeat

    ${resp}=    Put Request Capif
    ...    ${register_user_info['resource_url'].path}
    ...    json=${request_body}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    # Check Results
    Check Response Variable Type And Values    ${resp}    400    ProblemDetails
    ...    status=400
    ...    title=Bad Request
    ...    detail=suppFeat not present in request
    ...    cause=suppFeat not present
