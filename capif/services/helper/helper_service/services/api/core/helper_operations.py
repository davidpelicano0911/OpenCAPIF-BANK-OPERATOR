import os

import pymongo
import requests
from config import Config
from db.db import get_mongo
from flask import current_app, jsonify


class HelperOperations:

    def __init__(self):
        self.db = get_mongo()
        self.mimetype = 'application/json'
        self.config = Config().get_config()
    
    def get_invokers(self, uuid, invoker_id, page, page_size, sort_order):
        current_app.logger.debug(f"Getting the invokers")
        invoker_col = self.db.get_col_by_name(self.db.invoker_col)

        total_invokers = invoker_col.count_documents({})

        filter = {}
        if uuid:
            filter["uuid"]=uuid
        if invoker_id:
            filter["api_invoker_id"]=invoker_id
        
        sort_direction = pymongo.DESCENDING if sort_order == "desc" else pymongo.ASCENDING

        if page_size and page:
            index = (page - 1) * page_size
            documents = invoker_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction).skip(index).limit(page_size)
            pages = (total_invokers + page_size - 1) // page_size
        else:
            documents = invoker_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction)
            pages = 1

        list_invokers= list(documents)
        long = len(list_invokers)
        
        return jsonify(message="Invokers returned successfully", 
                        invokers=list_invokers,
                        total = total_invokers,
                        long = long,
                        totalPages = pages,
                        sortOrder = sort_order), 200
    
    def get_providers(self, uuid, provider_id, page, page_size, sort_order):
        current_app.logger.debug(f"Getting the providers")
        provider_col = self.db.get_col_by_name(self.db.provider_col)

        total_providers = provider_col.count_documents({})

        filter = {}
        if uuid:
            filter["uuid"]=uuid
        if provider_id:
            filter["api_prov_dom_id"]=provider_id
        
        sort_direction = pymongo.DESCENDING if sort_order == "desc" else pymongo.ASCENDING

        if page_size and page:
            index = (page - 1) * page_size
            documents = provider_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction).skip(index).limit(page_size)
            pages = (total_providers + page_size - 1) // page_size
        else:
            documents = provider_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction)
            pages = 1

        list_providers = list(documents)
        long = len(list_providers)
        
        return jsonify(message="Providers returned successfully", 
                        providers=list_providers,
                        total = total_providers,
                        long = long,
                        totalPages = pages,
                        sortOrder = sort_order), 200
    
    def get_services(self, service_id, apf_id, api_name, page, page_size, sort_order):
        current_app.logger.debug(f"Getting the services")
        service_col = self.db.get_col_by_name(self.db.services_col)

        total_services = service_col.count_documents({})

        filter = {}
        if service_id:
            filter["api_id"]=service_id
        if apf_id:
            filter["apf_id"]=apf_id
        if api_name:
            filter["api_name"]=api_name
        
        sort_direction = pymongo.DESCENDING if sort_order == "desc" else pymongo.ASCENDING

        if page_size and page:
            index = (page - 1) * page_size
            documents = service_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction).skip(index).limit(page_size)
            pages = (total_services + page_size - 1) // page_size
        else:
            documents = service_col.find(filter,{"_id":0}).sort("onboarding_date", sort_direction)
            pages = 1

        list_services= list(documents)
        long = len(list_services)
        
        return jsonify(message="Services returned successfully", 
                        services=list_services,
                        total = total_services,
                        long = long,
                        totalPages = pages,
                        sortOrder = sort_order), 200
    
    def get_security(self, invoker_id,  page, page_size):
        current_app.logger.debug(f"Getting the security context")
        security_col = self.db.get_col_by_name(self.db.security_context_col)

        total_security = security_col.count_documents({})

        filter = {}

        if invoker_id:
            filter["api_invoker_id"]=invoker_id

        if page_size and page:
            index = (page - 1) * page_size
            documents = security_col.find(filter,{"_id":0}).skip(index).limit(page_size)
            pages = (total_security + page_size - 1) // page_size
        else:
            documents = security_col.find(filter,{"_id":0})
            pages = 1

        list_security= list(documents)
        long = len(list_security)
        
        return jsonify(message="Security context returned successfully", 
                        security=list_security,
                        total = total_security,
                        long = long,
                        totalPages = pages), 200
    
    def get_events(self, subscriber_id, subscription_id,  page, page_size):
        current_app.logger.debug(f"Getting the events")
        events_col = self.db.get_col_by_name(self.db.events)

        total_events = events_col.count_documents({})

        filter = {}

        if subscriber_id:
            filter["subscriber_id"]=subscriber_id
        if subscription_id:
            filter["subscription_id"]=subscription_id

        if page_size and page:
            index = (page - 1) * page_size
            documents = events_col.find(filter,{"_id":0}).skip(index).limit(page_size)
            pages = (total_events + page_size - 1) // page_size
        else:
            documents = events_col.find(filter,{"_id":0})
            pages = 1

        list_events= list(documents)
        long = len(list_events)
        
        return jsonify(message="Events returned successfully", 
                        events=list_events,
                        total = total_events,
                        long = long,
                        totalPages = pages), 200
    
    def remove_entities(self, uuid):

        current_app.logger.debug(f"Removing entities for uuid: {uuid}")
        invoker_col = self.db.get_col_by_name(self.db.invoker_col)
        provider_col = self.db.get_col_by_name(self.db.provider_col)

        try:
            if invoker_col.count_documents({'uuid':uuid}) == 0 and provider_col.count_documents({'uuid':uuid}) == 0:
                current_app.logger.debug(f"No entities found for uuid: {uuid}")
                return jsonify(message=f"No entities found for uuid: {uuid}"), 204
            
            for invoker in invoker_col.find({'uuid':uuid}, {"_id":0}):
                current_app.logger.debug(f"Removing Invoker: {invoker["api_invoker_id"]}")
                url = 'https://{}/api-invoker-management/v1/onboardedInvokers/{}'.format(os.getenv('CAPIF_HOSTNAME'), invoker["api_invoker_id"])
                requests.request("DELETE", url, cert=(
                            '/usr/src/app/helper_service/certs/superadmin.crt', '/usr/src/app/helper_service/certs/superadmin.key'), verify='/usr/src/app/helper_service/certs/ca_root.crt')

            for provider in provider_col.find({'uuid':uuid}, {"_id":0}):
                current_app.logger.debug(f"Removing Provider: {provider["api_prov_dom_id"]}")
                url = 'https://{}/api-provider-management/v1/registrations/{}'.format(os.getenv('CAPIF_HOSTNAME'), provider["api_prov_dom_id"])

                requests.request("DELETE", url, cert=(
                                '/usr/src/app/helper_service/certs/superadmin.crt', '/usr/src/app/helper_service/certs/superadmin.key'), verify='/usr/src/app/helper_service/certs/ca_root.crt')
        except Exception as e:
            current_app.logger.debug(f"Error deleting user entities: {e}")
            jsonify(message=f"Error deleting user entities: {e}"), 500
        
        current_app.logger.debug(f"User entities removed successfully")
        return jsonify(message="User entities removed successfully"), 200
    
    def get_ccf_id(self):
        """
        Returns the current CAPIF unique identifier (ccf_id).
        """
        current_app.logger.debug("Retrieving ccf_id from capif_configuration")

        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        config = config_col.find_one({}, {"_id": 0, "ccf_id": 1})

        if not config or "ccf_id" not in config:
            return jsonify(message="ccf_id not found"), 404

        return jsonify(ccf_id=config["ccf_id"]), 200
