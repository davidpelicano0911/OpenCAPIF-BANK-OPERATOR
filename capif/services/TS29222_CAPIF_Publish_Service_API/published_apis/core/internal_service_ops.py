
from flask import current_app

from .auth_manager import AuthManager
from .resources import Resource


class InternalServiceOps(Resource):

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()

    def delete_intern_service(self, apf_ids):

        current_app.logger.debug("Provider removed, removing services published by APF")
        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)
        for apf_id in apf_ids:
            my_query = {'apf_id': apf_id}
            mycol.delete_many(my_query)

        #We dont need remove all auth events, because when provider is removed, remove auth entry
        #self.auth_manager.remove_auth_all_service(apf_id)

        current_app.logger.info("Removed service")
