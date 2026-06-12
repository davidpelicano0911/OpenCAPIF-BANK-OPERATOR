from functools import wraps

from capif_events.models.event_subscription import \
    EventSubscription  # noqa: E501
from capif_events.models.event_subscription_patch import \
    EventSubscriptionPatch  # noqa: E501
from capif_events.models.problem_details import ProblemDetails  # noqa: E501
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import unauthorized_error

from ..core.events_apis import EventSubscriptionsOperations
from ..core.validate_user import ControlAccess

events_ops = EventSubscriptionsOperations()
valid_user = ControlAccess()

def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):

            args = request.view_args
            cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            
            if not cert_tmp:
                return unauthorized_error("Client certificate required", "X-Ssl-Client-Cert header is missing")
            
            cert_raw = cert_tmp.replace('\t', '')

            cert = x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())

            cn = cert.subject.get_attributes_for_oid(x509.OID_COMMON_NAME)[0].value.strip()

            if cn != "superadmin":
                cert_signature = cert.signature.hex()
                if request.method != 'POST':
                    result = valid_user.validate_user_cert(args["subscriptionId"], args["subscriberId"], cert_signature)
                else:
                    result = valid_user.validate_user_cert(None, args["subscriberId"], cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def delete_ind_event_subsc(subscriber_id, subscription_id):  # noqa: E501
    """Delete an existing Individual CAPIF Events Subscription resource.

     # noqa: E501

    :param subscriber_id: Identifier of the Subscriber
    :type subscriber_id: str
    :param subscription_id: Identifier of an individual Events Subscription
    :type subscription_id: str

    :rtype: Union[None, Tuple[None, int], Tuple[None, int, Dict[str, str]]
    """
    current_app.logger.debug("Removing event subscription")

    res = events_ops.delete_event(subscriber_id, subscription_id)

    return res

@cert_validation()
def modify_ind_event_subsc(subscriber_id, subscription_id, body):  # noqa: E501
    """Modify an existing Individual CAPIF Events Subscription resource.

     # noqa: E501

    :param subscriber_id: Identifier of the Subscriber
    :type subscriber_id: str
    :param subscription_id: Identifier of the individual Subscriber
    :type subscription_id: str
    :param event_subscription_patch: 
    :type event_subscription_patch: dict | bytes

    :rtype: Union[EventSubscription, Tuple[EventSubscription, int], Tuple[EventSubscription, int, Dict[str, str]]
    """
    if request.is_json:
        body = EventSubscriptionPatch.from_dict(request.get_json())  # noqa: E501
    
    res = events_ops.patch_event(body, subscriber_id, subscription_id)
    return res

@cert_validation()
def update_ind_event_subsc(subscriber_id, subscription_id, body):  # noqa: E501
    """Update an existing Individual CAPIF Events Subscription resource.

     # noqa: E501

    :param subscriber_id: Identifier of the Subscriber
    :type subscriber_id: str
    :param subscription_id: Identifier of the individual Subscriber
    :type subscription_id: str
    :param event_subscription: 
    :type event_subscription: dict | bytes

    :rtype: Union[EventSubscription, Tuple[EventSubscription, int], Tuple[EventSubscription, int, Dict[str, str]]
    """
    if request.is_json:
        body = EventSubscription.from_dict(request.get_json())  # noqa: E501
    
    res = events_ops.put_event(body, subscriber_id, subscription_id)
    return res
