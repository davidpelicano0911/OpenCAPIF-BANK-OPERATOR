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
Obtain ccfId
    [Tags]    api_1  smoke

    ${ccfId}=    Get Capif Ccf Id

    Log    CCF ID obtained: ${ccfId}
    Should Match Regexp    ${ccfId}    ^CCF[a-zA-Z0-9]+
    