
import json

from flask import current_app

from ..core.resources import Resource
from ..core.responses import (internal_server_error, make_response,
                              not_found_error)
from ..models.discovered_apis import DiscoveredAPIs
from ..util import serialize_clean_camel_case
from ..vendor_specific import (filter_apis_with_vendor_specific_params,
                               find_attribute_in_body,
                               remove_vendor_specific_fields)

TOTAL_FEATURES = 4
SUPPORTED_FEATURES_HEX = "2"


def filter_fields(filtered_apis):
    key_filter = [
        "api_name", "api_id", "aef_profiles", "description",
        "supported_features", "shareable_info", "service_api_category",
        "api_supp_feats", "pub_api_path", "ccf_id", "api_status"
    ]
    field_filtered_api = {}
    for key in filtered_apis.keys():
        if key in key_filter or 'vendorSpecific' in key:
            field_filtered_api[key] = filtered_apis[key]
    return field_filtered_api


def return_negotiated_supp_feat_dict(supp_feat):

    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "ApiSupportedFeatureQuery": True if final_supp_feat[0] == "1" else False,
        "VendSpecQueryParams": True if final_supp_feat[1] == "1" else False,
        "RNAA": True if final_supp_feat[2] == "1" else False,
        "SliceBasedAPIExposure": True if final_supp_feat[3] == "1" else False
    }


class DiscoverApisOperations(Resource):

    def get_discoveredapis(self, api_invoker_id, query_params):

        services = self.db.get_col_by_name(self.db.service_api_descriptions)
        invokers = self.db.get_col_by_name(self.db.invoker_col)

        current_app.logger.debug("Discovering services apis by: " + api_invoker_id)

        try:
            invoker = invokers.find_one({"api_invoker_id": api_invoker_id})
            if invoker is None:
                current_app.logger.warning("Api invoker not found in database")
                return not_found_error(detail="API Invoker does not exist", cause="API Invoker id not found")

            my_params = []
            my_query = {}
            # QPV = Query Parameter Value
            query_params_name = {
                "api_name": "api_name",
                "api_version": '{"aef_profiles": {"$elemMatch": {"versions" : {"$elemMatch": {"api_version": "QPV"}}}}}',
                "comm_type": '{"aef_profiles": {"$elemMatch": {"versions" : {"$elemMatch": {"resources": {"$elemMatch": {"comm_type":"QPV"}}}}}}}',
                "protocol": '{"aef_profiles": {"$elemMatch": {"protocol":"QPV"}}}',
                "aef_id": '{"aef_profiles": {"$elemMatch": {"aef_id":"QPV"}}}',
                "data_format": '{"aef_profiles": {"$elemMatch": {"data_format":"QPV"}}}',
                "api_cat": "service_api_category",
                "supported_features": "supported_features",
                "api_supported_features": "api_supp_feats"
            }

            vend_spec_query_params_n_values = {}
            supp_feat = query_params["supported_features"]
            del query_params["supported_features"]

            for param in query_params:
                if query_params[param] is not None:
                    if "vend-spec" in param:
                        vend_param = param.split("vend-spec-")[1]
                        attribute_path = query_params[param]["target"].split('/')
                        vend_spec_query_params_n_values[".".join(attribute_path[1:]) + "." + vend_param] = query_params[param]["value"]
                    elif param in ["api_version", "comm_type", "protocol", "aef_id", "data_format"]:
                        my_params.append(json.loads(query_params_name[param].replace("QPV", query_params[param])))
                    else:
                        my_params.append({query_params_name[param]: query_params[param]})

            if my_params:
                my_query = {"$and": my_params}

            discoved_apis = services.find(my_query, {"_id":0})
            json_docs = []
            if supp_feat is None:
                for discoved_api in discoved_apis:
                    vendor_specific_fields_path = find_attribute_in_body(discoved_api, '')
                    json_docs.append(filter_fields(remove_vendor_specific_fields(discoved_api, vendor_specific_fields_path)))
            else:
                supported_features = return_negotiated_supp_feat_dict(supp_feat)
                if supported_features['VendSpecQueryParams']:
                    for discoved_api in discoved_apis:
                        vendor_specific_fields_path = find_attribute_in_body(discoved_api, '')
                        if vendor_specific_fields_path:
                            if vend_spec_query_params_n_values:
                                pass_filter = filter_apis_with_vendor_specific_params(discoved_api,
                                                                                      vend_spec_query_params_n_values)
                                if pass_filter:
                                    json_docs.append(filter_fields(discoved_api))
                            else:
                                json_docs.append(filter_fields(discoved_api))
                else:
                    for discoved_api in discoved_apis:
                        vendor_specific_fields_path = find_attribute_in_body(discoved_api, '')
                        if not vendor_specific_fields_path:
                            json_docs.append(filter_fields(discoved_api))

            if len(json_docs) == 0:
                return not_found_error(detail="API Invoker " + api_invoker_id + " has no API Published that accomplish filter conditions", cause="No API Published accomplish filter conditions")

            apis_discovered = DiscoveredAPIs(service_api_descriptions=json_docs)
            res = make_response(object=serialize_clean_camel_case(apis_discovered), status=200)
            return res

        except Exception as e:
            exception = "An exception occurred in discover services"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

