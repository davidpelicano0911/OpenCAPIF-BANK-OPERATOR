import json

from flask import Response, current_app

from ..encoder import CustomJSONEncoder
from ..models.problem_details import ProblemDetails
from ..util import serialize_clean_camel_case
from .resources import Resource
from .responses import internal_server_error, not_found_error, forbidden_error


class ControlAccess(Resource):

    def validate_user_cert(self, api_invoker_id, cert_signature):

        cert_col = self.db.get_col_by_name(self.db.certs_col)

        try:

            my_query = {'id': api_invoker_id}
            cert_entry = cert_col.find_one(my_query)

            if cert_entry is None:
                return not_found_error(detail="Please provide an existing Network App ID", cause="Certificate not found for invoker")
            
            if cert_entry["cert_signature"] != cert_signature:
                return forbidden_error(detail="User not authorized", cause="You are not the owner of this resource")

        except Exception as e:
            exception = "An exception occurred in validate invoker"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))