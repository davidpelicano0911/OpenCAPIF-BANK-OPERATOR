import json

from flask import Response, current_app

from ..encoder import CustomJSONEncoder
from ..models.problem_details import ProblemDetails
from ..util import serialize_clean_camel_case
from .resources import Resource
from .responses import internal_server_error, not_found_error, forbidden_error


class ControlAccess(Resource):

    def validate_user_cert(self, event_id, subscriber_id, cert_signature):

        cert_col = self.db.get_col_by_name(self.db.certs_col)

        try:
            my_query = {'id':subscriber_id}
            cert_entry = cert_col.find_one(my_query)

            if cert_entry is None:
                return not_found_error(detail="Please provide an existing Subscriber ID", cause="Certificate not found for Invoker or APF or AEF or AMF")
            
            if (event_id is None and cert_entry["cert_signature"] != cert_signature):
                prob = ProblemDetails(title="Unauthorized", detail="User not authorized", cause="You are not the owner of this resource")
                prob = serialize_clean_camel_case(prob)

                return Response(json.dumps(prob, cls=CustomJSONEncoder), status=401, mimetype="application/json")
            elif event_id is not None and (cert_entry["cert_signature"] != cert_signature or "event_subscriptions" not in cert_entry["resources"] or event_id not in cert_entry["resources"]["event_subscriptions"]):
                prob = ProblemDetails(title="Unauthorized", detail="User not authorized", cause="You are not the owner of this resource")
                prob = serialize_clean_camel_case(prob)

                return Response(json.dumps(prob, cls=CustomJSONEncoder), status=401, mimetype="application/json")
        except Exception as e:
            exception = "An exception occurred in validate subscriber"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
