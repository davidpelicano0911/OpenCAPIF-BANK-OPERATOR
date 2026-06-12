import unittest

from capif_events.models.event_subscription import \
    EventSubscription  # noqa: E501
from capif_events.models.problem_details import ProblemDetails  # noqa: E501
from capif_events.test import BaseTestCase
from flask import json


class TestCAPIFsEventsSubscriptionsCollectionController(BaseTestCase):
    """CAPIFsEventsSubscriptionsCollectionController integration test stubs"""

    def test_create_event_subsc(self):
        """Test case for create_event_subsc

        Create a new CAPIFs Event Subscription.
        """
        event_subscription = {"notificationDestination":"notificationDestination","eventFilters":[{"aefIds":["aefIds","aefIds"],"apiInvokerIds":["apiInvokerIds","apiInvokerIds"],"apiIds":["apiIds","apiIds"]},{"aefIds":["aefIds","aefIds"],"apiInvokerIds":["apiInvokerIds","apiInvokerIds"],"apiIds":["apiIds","apiIds"]}],"supportedFeatures":"supportedFeatures","eventReq":{"notifMethod":"PERIODIC","partitionCriteria":["TAC","TAC"],"grpRepTime":5,"notifFlag":"ACTIVATE","mutingSetting":{"maxNoOfNotif":5,"durationBufferedNotif":2},"monDur":"2000-01-23T04:56:07.000+00:00","immRep":True,"maxReportNbr":0,"repPeriod":6,"sampRatio":15,"notifFlagInstruct":{"bufferedNotifs":"SEND_ALL","subscription":"CLOSE"}},"websockNotifConfig":{"requestWebsocketUri":True,"websocketUri":"websocketUri"},"events":["SERVICE_API_AVAILABLE","SERVICE_API_AVAILABLE"],"requestTestNotification":True}
        headers = { 
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        response = self.client.open(
            '/capif-events/v1/{subscriber_id}/subscriptions'.format(subscriber_id='subscriber_id_example'),
            method='POST',
            headers=headers,
            data=json.dumps(event_subscription),
            content_type='application/json')
        self.assert200(response,
                       'Response body is : ' + response.data.decode('utf-8'))


if __name__ == '__main__':
    unittest.main()
