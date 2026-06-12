#import concurrent
import asyncio
import json
import os
from datetime import datetime, timedelta, timezone

import aiohttp
import requests
from encoder import CustomJSONEncoder
from flask import current_app
from models.event_notification import EventNotification
from util import serialize_clean_camel_case

from .internal_event_ops import InternalEventOperations

TOTAL_FEATURES = 4
SUPPORTED_FEATURES_HEX = "c"

def return_negotiated_supp_feat_dict(supp_feat):

    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "NotificationTestEvent": True if final_supp_feat[0] == "1" else False,
        "NotificationWebsocket": True if final_supp_feat[1] == "1" else False,
        "EnhancedEventReport": True if final_supp_feat[2] == "1" else False,
        "ApiStatusMonitoring": True if final_supp_feat[3] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }

class Notifications():

    def __init__(self):
        self.events_ops = InternalEventOperations()

    def send_notifications(self, redis_event):
        try:
            event = redis_event.get('event', None)
            if event is None:
                raise("Event value is not present on received event from REDIS")
            

            current_app.logger.debug("Received event " + event + ", sending notifications")
            subscriptions = self.events_ops.get_event_subscriptions(event)
            current_app.logger.debug(subscriptions)

            for sub in subscriptions:
                url = sub["notification_destination"]
                current_app.logger.debug(url)
                data = EventNotification(sub["subscription_id"], events=event)
                event_detail_redis=redis_event.get('event_detail', None)
                if event_detail_redis is not None:
                    if return_negotiated_supp_feat_dict(sub["supported_features"])["EnhancedEventReport"]:
                        event_detail={}
                        current_app.logger.debug(f"event: {event_detail_redis}")

                        event_filters = sub.get("event_filters", None)
                        event_filter=None
                        if event_filters:
                            try:
                                event_filter = None if all(value is None for value in event_filters[sub.get("events", []).index(event)].values()) else event_filters[sub.get("events", []).index(event)]
                                current_app.logger.debug(f"Event filters: {event_filter}")
                            except IndexError:
                                event_filter=None

                        if event in ["SERVICE_API_AVAILABLE", "SERVICE_API_UNAVAILABLE"]:
                            if event_filter:
                                api_ids_list = event_filter.get("api_ids", None)
                                if api_ids_list and event_detail_redis.get('apiIds', None)[0] in api_ids_list:
                                    event_detail["apiIds"]=event_detail_redis.get('apiIds', None)
                                    if return_negotiated_supp_feat_dict(sub["supported_features"])["ApiStatusMonitoring"]:
                                        event_detail["serviceAPIDescriptions"]=event_detail_redis.get('serviceAPIDescriptions', None)
                                else:
                                    continue
                            else:
                                event_detail["apiIds"]=event_detail_redis.get('apiIds', None)
                                if return_negotiated_supp_feat_dict(sub["supported_features"])["ApiStatusMonitoring"]:
                                    event_detail["serviceAPIDescriptions"]=event_detail_redis.get('serviceAPIDescriptions', None)
                        elif event in ["SERVICE_API_UPDATE"]:
                            if event_filter:
                                api_ids_list = event_filter.get("api_ids", None)
                                if api_ids_list and event_detail_redis.get('serviceAPIDescriptions', {})[0].get('apiId') in api_ids_list:
                                    event_detail["serviceAPIDescriptions"]=event_detail_redis.get('serviceAPIDescriptions', None)
                                else:
                                    continue
                            else:
                                event_detail["serviceAPIDescriptions"]=event_detail_redis.get('serviceAPIDescriptions', None)
                        elif event in ["API_INVOKER_ONBOARDED", "API_INVOKER_OFFBOARDED", "API_INVOKER_UPDATED"]:
                            if event_filter:
                                invoker_ids_list = event_filter.get("api_invoker_ids", None)
                                if invoker_ids_list and event_detail_redis.get('apiInvokerIds', None)[0] in invoker_ids_list:
                                    event_detail["apiInvokerIds"]=event_detail_redis.get('apiInvokerIds', None)
                                else:
                                    continue
                            else:
                                event_detail["apiInvokerIds"]=event_detail_redis.get('apiInvokerIds', None)
                        elif event in ["ACCESS_CONTROL_POLICY_UPDATE"]:
                            if event_filter:
                                filter_invoker_ids = event_filter.get("api_invoker_ids", [])
                                filter_api_ids = event_filter.get("api_ids", [])

                                invoker_ids_list = [invoker.get("apiInvokerId") for invoker in event_detail_redis.get("accCtrlPolList", None).get("apiInvokerPolicies")]
                                api_id = event_detail_redis.get("accCtrlPolList").get("apiId", None)

                                if (filter_api_ids and not filter_invoker_ids) and (api_id in filter_api_ids):
                                    event_detail["accCtrlPolList"]=event_detail_redis.get('accCtrlPolList', None)                               
                                elif (not filter_api_ids and filter_invoker_ids) and bool(set(filter_invoker_ids) & set(invoker_ids_list)):
                                    event_detail["accCtrlPolList"]=event_detail_redis.get('accCtrlPolList', None)
                                elif (filter_api_ids and filter_invoker_ids) and bool(set(filter_invoker_ids) & set(invoker_ids_list)) and api_id in filter_api_ids:
                                    event_detail["accCtrlPolList"]=event_detail_redis.get('accCtrlPolList', None)
                                else:
                                    continue
                            else:
                                event_detail["accCtrlPolList"]=event_detail_redis.get('accCtrlPolList', None)
                        elif event in ["SERVICE_API_INVOCATION_SUCCESS", "SERVICE_API_INVOCATION_FAILURE"]:
                            if event_filter:
                                filter_invoker_ids = event_filter.get("api_invoker_ids", None)
                                filter_api_ids = event_filter.get("api_ids", None)
                                filter_aef_ids = event_filter.get("aef_ids", None)

                                invoker_id = event_detail_redis.get("invocationLogs", None)[0].get("api_invoker_id", None)
                                aef_id = event_detail_redis.get("invocationLogs", None)[0].get("aef_id", None)
                                api_id = event_detail_redis.get("invocationLogs", None)[0].get("logs", None)[0].get("api_id", None)

                                if (filter_api_ids and not filter_invoker_ids and not filter_aef_ids) and (api_id in filter_api_ids):
                                   event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                                elif (not filter_api_ids and filter_invoker_ids and not filter_aef_ids) and invoker_id in filter_invoker_ids:
                                   event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                                elif (not filter_api_ids and not filter_invoker_ids and filter_aef_ids) and aef_id in filter_aef_ids:
                                   event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                                elif (filter_api_ids and filter_invoker_ids and not filter_aef_ids) and (api_id in filter_api_ids) and invoker_id in filter_invoker_ids:
                                   event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)                                
                                elif (filter_api_ids and not filter_invoker_ids and filter_aef_ids) and (api_id in filter_api_ids) and aef_id in filter_aef_ids:
                                    event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                                elif (not filter_api_ids and filter_invoker_ids and filter_aef_ids) and invoker_id in filter_invoker_ids and aef_id in filter_aef_ids:
                                    event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)                               
                                elif (filter_api_ids and filter_invoker_ids and filter_aef_ids) and (api_id in filter_api_ids) and invoker_id in filter_invoker_ids and aef_id in filter_aef_ids:
                                    event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                                else:
                                    continue
                                    
                            else:
                                event_detail["invocationLogs"]=event_detail_redis.get('invocationLogs', None)
                        elif event in ["API_TOPOLOGY_HIDING_CREATED", "API_TOPOLOGY_HIDING_REVOKED"]:
                            event_detail["apiTopoHide"]=event_detail_redis.get('apiTopoHide', None)

                        current_app.logger.debug(event_detail)
                        data.event_detail=event_detail

                current_app.logger.debug(json.dumps(data.to_dict(),cls=CustomJSONEncoder))

                if return_negotiated_supp_feat_dict(sub["supported_features"])["EnhancedEventReport"] and sub.get("event_req", None):
                    current_app.logger.debug(f"Creating notification for {sub['subscription_id']}")

                    if sub["event_req"]["notif_method"] == "PERIODIC":
                        transcurred_time = (datetime.now(timezone.utc)-sub["created_at"]).total_seconds()
                        if transcurred_time > sub["event_req"]["rep_period"]:
                            transcurred_blocks = int(transcurred_time // sub["event_req"]["rep_period"])
                            next_report_time = sub["created_at"] + timedelta(seconds=((transcurred_blocks+1) * sub["event_req"]["rep_period"]))
                        else:
                            next_report_time = sub["created_at"] + timedelta(seconds=sub["event_req"]["rep_period"])

                        notification = {"notification": data.to_dict(), "next_report_time" : next_report_time, "url": url, "subscription_id": sub["subscription_id"]}

                        self.events_ops.add_notification(notification)
                        self.events_ops.update_report_nbr(sub["subscription_id"])

                    if sub["event_req"]["notif_method"] == "ONE_TIME":
                        asyncio.run(self.send(url, serialize_clean_camel_case(data)))
                        self.events_ops.delete_subscription(sub["subscription_id"])
                    
                    if sub["event_req"].get("max_report_nbr", None) and sub["report_nbr"] + 1 == sub["event_req"].get("max_report_nbr", None):
                        current_app.logger.debug(f"Limit reached, deleting subscription {sub['subscription_id']}")
                        self.events_ops.delete_subscription(sub["subscription_id"])

                else:
                    asyncio.run(self.send(url, serialize_clean_camel_case(data)))
                    self.events_ops.update_report_nbr(sub["subscription_id"])

                

        except Exception as e:
            current_app.logger.error("An exception occurred ::" + str(e))
            return False

    def request_post(self, url, data):
        headers = {'content-type': 'application/json'}
        return requests.post(url, json={'text': str(data.to_str())}, headers=headers, timeout=os.getenv("TIMEOUT", "30"))
    
    async def send_request(self, url, data):
        async with aiohttp.ClientSession() as session:
            timeout = aiohttp.ClientTimeout(total=10)  # Establecer timeout a 10 segundos
            headers = {'content-type': 'application/json'}
            async with session.post(url, json=data, timeout=timeout, headers=headers) as response:
                return await response.text()
    
    async def send(self, url, data):
        try:
            response = await self.send_request(url, data)
            current_app.logger.debug(response)
        except asyncio.TimeoutError:
            current_app.logger.error("Timeout: Request timeout")
        except Exception as e:
            current_app.logger.error("An exception occurred sending notification::" + str(e))
            return False
