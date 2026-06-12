from ast import Not
import json

from flask import Response, current_app

from ..encoder import CustomJSONEncoder
from ..models.problem_details import ProblemDetails
from ..util import serialize_clean_camel_case
from .resources import Resource
from .responses import internal_server_error, unauthorized_error


class ControlAccess(Resource):

    def validate_user_cert(self, apf_id, cert_signature, service_id=None):

        cert_col = self.db.get_col_by_name(self.db.certs_col)

        try:
            my_query = {'id': apf_id}
            cert_entry = cert_col.find_one(my_query)

            if cert_entry is None:
                return unauthorized_error(detail="Please provide an existing APF ID", cause="Certificate not found for APF")
            
            is_user_owner = True
            if cert_entry["cert_signature"] != cert_signature:
                is_user_owner = False
            elif service_id:
                if "services" not in cert_entry["resources"]:
                    is_user_owner = False
                elif cert_entry.get("resources") and cert_entry["resources"].get("services"):
                    if service_id not in cert_entry["resources"].get("services"):
                        is_user_owner = False
            if is_user_owner == False:
                current_app.logger.info("STEP3")
                prob = ProblemDetails(
                    title="Unauthorized",
                    detail="User not authorized",
                    cause="You are not the owner of this resource")
                current_app.logger.info("STEP4")
                prob = serialize_clean_camel_case(prob)
                current_app.logger.info("STEP5")
                return Response(
                    json.dumps(prob, cls=CustomJSONEncoder),
                    status=401,
                    mimetype="application/json")

        except Exception as e:
            exception = "An exception occurred in validate apf"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
