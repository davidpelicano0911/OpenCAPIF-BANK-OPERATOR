from flask import current_app

from .auth_manager import AuthManager
from .resources import Resource


class InternalEventOperations(Resource):

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()

    def delete_all_events(self, subscriber_ids):

        for subscriber_id in subscriber_ids:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            my_query = {'subscriber_id': subscriber_id}
            mycol.delete_many(my_query)

            current_app.logger.info(f"Removed events for this subscriber: {subscriber_id}")

        #We dont need remove all auth events, becase when invoker is removed, remove auth entry
        #self.auth_manager.remove_auth_all_event(subscriber_id)
    
    def delete_subscription(self, subscription_id):

        mycol = self.db.get_col_by_name(self.db.event_collection)
        my_query = {'subscription_id': subscription_id}
        mycol.delete_one(my_query)

        current_app.logger.info(f"Removed subscription: {subscription_id}")

    def get_event_subscriptions(self, event):
        current_app.logger.debug("get subscription from db")
        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            query={'events':{'$in':[event]}}
            subscriptions = mycol.find(query)

            if  subscriptions is None:
                current_app.logger.warning("Not found event subscriptions")

            else:
                json_docs=[]
                for subscription in subscriptions:
                    json_docs.append(subscription)

                return json_docs

        except Exception as e:
            current_app.logger.error("An exception occurred ::" + str(e))
            return False
        
    def add_notification(self, notification):
        current_app.logger.debug("Adding Notification to notifications list")
        try:
            mycol = self.db.get_col_by_name(self.db.notifications_col)
            mycol.insert_one(notification)
            current_app.logger.info("Notification added to notifications list")
        except Exception as e:
            current_app.logger.error("An exception occurred ::" + str(e))
            return False
    
    def update_report_nbr(self, subscription_id):
        current_app.logger.debug("Incrementing report number")
        try:
            mycol = self.db.get_col_by_name(self.db.event_collection)
            my_query = {'subscription_id': subscription_id}
            result = mycol.update_one(my_query, {'$inc': {'report_nbr': 1}})
            current_app.logger.debug(result)
            current_app.logger.info("Report number incremented")
        except Exception as e:
            current_app.logger.error("An exception occurred ::" + str(e))
            return False

