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
Library             String



*** Variables ***
${TOTAL_USERS}                      5

${BACKUP_DIRECTORY}                 backup
${RESULT_FOLDER}                    /opt/robot-tests/results
${OUTPUT_ZIP_FILE}                  users_loaded.zip

${USER_PASSWORD}                    password
${USERNAME_PREFIX}                  user
${DESCRIPTION}                      Testing purpouse


*** Test Cases ***
Create Client Users
    [Tags]    create-users
    ${entities_dictionary}=    Create Dictionary
    Create Directory    ${BACKUP_DIRECTORY}

    FOR    ${counter}    IN RANGE    ${TOTAL_USERS}
        ${USERNAME}=    Set Variable    ${USERNAME_PREFIX}_${counter}
        IF  ${TOTAL_USERS} == 1
            ${USERNAME}=    Set Variable    ${USERNAME_PREFIX}
        END

        ${resp}=    Run Keyword And Continue On Failure    Create User At Register
        ...    ${USERNAME}
        ...    ${USER_PASSWORD}
        ...    ${DESCRIPTION}
        ...    email="${USERNAME}@nobody.com"

        ${register_user_info}=    Create Dictionary

        IF    ${resp.status_code} == 201
            ${register_user_info}=    Create Dictionary
            ...    user_uuid=${resp.json()['uuid']}
            ...    &{resp.json()}
        ELSE
            ${register_user_info}=    Create Dictionary
            ...    ${resp.json()}
        END

        Set To Dictionary    ${entities_dictionary}    ${USERNAME}=${register_user_info}
        Copy Files    *${USERNAME}*    ${BACKUP_DIRECTORY}/
    END

    Write Dictionary    ${BACKUP_DIRECTORY}/registers.json    ${entities_dictionary}
    ${date}=    Get Current Date    result_format=%Y_%m_%d_%H_%M_%S
    Create Zip From Files In Directory    ${BACKUP_DIRECTORY}    ${RESULT_FOLDER}/${date}_${OUTPUT_ZIP_FILE}

    ${result}=    Run Process    ls    -l

    Log Many    ${result.stdout}

Remove Client Users
    [Tags]    remove-users
    ${files}=    List Files In Directory    ${RESULT_FOLDER}    *${OUTPUT_ZIP_FILE}
    ${sorted_list}=    Copy List    ${files}

    Sort List    ${sorted_list}
    Log To Console    message
    ${last_backup}=    Get From List    ${sorted_list}    -1

    Copy File    ${RESULT_FOLDER}/${last_backup}    ./
    Extract Zip File    ${last_backup}

    ${entities_dictionary}=    Read Dictionary    registers.json

    Log Dictionary    ${entities_dictionary}

    FOR    ${username}    IN    @{entities_dictionary}
        Log    ${username}=${entities_dictionary}[${username}]
        Run Keyword And Continue On Failure   Delete User At Register  username=${username}
    END

    ${result}=    Run Process    ls    -l

    Log Many    ${result.stdout}


Remove Client Users By Prefix
    [Tags]    remove-users-by-prefix

    ${users}=   Get List of Users At Register

    ${users_to_remove}=   Filter Users By Prefix Username   users=${users}    prefix=${USERNAME_PREFIX}

    Log List    ${users_to_remove}

    FOR    ${username}    IN    @{users_to_remove}
        Log    Removing ${username}
        Run Keyword And Continue On Failure   Delete User At Register  username=${username}
    END

    ${result}=    Run Process    ls    -l

    Log Many    ${result.stdout}

