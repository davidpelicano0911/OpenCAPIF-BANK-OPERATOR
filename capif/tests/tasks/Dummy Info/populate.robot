*** Settings ***
Resource            /opt/robot-tests/tests/resources/common.resource
Resource            /opt/robot-tests/tests/resources/api_invoker_management_requests/apiInvokerManagementRequests.robot
Resource            ../../resources/common.resource
Resource            ../../resources/common/basicRequests.robot
Library             /opt/robot-tests/tests/libraries/bodyRequests.py
Library             Process
Library             Collections
Library             ArchiveLibrary
Library             OperatingSystem
Library             DateTime

Test Setup          Reset Testing Environment


*** Variables ***
${API_INVOKER_NOT_REGISTERED}       not-valid
${TOTAL_INVOKERS}                   10
${TOTAL_PROVIDERS}                  10

${BACKUP_DIRECTORY}                 backup
${RESULT_FOLDER}                    /opt/robot-tests/results
${OUTPUT_ZIP_FILE}                  entities_loaded.zip

${INVOKER_USERNAME_POPULATE}        ${INVOKER_USERNAME}_POPULATE
${PROVIDER_USERNAME_POPULATE}       ${PROVIDER_USERNAME}_POPULATE


*** Test Cases ***
Create Dummy Invokers and Providers
    [Tags]    populate-create
    ${entities_dictionary}=    Create Dictionary
    Create Directory    ${BACKUP_DIRECTORY}

    FOR    ${counter}    IN RANGE    ${TOTAL_PROVIDERS}
        ${USERNAME}=    Set Variable    ${PROVIDER_USERNAME_POPULATE}_${counter}
        ${register_user_info}=    Run Keyword And Continue On Failure    Provider Default Registration    ${USERNAME}

        Set To Dictionary    ${entities_dictionary}    ${USERNAME}=${register_user_info}
        Copy Files    *${USERNAME}*    ${BACKUP_DIRECTORY}/

        ${service_api_description_published}
        ...    ${resource_url}
        ...    ${request_body}=
        ...    Run Keyword And Continue On Failure
        ...    Publish Service Api
        ...    ${register_user_info}
        ...    ROBOT_SERVICE_${counter}
    END

    ${last_provider_used}=    Evaluate    -1
    FOR    ${counter}    IN RANGE    ${TOTAL_INVOKERS}
        ${USERNAME}=    Set Variable    ${INVOKER_USERNAME_POPULATE}_${counter}
        ${register_user_info}    ${url}    ${request_body}=    Run Keyword And Continue On Failure
        ...    Invoker Default Onboarding
        ...    ${USERNAME}

        IF    ${TOTAL_PROVIDERS} > 0
            ${last_provider_used}    ${register_user_info_provider}=    Get Provider
            ...    ${last_provider_used}
            ...    ${entities_dictionary}
            Log Dictionary    ${register_user_info_provider}

            Run Keyword And Continue On Failure
            ...    Create Security Context Between invoker and provider
            ...    ${register_user_info}
            ...    ${register_user_info_provider}
        END

        Set To Dictionary    ${entities_dictionary}    ${USERNAME}=${register_user_info}
        Copy Files    ${USERNAME}*    ${BACKUP_DIRECTORY}/
    END

    Write Dictionary    ${BACKUP_DIRECTORY}/registers.json    ${entities_dictionary}
    ${date}=    Get Current Date    result_format=%Y_%m_%d_%H_%M_%S
    Create Zip From Files In Directory    ${BACKUP_DIRECTORY}    ${RESULT_FOLDER}/${date}_${OUTPUT_ZIP_FILE}

    ${result}=    Run Process    ls    -l

    Log Many    ${result.stdout}

Remove Dummy Invokers and Providers
    [Tags]    populate-remove
    ${files}=    List Files In Directory    ${RESULT_FOLDER}    *${OUTPUT_ZIP_FILE}
    ${sorted_list}=    Copy List    ${files}

    Sort List    ${sorted_list}
    ${last_backup}=    Get From List    ${sorted_list}    -1

    Copy File    ${RESULT_FOLDER}/${last_backup}    ./
    Extract Zip File    ${last_backup}

    ${entities_dictionary}=    Read Dictionary    registers.json

    Log Dictionary    ${entities_dictionary}

    FOR    ${username}    IN    @{entities_dictionary}
        Log    ${username}=${entities_dictionary}[${username}]
        ${resource_url}=    Set Variable    ${entities_dictionary}[${username}][resource_url]
        ${management_cert}=    Set Variable    ${entities_dictionary}[${username}][management_cert]
        Run Keyword And Continue On Failure    Remove Resource    ${resource_url.path}    ${management_cert}    ${username}
    END

    ${result}=    Run Process    ls    -l

    Log Many    ${result.stdout}

*** Keywords ***
Get Provider
    [Arguments]    ${index}    ${entities_dictionary}
    ${index}=    Evaluate    ${index} + 1
    IF    ${index} == ${TOTAL_PROVIDERS}
        ${index}=    Evaluate    0
    END

    ${username}=    Set Variable    ${PROVIDER_USERNAME_POPULATE}_${index}
    ${usernames}=    Get Dictionary Keys    ${entities_dictionary}
    IF    '${username}' in ${usernames}
        log    ${username} is in the list
    ELSE
        Log    Dictionary not contain ${username}, no provider returned
    END

    RETURN    ${index}    ${entities_dictionary}[${username}]
