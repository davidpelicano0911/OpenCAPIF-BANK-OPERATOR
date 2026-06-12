import json
from flask import Response, current_app

class Resource:
    def __init__(self):
        # We use the existing mongo helper from your service
        from db.db import get_mongo
        self.db = get_mongo()

class ControlAccess(Resource):
    def validate_user_cert(self, api_provider_id, cert_signature):
        # Access the certificates collection in CAPIF database
        cert_col = self.db.get_col_by_name("certs")
        try:
            # Check if provider_id matches the certificate signature
            my_query = {'provider_id': api_provider_id}
            cert_entry = cert_col.find_one(my_query)

            if cert_entry is not None:
                if cert_entry["cert_signature"] != cert_signature:
                    # Return 401 if signatures don't match
                    prob = {
                        "title": "Unauthorized", 
                        "detail": "User not authorized", 
                        "cause": "You are not the owner of this resource"
                    }
                    return Response(json.dumps(prob), status=401, mimetype="application/json")
            return None
        except Exception as e:
            current_app.logger.error("Error in validate_user_cert: " + str(e))
            return Response(json.dumps({"title": "Internal Server Error", "detail": str(e)}), status=500, mimetype="application/json")