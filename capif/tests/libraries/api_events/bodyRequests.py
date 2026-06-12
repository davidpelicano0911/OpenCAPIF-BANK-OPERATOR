def create_events_subscription(events=["SERVICE_API_AVAILABLE", "API_INVOKER_ONBOARDED"], notification_destination="http://robot.testing", event_filters=None, event_req=None, request_test_notification=None, supported_features="0", websock_notif_config=None):
    event_subscription = {
        "events": events,
        "notificationDestination": notification_destination,
    }
    if event_filters != None:
        event_subscription['eventFilters'] = event_filters
    if event_req != None:
        event_subscription['eventReq'] = event_req
    if request_test_notification != None:
        event_subscription['requestTestNotification'] = request_test_notification
    if supported_features != None:
        event_subscription['supportedFeatures'] = supported_features
    if websock_notif_config != None:
        event_subscription['websockNotifConfig'] = websock_notif_config

    return event_subscription


def create_capif_event_filter(aefIds=None, apiIds=None, apiInvokerIds=None):
    # if aefIds == None and apiIds == None and apiInvokerIds:
    #     raise ("Error, no data present to create event filter")
    capif_event_filter = dict()
    if aefIds is not None:
        if isinstance(aefIds, list):
            capif_event_filter['aefIds'] = aefIds
        else:
            capif_event_filter['aefIds'] = [aefIds]
    if apiIds is not None:
        if isinstance(apiIds, list):
            capif_event_filter['apiIds'] = apiIds
        else:
            capif_event_filter['apiIds'] = [apiIds]
    if apiInvokerIds is not None:
        if isinstance(apiInvokerIds, list):
            capif_event_filter['apiInvokerIds'] = apiInvokerIds
        else:
            capif_event_filter['apiInvokerIds'] = [apiInvokerIds]
    return capif_event_filter


def create_event_req(imm_rep=None, notif_method=None, max_report_nbr=None, mon_dur=None, rep_period=None):
    data = dict()
    if imm_rep is not None:
        data['immRep'] = imm_rep
    if notif_method is not None:
        data['notifMethod'] = notif_method
    if max_report_nbr is not None:
        data['maxReportNbr'] = max_report_nbr
    if mon_dur is not None:
        data['monDur'] = mon_dur
    if rep_period is not None:
        data['repPeriod'] = rep_period
    return data


def create_default_event_req():
    return {
        "grpRepTime": 5,
        "immRep": True,
        "maxReportNbr": 0,
        "monDur": "2000-01-23T04:56:07+00:00",
        "partitionCriteria": ["TAC", "GEOAREA"],
        "repPeriod": 6,
        "sampRatio": 15
    }



def create_websock_notif_config_default():
    return {
        "requestWebsocketUri": True,
        "websocketUri": "websocketUri"
    }


def create_notification_event(subscriptionId, event, serviceAPIDescriptions=None, apiIds=None, apiInvokerIds=None, accCtrlPolList=None, invocationLogs=None, apiTopoHide=None):
    result = {
        "subscriptionId": subscriptionId,
        "events": event,
        "eventDetail": dict()
    }
    count = 0
    if serviceAPIDescriptions != None:
        if isinstance(serviceAPIDescriptions, list):
            result['eventDetail']['serviceAPIDescriptions'] = serviceAPIDescriptions
        else:
            result['eventDetail']['serviceAPIDescriptions'] = [
                serviceAPIDescriptions]
        count = count+1
    if apiIds != None:
        if isinstance(apiIds, list):
            result['eventDetail']['apiIds'] = apiIds
        else:
            result['eventDetail']['apiIds'] = [apiIds]
        count = count+1
    if apiInvokerIds != None:
        if isinstance(apiInvokerIds, list):
            result['eventDetail']['apiInvokerIds'] = apiInvokerIds
        else:
            result['eventDetail']['apiInvokerIds'] = [apiInvokerIds]
        count = count+1
    if accCtrlPolList != None:
        result['eventDetail']['accCtrlPolList'] = accCtrlPolList
        count = count+1
    if invocationLogs != None:
        if isinstance(invocationLogs, list):
            result['eventDetail']['invocationLogs'] = invocationLogs
        else:
            result['eventDetail']['invocationLogs'] = [invocationLogs]
        count = count+1
    if apiTopoHide != None:
        if isinstance(apiTopoHide, list):
            result['eventDetail']['apiTopoHide'] = apiTopoHide
        else:
            result['eventDetail']['apiTopoHide'] = [apiTopoHide]
        count = count+1

    if count == 0:
        del result['eventDetail']

    return result
