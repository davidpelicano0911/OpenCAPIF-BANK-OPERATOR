import asyncio
import os
import secrets
from datetime import datetime, timezone

import rfc3987
from capif_events.models.event_subscription import \
    EventSubscription  # noqa: E501
from flask import Response, current_app

from ..util import clean_empty, dict_to_camel_case, serialize_clean_camel_case
from .auth_manager import AuthManager
from .notifications import Notifications
from .resources import Resource
from .responses import (bad_request_error, internal_server_error,
                        make_response, not_found_error)

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

class EventSubscriptionsOperations(Resource):

    def __init__(self):
        super().__init__()
        self.notifications = Notifications()

    def __check_subscriber_id(self, subscriber_id):
        mycol_invoker= self.db.get_col_by_name(self.db.invoker_collection)
        mycol_provider= self.db.get_col_by_name(self.db.provider_collection)

        current_app.logger.debug("Cheking subscriber id")

        invoker_query = {"api_invoker_id":subscriber_id}

        invoker = mycol_invoker.find_one(invoker_query)

        provider_query = {"api_prov_funcs.api_prov_func_id":subscriber_id}

        provider = mycol_provider.find_one(provider_query)

        if invoker is None and provider is None:
            current_app.logger.warning("Not found invoker or provider with this subscriber id")
            return not_found_error(detail="Invoker or APF or AEF or AMF Not found", cause="Subscriber Not Found")

        return None

    def __check_event_filters(self, events, filters):
        current_app.logger.debug("Checking event filters.")
        valid_filters = {
            "SERVICE_API_UPDATE": ["api_ids"],
            "SERVICE_API_AVAILABLE" : ["api_ids"],
            "SERVICE_API_UNAVAILABLE" : ["api_ids"],
            "API_INVOKER_ONBOARDED": ["api_invoker_ids"],
            "API_INVOKER_OFFBOARDED": ["api_invoker_ids"],
            "API_INVOKER_UPDATED": ["api_invoker_ids"],
            "ACCESS_CONTROL_POLICY_UPDATE":["api_invoker_ids", "api_ids"],
            "SERVICE_API_INVOCATION_SUCCESS": ["api_invoker_ids", "api_ids", "aef_ids"],
            "SERVICE_API_INVOCATION_FAILURE": ["api_invoker_ids", "api_ids", "aef_ids"],
            "API_TOPOLOGY_HIDING_CREATED": [],
            "API_TOPOLOGY_HIDING_REVOKED": []
        }

        for event, filter in zip(events, filters):
            invalid_filters = set(filter.keys()) - set(valid_filters.get(event, []))

            if invalid_filters:
                 current_app.logger.warning(f"The eventFilter {invalid_filters} for event {event} are not applicable.")
                 return bad_request_error(detail="Bad Param", cause = f"Invalid eventFilter for event {event}", invalid_params=[{"param": "eventFilter", "reason": f"The eventFilter {invalid_filters} for event {event} are not applicable."}])
        return None
    
    def __check_event_req(self, event_subscription, subscription_id=None):
        current_app.logger.debug("Checking event requirement.")
        expired_at = None
        if event_subscription.event_req.mon_dur:
            if event_subscription.event_req.mon_dur > datetime.now(timezone.utc):
                expired_at = event_subscription.event_req.mon_dur
            else:
                current_app.logger.warning("monDur is in the past")
                return bad_request_error(
                    detail="Bad Param",
                    cause="monDur is in the past",
                    invalid_params=[{"param": "monDur", "reason": "monDur is in the past"}]
                )
        
        if event_subscription.event_req.notif_method == "PERIODIC" and event_subscription.event_req.rep_period is None:
            current_app.logger.warning("Periodic notification method selected but repPeriod not provided")
            return bad_request_error(
                detail="Bad Param",
                cause="Periodic notification method selected but repPeriod not provided",
                invalid_params=[{"param": "repPeriod", "reason": "Periodic notification method selected but repPeriod not provided"}]
            )
        
        if event_subscription.event_req.imm_rep and subscription_id is not None:
            current_app.logger.debug("Sending immediate notification")
            notifications_col = self.db.get_col_by_name(self.db.notifications_col)
            result = notifications_col.find({"subscription_id": subscription_id})
            for notification in result:
                asyncio.run(self.notifications.send(notification["url"], notification["notification"]))

        return expired_at

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()

    def create_event(self, subscriber_id, event_subscription):

        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)

            current_app.logger.debug("Creating event")

            if rfc3987.match(event_subscription.notification_destination, rule="URI") is None:
                current_app.logger.warning("Bad url format")
                return bad_request_error(detail="Bad Param", cause = "Detected Bad formar of param", invalid_params=[{"param": "notificationDestination", "reason": "Not valid URL format"}])

            if event_subscription.supported_features is None:
                return bad_request_error(
                    detail="supportedFeatures not present in request",
                    cause="supportedFeatures not present",
                    invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
                )

            ## Verify that this subscriberID exist in publishers or invokers

            result = self.__check_subscriber_id(subscriber_id)

            if  isinstance(result, Response):

                return result

            negotiated_supported_features = return_negotiated_supp_feat_dict(event_subscription.supported_features)
            
            expired_at = None
            # Check if EnhancedEventReport is enabled and validate event filters
            if negotiated_supported_features["EnhancedEventReport"]:
                if event_subscription.event_filters:
                    current_app.logger.debug(event_subscription.event_filters)
                    result = self.__check_event_filters(event_subscription.events, clean_empty(event_subscription.to_dict()["event_filters"]))
                    if isinstance(result, Response):
                        return result
                if event_subscription.event_req:
                    current_app.logger.debug(event_subscription.event_req)
                    expired_at = self.__check_event_req(event_subscription)
                    if isinstance(expired_at, Response):
                        return result
            else:
                if event_subscription.event_filters:
                    current_app.logger.warning("Event filters provided but EnhancedEventReport is not enabled")
                    return bad_request_error(
                        detail="Bad Param",
                        cause="Event filters provided but EnhancedEventReport is not enabled",
                        invalid_params=[{"param": "eventFilters", "reason": "EnhancedEventReport is not enabled"}]
                    )
                if event_subscription.event_req:
                    current_app.logger.warning("Event requirement provided but EnhancedEventReport is not enabled")
                    return bad_request_error(
                        detail="Bad Param",
                        cause="Event requirement provided but EnhancedEventReport is not enabled",
                        invalid_params=[{"param": "eventReq", "reason": "EnhancedEventReport is not enabled"}]
                    )

            # Generate subscriptionID
            subscription_id = secrets.token_hex(15)
            evnt = dict()
            evnt["subscriber_id"] = subscriber_id
            evnt["subscription_id"] = subscription_id

            evnt["report_nbr"] = 0
            evnt["created_at"] = datetime.now(timezone.utc)
            evnt["expire_at"] = expired_at
            event_subscription.supported_features = negotiated_supported_features["Final"]

            evnt.update(event_subscription.to_dict())
            mycol.insert_one(evnt)

            current_app.logger.info("Event Subscription inserted in database")

            self.auth_manager.add_auth_event(subscription_id, subscriber_id)

            res = make_response(object=serialize_clean_camel_case(event_subscription), status=201)
            res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/capif-events/v1/{str(subscriber_id)}/subscriptions/{str(subscription_id)}"

            return res

        except Exception as e:
            exception = "An exception occurred in create event"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def delete_event(self, subscriber_id, subscription_id):

        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            notifications_col = self.db.get_col_by_name(self.db.notifications_col)

            current_app.logger.debug("Removing event subscription")

            result = self.__check_subscriber_id(subscriber_id)


            if  isinstance(result, Response):
                return result

            my_query = {'subscriber_id': subscriber_id,
                    'subscription_id': subscription_id}
            eventdescription = mycol.find_one(my_query)

            if eventdescription is None:
                current_app.logger.warning("Event subscription not found")
                return not_found_error(detail="Event subscription not exist", cause="Event API subscription id not found")

            mycol.delete_one(my_query)
            notifications_col.delete_many({"subscription_id": subscription_id})
            current_app.logger.info("Event subscription removed from database")

            self.auth_manager.remove_auth_event(subscription_id, subscriber_id)

            out =  "The event matching subscriptionId  " + subscription_id + " was deleted."
            return make_response(out, status=204)

        except Exception as e:
            exception= "An exception occurred in delete event"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def put_event(self, event_subscription, subscriber_id, subscription_id):
        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            notifications_col = self.db.get_col_by_name(self.db.notifications_col)

            current_app.logger.debug("Updating event subscription")

            if event_subscription.supported_features is None:
                return bad_request_error(
                    detail="supportedFeatures not present in request",
                    cause="supportedFeatures not present",
                    invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
                )

            result = self.__check_subscriber_id(subscriber_id)

            if  isinstance(result, Response):
                return result
            
            current_app.logger.debug(event_subscription)
            expired_at = None

            negotiated_supported_features = return_negotiated_supp_feat_dict(event_subscription.supported_features)
            if negotiated_supported_features["EnhancedEventReport"]:
                if event_subscription.event_filters:
                    current_app.logger.debug(event_subscription.event_filters)
                    result = self.__check_event_filters(event_subscription.events, clean_empty(event_subscription.to_dict()["event_filters"]))
                    if isinstance(result, Response):
                        return result
                if event_subscription.event_req:
                    current_app.logger.debug(event_subscription.event_req)
                    expired_at = self.__check_event_req(event_subscription)
                    if isinstance(expired_at, Response):
                        return result
            else:
                if event_subscription.event_filters:
                    current_app.logger.warning("Event filters provided but EnhancedEventReport is not enabled")
                    return bad_request_error(
                        detail="Bad Param",
                        cause="Event filters provided but EnhancedEventReport is not enabled",
                        invalid_params=[{"param": "eventFilters", "reason": "EnhancedEventReport is not enabled"}]
                    )
                if event_subscription.event_req:
                    current_app.logger.warning("Event requirement provided but EnhancedEventReport is not enabled")
                    return bad_request_error(
                        detail="Bad Param",
                        cause="Event requirement provided but EnhancedEventReport is not enabled",
                        invalid_params=[{"param": "eventReq", "reason": "EnhancedEventReport is not enabled"}]
                    )
            my_query = {'subscriber_id': subscriber_id,
                        'subscription_id': subscription_id}
            eventdescription = mycol.find_one(my_query)

            event_subscription.supported_features = negotiated_supported_features["Final"]

            body = event_subscription.to_dict()

            body["subscriber_id"] = subscriber_id
            body["subscription_id"] = subscription_id

            body["report_nbr"] = eventdescription.get("report_nbr", 0)
            body["created_at"] = eventdescription.get("created_at", datetime.now(timezone.utc))
            body["expire_at"] = expired_at if expired_at else eventdescription.get("expire_at", None)

            notifications_col.delete_many({"subscription_id": subscription_id})
            mycol.replace_one(my_query, body)
            current_app.logger.info("Event subscription updated from database")


            res = make_response(object=serialize_clean_camel_case(event_subscription), status=200)

            return res

        except Exception as e:
            exception= "An exception occurred in updating event"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))


    def patch_event(self, event_subscription, subscriber_id, subscription_id):
        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            notifications_col = self.db.get_col_by_name(self.db.notifications_col)

            current_app.logger.debug("Patching event subscription")

            result = self.__check_subscriber_id(subscriber_id)

            if  isinstance(result, Response):
                return result

            my_query = {'subscriber_id': subscriber_id,
                    'subscription_id': subscription_id}
            eventdescription = mycol.find_one(my_query)

            if eventdescription is None:
                current_app.logger.warning("Event subscription not found")
                return not_found_error(detail="Event subscription not exist", cause="Event API subscription id not found")

            current_app.logger.debug(event_subscription)
            expired_at = None
            
            negotiated_supported_features = return_negotiated_supp_feat_dict(eventdescription.get("supported_features"))

            if negotiated_supported_features["EnhancedEventReport"]:
                if event_subscription.events and event_subscription.event_filters:
                    result = self.__check_event_filters(event_subscription.events, clean_empty(event_subscription.to_dict()["event_filters"]))
                elif event_subscription.events and  event_subscription.event_filters is None and eventdescription.get("event_filters", None):
                    result = self.__check_event_filters(event_subscription.events, eventdescription.get("event_filters"))
                elif event_subscription.events is None and event_subscription.event_filters:
                    result = self.__check_event_filters(eventdescription.get("events"), clean_empty(event_subscription.to_dict()["event_filters"]))
                if  isinstance(result, Response):
                    return result
                
                if event_subscription.event_req:
                    updated_data = EventSubscription.from_dict(dict_to_camel_case({**eventdescription, **clean_empty(event_subscription.to_dict())}))
                    expired_at = self.__check_event_req(updated_data, subscription_id)
                    if isinstance(expired_at, Response):
                        return result
                    else:
                        expired_at = expired_at if expired_at else eventdescription.get("expire_at", None)

                if  isinstance(result, Response):
                    return result

            event_subscription.supported_features = negotiated_supported_features["Final"]

            body = clean_empty(event_subscription.to_dict())
            body["expire_at"] = expired_at
            notifications_col.delete_many({"subscription_id": subscription_id})
            document = mycol.update_one(my_query, {"$set":body})
            document = mycol.find_one(my_query)
            current_app.logger.info("Event subscription patched from database")

            res = make_response(object=EventSubscription.from_dict(dict_to_camel_case(document)), status=200)

            return res

        except Exception as e:
            exception= "An exception occurred in patching event"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
