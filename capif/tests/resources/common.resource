*** Settings ***
Library         /opt/robot-tests/tests/libraries/helpers.py
Library         /opt/robot-tests/tests/libraries/interrupt_listener.py
Library    Process
Library    Collections
Variables       /opt/robot-tests/tests/libraries/environment.py
Resource        /opt/robot-tests/tests/resources/common/basicRequests.robot
Resource        /opt/robot-tests/tests/resources/common/expectedMessages.robot


*** Variables ***
${SUPERADMIN_USERNAME}          ROBOT_TESTING_SUPERADMIN
${INVOKER_USERNAME}             ROBOT_TESTING_INVOKER
${PROVIDER_USERNAME}            ROBOT_TESTING_PROVIDER
${APF_PROVIDER_USERNAME}        APF_${PROVIDER_USERNAME}
${AEF_PROVIDER_USERNAME}        AEF_${PROVIDER_USERNAME}
${AMF_PROVIDER_USERNAME}        AMF_${PROVIDER_USERNAME}

${INVOKER_NOT_REGISTERED}       not-valid
${INVOKER_ROLE}                 invoker
${PROVIDER_ROLE}                provider

${CAPIF_HOSTNAME}               capifcore
${CAPIF_VAULT}                  vault
${CAPIF_VAULT_PORT}             8200
${CAPIF_VAULT_TOKEN}            read-ca-token
${CAPIF_REGISTER}               register
${CAPIF_REGISTER_PORT}          8084
${CAPIF_HTTP_PORT}              ${EMPTY}
${CAPIF_HTTPS_PORT}             ${EMPTY}
${CAPIF_IP}                     127.0.0.1
${CAPIF_CALLBACK_IP}            host.docker.internal
${CAPIF_CALLBACK_PORT}          8086

${REGISTER_ADMIN_USER}          admin
${REGISTER_ADMIN_PASSWORD}      password123

${REQUESTS_TIMEOUT}             120s

${MOCK_SERVER_URL}
${NOTIFICATION_DESTINATION_URL}     ${MOCK_SERVER_URL}


${DISCOVER_URL}                 /service-apis/v1/allServiceAPIs?api-invoker-id=


*** Keywords ***
Reset Testing Environment
    Log    Db capif.invokerdetails collection will be removed in order to isolate each test.

    # Clean Test Information By HTTP Requests
    Clean Test Information

Check Location Header
    [Documentation]    This keyword will check location header at response according to regular expression provided as argument
    [Arguments]    ${resp}    ${regular_expression}

    ${event_url}=    Parse Url    ${resp.headers['Location']}

    Should Match Regexp    ${event_url.path}    ${regular_expression}
    Should Match Regexp    ${event_url.netloc}   ^${CAPIF_HOSTNAME}(:[0-9]+)?$
    RETURN    ${event_url}

Check Event Location Header
    [Arguments]    ${resp}

    ${event_url}=    Check Location Header    ${resp}    ${LOCATION_EVENT_RESOURCE_REGEX}

    ${subscriber_id}    ${subscription_id}=    Get Subscriber And Subscription From Location    ${event_url.path}

    RETURN    ${subscriber_id}    ${subscription_id}

Check Problem Details
    [Arguments]    ${resp}    &{input_parameters}
    Check Variable    ${resp.json()}    ProblemDetails
    FOR    ${input}    IN    @{input_parameters}
        Log    ${input}=${input_parameters['${input}']}
        Should Match    "${resp.json()['${input}']}"    "${input_parameters['${input}']}"
    END

Check Response Variable Type And Values
    [Arguments]    ${resp}    ${status_code}    ${variable_type}    &{input_parameters}
    Status Should Be    ${status_code}    ${resp}
    Check Variable    ${resp.json()}    ${variable_type}
    FOR    ${input}    IN    @{input_parameters}
        Log    ${input}=${input_parameters['${input}']}
        IF     "${input}"=="invalidParams"
            Should Be Equal    ${resp.json()['${input}']}    ${input_parameters['${input}']}
        ELSE
            Should Match Regexp    "${resp.json()['${input}']}"    "${input_parameters['${input}']}"
        END
    END

Remove Keys From Object
    [Arguments]    ${input}    @{keys_to_remove}

    ${filtered_input}=    Remove Keys From Object Helper    ${input}    ${keys_to_remove}

    RETURN    ${filtered_input}

Test ${TEST NAME} Currently Not Supported
    Log    Test "${TEST NAME}" Currently not supported    WARN
    Skip    Test "${TEST NAME}" Currently not supported

Init Mock Server
    Check Mock Server
    Clean Mock Server

Check Mock Server
    Log  Checking mock Server for Robot Framework.

    IF    "${MOCK_SERVER_URL}" == ""
        Fail   Mock Server Url is not setup on Tests execution, check MOCK_SERVER_URL variable   mockserver-not-ready
    END

    Create Session    mockserver    ${MOCK_SERVER_URL}

    ${endpoint}=    Set Variable  /requests_list

    ${resp}=    GET On Session
    ...    mockserver
    ...    ${endpoint}
    ...    expected_status=any
    ...    verify=False

    Status Should Be    200    ${resp}   Mock Server response is not 200 OK at ${MOCK_SERVER_URL}, check server status.

Clean Mock Server
    Log  Checking mock Server for Robot Framework.

    Create Session    mockserver    ${MOCK_SERVER_URL}

    ${endpoint}=    Set Variable  /requests_list

    ${resp}=    DELETE On Session
    ...    mockserver
    ...    ${endpoint}
    ...    expected_status=any
    ...    verify=False

    Status Should Be    200    ${resp}


Get Mock Server Messages
    Log  Checking mock Server for Robot Framework.

    Create Session    mockserver    ${MOCK_SERVER_URL}

    ${endpoint}=    Set Variable  /requests_list

    ${resp}=    GET On Session
    ...    mockserver
    ...    ${endpoint}
    ...    expected_status=any
    ...    verify=False

    Status Should Be    200    ${resp}
    Log List    ${resp.json()}
    RETURN   ${resp}

Check Mock Server Notification Events
    [Arguments]    ${events_expected}

    Check Variable    ${events_expected}    EventNotification
    # Check results
    ${events_expected_length}=   Get Length    ${events_expected}

    Sleep    3s
    # Get from Mock server the EventNotification Messages sent to callback setup on event subscription.
    ${resp}=    Get Mock Server Messages
    ${notification_events_on_mock_server}=    Set Variable    ${resp.json()}
    Check Variable    ${notification_events_on_mock_server}    EventNotification

    Length Should Be    ${notification_events_on_mock_server}   ${events_expected_length}
    FOR    ${event_expected}    IN    @{events_expected}
        Log    ${event_expected}
        List Should Contain Value    ${notification_events_on_mock_server}    ${event_expected}
    END

    RETURN  ${notification_events_on_mock_server}