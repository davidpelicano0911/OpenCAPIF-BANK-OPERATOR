*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             XML
Library             String
Resource            /opt/robot-tests/tests/resources/common/basicRequests.robot
Resource            /opt/robot-tests/tests/resources/common.resource
Resource            /opt/robot-tests/tests/resources/common/basicRequests.robot

Suite Teardown      Reset Testing Environment
Test Setup          Reset Testing Environment
Test Teardown       Reset Testing Environment


*** Variables ***
${API_INVOKER_NOT_REGISTERED}       not-valid
${SUBSCRIBER_ID_NOT_VALID}          not-valid
${SUBSCRIPTION_ID_NOT_VALID}        not-valid


*** Test Cases ***
Get Visibility Control Rules as Superadmin
    [Tags]    visibility_control-1

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    
    Length Should Be    ${resp.json()['rules']}    0

Create Visibility Control Rule Invalid Dates as Superadmin
    [Tags]    visibility_control-2

    ${body}=   Create Visibility Control Rule Body Invalid Dates
    
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    ...    json=${body}

    Status Should Be    400    ${resp}
    
Create Visibility Control Rule
    [Tags]    visibility_control-3
    ${body}=   Create Visibility Control Rule Body
    
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    ...    json=${body}

    ${rule_id}=    Set Variable    ${resp.json()['ruleId']}

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    Length Should Be    ${resp.json()['rules']}    1
    
    ${resp}=    Delete Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    
    Length Should Be    ${resp.json()['rules']}    0


Get Visibility Control Rule by AMF Provider
    [Tags]    visibility_control-4

    ${register_user_info}=    Provider Default Registration
    
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Status Should Be    200    ${resp}

Create Visibility Control Rule by AMF Provider and DELETE by useradmin
    [Tags]    visibility_control-5

    ${register_user_info}=    Provider Default Registration

    ${body}=   Create Visibility Control Rule Body
    
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}
    ...    json=${body}

    Status Should Be    201    ${resp}

    ${rule_id}=    Set Variable    ${resp.json()['ruleId']}

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    Length Should Be    ${resp.json()['rules']}    1

    ${resp}=    Delete Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    Status Should Be    204    ${resp}

    # Check empty list
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    Length Should Be    ${resp.json()['rules']}    0

Create and Delete Visibility Control Rule by AMF Provider
    [Tags]    visibility_control-6

    ${register_user_info}=    Provider Default Registration

    ${body}=   Create Visibility Control Rule Body
    
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}
    ...    json=${body}

    Status Should Be    201    ${resp}

    ${rule_id}=    Set Variable    ${resp.json()['ruleId']}

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Length Should Be    ${resp.json()['rules']}    1

    ${resp}=    Delete Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check empty list
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Length Should Be    ${resp.json()['rules']}    0

Create Update and Delete Visibility Control Rule by AMF Provider
    [Tags]    visibility_control-7

    ${register_user_info}=    Provider Default Registration

    ${body}=   Create Visibility Control Rule Body
    
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}
    ...    json=${body}

    Status Should Be    201    ${resp}

    ${rule_id}=    Set Variable    ${resp.json()['ruleId']}

    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Length Should Be    ${resp.json()['rules']}    1

    ${body}=   Create Visibility Control Rule body 2

     ${resp}=    Patch Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}
    ...    json=${body}

    Status Should Be    200    ${resp}

    ${resp}=    Delete Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Status Should Be    204    ${resp}

    # Check empty list
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${AMF_PROVIDER_USERNAME}

    Length Should Be    ${resp.json()['rules']}    0

Create and Get Specific Visibility Control Rule
    [Tags]    visibility_control-8
    
    # 1. Prepare the request body
    ${body}=    Create Visibility Control Rule Body
    
    # 2. Create a new rule using superadmin
    ${resp}=    Post Request Capif
    ...    /helper/visibility-control/rules
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    ...    json=${body}

    # Verify creation was successful (201 Created)
    Status Should Be    201    ${resp}
    ${rule_id}=    Set Variable    ${resp.json()['ruleId']}

    # 3. Get the specific rule by its ID
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    # Validation: Specific GET returns the rule object directly.
    # We verify the status is 200 OK and the ruleId matches.
    Status Should Be    200    ${resp}
    Should Be Equal As Strings    ${resp.json()['ruleId']}    ${rule_id}
    
    # 4. Delete the specific rule
    ${resp}=    Delete Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}

    # Verify deletion was successful (204 No Content)
    Status Should Be    204    ${resp}

    # 5. Verify the rule no longer exists
    ${resp}=    Get Request Capif
    ...    /helper/visibility-control/rules/${rule_id}
    ...    server=${CAPIF_HTTPS_URL}
    ...    verify=ca.crt
    ...    username=${SUPERADMIN_USERNAME}
    
    # After deletion, the server must return 404 Not Found.
    # This is the correct way to confirm the resource is gone.
    Status Should Be    404    ${resp}
