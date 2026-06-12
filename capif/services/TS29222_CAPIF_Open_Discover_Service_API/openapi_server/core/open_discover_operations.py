import json
import re

from flask import current_app, request

from ..util import clean_empty, dict_to_camel_case
from ..vendor_specific import (filter_apis_with_vendor_specific_params,
                               find_attribute_in_body,
                               remove_vendor_specific_fields)
from .resources import Resource
from .responses import (bad_request_error, internal_server_error,
                        make_response, not_found_error)

TOTAL_FEATURES = 4
SUPPORTED_FEATURES_HEX = "2"


CAMEL_TO_SNAKE_RE = re.compile(r"(?<!^)(?=[A-Z])")
QUERY_BRACKETS_RE = re.compile(r"\[([^\]]*)\]")
SUPPORTED_FEATURES_RE = re.compile(r"^[A-Fa-f0-9]*$")
SERVICE_KPIS_QUERY_KEYS = {
    "maxReqRate": "max_req_rate",
    "maxRestime": "max_restime",
    "availability": "availability",
    "avalComp": "aval_comp",
    "avalGraComp": "aval_gra_comp",
    "avalMem": "aval_mem",
    "avalStor": "aval_stor",
    "conBand": "con_band",
}


def return_negotiated_supp_feat_dict(supp_feat):
    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "ApiSupportedFeatureQuery": True if final_supp_feat[0] == "1" else False,
        "VendSpecQueryParams": True if final_supp_feat[1] == "1" else False,
        "RNAA": True if final_supp_feat[2] == "1" else False,
        "SliceBasedAPIExposure": True if final_supp_feat[3] == "1" else False,
    }


class OpenDiscoverOperations(Resource):

    @staticmethod
    def _coerce_query_scalar(value):
        if isinstance(value, list):
            return [OpenDiscoverOperations._coerce_query_scalar(entry) for entry in value]
        if not isinstance(value, str):
            return value
        if value.isdecimal():
            return int(value)
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value

    @staticmethod
    def _has_bracketed_query_param(query_name):
        return any(key.startswith(f"{query_name}[") for key in request.args)

    @staticmethod
    def _to_snake_case(value):
        if not isinstance(value, str):
            return value
        return CAMEL_TO_SNAKE_RE.sub("_", value).lower()

    @classmethod
    def _normalise_query_value(cls, value):
        if hasattr(value, "to_dict"):
            return cls._normalise_query_value(value.to_dict())
        if isinstance(value, dict):
            normalised = {}
            for key, entry in value.items():
                normalised_entry = cls._normalise_query_value(entry)
                if normalised_entry is None:
                    continue
                if isinstance(normalised_entry, (dict, list)) and not normalised_entry:
                    continue
                normalised[cls._to_snake_case(key)] = normalised_entry
            return normalised
        if isinstance(value, list):
            return [cls._normalise_query_value(entry) for entry in value]
        if isinstance(value, str) and value[:1] in ["{", "["]:
            try:
                return cls._normalise_query_value(json.loads(value))
            except json.JSONDecodeError:
                return value
        return value

    @classmethod
    def _insert_nested_query_value(cls, target, path, value):
        for key in path[:-1]:
            key = cls._to_snake_case(key)
            target = target.setdefault(key, {})
        target[cls._to_snake_case(path[-1])] = cls._coerce_query_scalar(value)

    @classmethod
    def _extract_object_query_param(cls, query_name):
        if query_name in request.args:
            return cls._normalise_query_value(request.args[query_name])

        extracted = {}
        prefix = f"{query_name}["
        for key in request.args:
            if not key.startswith(prefix):
                continue
            path = QUERY_BRACKETS_RE.findall(key)
            if not path:
                continue
            values = request.args.getlist(key)
            value = values if len(values) > 1 else values[0]
            cls._insert_nested_query_value(extracted, path, value)

        return extracted or None

    @classmethod
    def _extract_json_content_query_param(cls, query_name):
        if query_name not in request.args:
            return None
        return cls._normalise_query_value(request.args[query_name])

    @classmethod
    def _extract_array_object_query_param(cls, query_name):
        if query_name in request.args:
            value = cls._normalise_query_value(request.args[query_name])
            return value if isinstance(value, list) else [value]

        extracted = []
        prefix = f"{query_name}["
        for key in request.args:
            if not key.startswith(prefix):
                continue
            path = QUERY_BRACKETS_RE.findall(key)
            if not path:
                continue

            if path[0].isdecimal():
                index = int(path[0])
                while len(extracted) <= index:
                    extracted.append({})
                target = extracted[index]
                path = path[1:]
            else:
                if not extracted:
                    extracted.append({})
                target = extracted[0]

            if not path:
                continue
            values = request.args.getlist(key)
            value = values if len(values) > 1 else values[0]
            cls._insert_nested_query_value(target, path, value)

        return [entry for entry in extracted if entry] or None

    @classmethod
    def _split_form_values(cls, values):
        split_values = []
        for value in cls._ensure_list(values):
            if isinstance(value, str):
                split_values.extend(entry for entry in value.split(",") if entry)
            else:
                split_values.append(value)
        return split_values

    @classmethod
    def _extract_requested_api_names(cls, query_params):
        api_names = []
        raw_api_names = query_params.get("api_names")

        if raw_api_names is None and "api-names" in request.args:
            raw_api_names = request.args.getlist("api-names")

        for value in cls._ensure_list(raw_api_names):
            api_names.extend(cls._split_form_values(value))

        return [str(api_name) for api_name in api_names if api_name]

    @classmethod
    def _extract_form_exploded_api_filters(cls, api_names):
        api_versions = {}
        api_supported_features = {}

        for api_name in api_names:
            if api_name not in request.args:
                continue

            for value in cls._split_form_values(request.args.getlist(api_name)):
                if not isinstance(value, str):
                    value = str(value)

                if value.lower().startswith("v") or not SUPPORTED_FEATURES_RE.fullmatch(value):
                    api_versions.setdefault(api_name, []).append(value)
                else:
                    api_supported_features[api_name] = value

        return api_versions or None, api_supported_features or None

    @classmethod
    def _extract_form_exploded_service_kpis(cls):
        service_kpis = {}

        for query_name, field_name in SERVICE_KPIS_QUERY_KEYS.items():
            if query_name not in request.args:
                continue

            values = request.args.getlist(query_name)
            if not values:
                continue

            service_kpis[field_name] = cls._coerce_query_scalar(values[-1])

        return service_kpis or None

    @classmethod
    def _populate_complex_query_params_from_request(cls, query_params):
        api_names = cls._extract_requested_api_names(query_params)
        api_versions = query_params.get("api_versions")
        api_supported_features = query_params.get("api_supported_features")
        form_api_versions, form_api_supported_features = cls._extract_form_exploded_api_filters(api_names)

        if not api_versions and form_api_versions:
            query_params["api_versions"] = form_api_versions
        if not api_supported_features and form_api_supported_features:
            query_params["api_supported_features"] = form_api_supported_features

        preferred_aef_loc = cls._normalise_query_value(
            query_params.get("preferred_aef_loc")
        )
        if not preferred_aef_loc:
            preferred_aef_loc = cls._extract_json_content_query_param(
                "preferred-aef-loc"
            )
        query_params["preferred_aef_loc"] = preferred_aef_loc

        service_kpis = cls._normalise_query_value(query_params.get("service_kpis"))
        if not service_kpis:
            service_kpis = cls._extract_form_exploded_service_kpis()
        if not service_kpis:
            service_kpis = cls._extract_object_query_param("service-kpis")
        query_params["service_kpis"] = service_kpis

        res_ops = cls._normalise_query_value(query_params.get("res_ops"))
        if not res_ops:
            res_ops = cls._extract_array_object_query_param("res-ops")
        query_params["res_ops"] = res_ops

    @classmethod
    def _object_elem_match(cls, prefix, value):
        value = cls._normalise_query_value(value)
        if not isinstance(value, dict):
            return {prefix: value}

        match = {}

        def add_fields(path, current):
            if isinstance(current, dict):
                for key, entry in current.items():
                    add_fields(f"{path}.{cls._to_snake_case(key)}", entry)
            elif isinstance(current, list):
                match[path] = {"$all": current}
            else:
                match[path] = current

        add_fields(prefix, value)
        return match

    @classmethod
    def _aef_profile_object_query(cls, field_name, value):
        return {
            "aef_profiles": {
                "$elemMatch": cls._object_elem_match(field_name, value)
            }
        }

    @classmethod
    def _resource_operations_query(cls, res_oper_info):
        res_oper_info = cls._normalise_query_value(res_oper_info)
        if not isinstance(res_oper_info, dict):
            return None

        resource_match = {}
        custom_operations = cls._ensure_list(res_oper_info.get("custom_serv_opers"))
        operations = cls._ensure_list(res_oper_info.get("operations"))

        if res_oper_info.get("resource") is not None:
            resource_match["uri"] = res_oper_info["resource"]
        if operations:
            resource_match["operations"] = {"$all": operations}
        if custom_operations:
            resource_match["cust_operations"] = {
                "$elemMatch": {"cust_op_name": {"$in": custom_operations}}
            }

        if not resource_match:
            return None

        return {
            "aef_profiles": {
                "$elemMatch": {
                    "versions": {
                        "$elemMatch": {
                            "resources": {
                                "$elemMatch": resource_match
                            }
                        }
                    }
                }
            }
        }

    @staticmethod
    def _ensure_list(value):
        if value is None:
            return []
        if isinstance(value, list):
            return value
        if isinstance(value, tuple):
            return list(value)
        return [value]

    @staticmethod
    def _to_open_discovery_shape(service_api_doc):
        open_doc = {}

        key_filter = [
            "api_name",
            "api_id",
            "api_status",
            "description",
            "service_api_category",
            "api_supp_feats",
            "api_prov_name",
            "aef_profiles",
        ]

        for key in service_api_doc.keys():
            if key in key_filter or "vendorSpecific" in key:
                open_doc[key] = service_api_doc[key]

        if "aef_profiles" in open_doc:
            for idx, aef_profile in enumerate(open_doc["aef_profiles"]):
                if not isinstance(aef_profile, dict):
                    continue
                filtered_profile = {}
                for key in [
                    "aef_id",
                    "versions",
                    "protocol",
                    "data_format",
                    "aef_location",
                    "service_kpis",
                ]:
                    if key in aef_profile:
                        filtered_profile[key] = aef_profile[key]
                open_doc["aef_profiles"][idx] = filtered_profile

        return clean_empty(open_doc)

    def get_open_discovered_apis(self, query_params):
        services = self.db.get_col_by_name(self.db.service_api_descriptions)

        current_app.logger.debug("Open discovering services apis")

        try:
            my_params = []
            my_query = {}

            query_params_name = {
                "api_names": "api_name",
                "api_versions": '{"aef_profiles": {"$elemMatch": {"versions": {"$elemMatch": {"api_version": "QPV"}}}}}',
                "comm_type": '{"aef_profiles": {"$elemMatch": {"versions": {"$elemMatch": {"resources": {"$elemMatch": {"comm_type": "QPV"}}}}}}}',
                "protocols": '{"aef_profiles": {"$elemMatch": {"protocol": "QPV"}}}',
                "data_format": '{"aef_profiles": {"$elemMatch": {"data_format": "QPV"}}}',
                "api_cats": "service_api_category",
                "api_supported_features": "api_supp_feats",
                "api_ids": "api_id",
                "api_prov_names": "api_prov_name",
                "preferred_aef_loc": "aef_location",
                "service_kpis": "service_kpis",
                "res_ops": "resources",
            }
            nested_query_params = ["api_versions", "comm_type", "protocols", "data_format"]

            vend_spec_query_params_n_values = {}

            supp_feat = query_params["supported_features"]
            del query_params["supported_features"]

            if self._has_bracketed_query_param("preferred-aef-loc"):
                return bad_request_error(
                    detail="Invalid query parameter format",
                    cause="preferred-aef-loc must be sent as an application/json query parameter",
                    invalid_params=[
                        {
                            "param": "preferred-aef-loc",
                            "reason": 'Use preferred-aef-loc={"dcId":"..."}',
                        }
                    ],
                )

            self._populate_complex_query_params_from_request(query_params)

            if supp_feat is not None:
                supp_feat_dict = return_negotiated_supp_feat_dict(supp_feat)
                if supp_feat_dict["VendSpecQueryParams"]:
                    for q_param in request.args:
                        if "vend-spec" in q_param:
                            query_params[q_param] = json.loads(request.args[q_param])

            for param in query_params:
                if query_params[param] is None:
                    continue

                if "vend-spec" in param:
                    vend_param = param.split("vend-spec-")[1]
                    attribute_path = query_params[param]["target"].split("/")
                    vend_spec_query_params_n_values[".".join(attribute_path[1:]) + "." + vend_param] = query_params[param][
                        "value"
                    ]
                    continue

                if param not in query_params_name:
                    continue

                if param == "preferred_aef_loc":
                    my_params.append(
                        self._aef_profile_object_query(
                            query_params_name[param], query_params[param]
                        )
                    )
                    continue

                if param == "service_kpis":
                    my_params.append(
                        self._aef_profile_object_query(
                            query_params_name[param], query_params[param]
                        )
                    )
                    continue

                if param == "res_ops":
                    for res_oper_info in self._ensure_list(query_params[param]):
                        res_ops_query = self._resource_operations_query(res_oper_info)
                        if res_ops_query is not None:
                            my_params.append(res_ops_query)
                    continue

                if param in nested_query_params:
                    if param == "api_versions" and isinstance(query_params[param], dict):
                        for _, versions in query_params[param].items():
                            for version in self._ensure_list(versions):
                                my_params.append(
                                    json.loads(query_params_name[param].replace("QPV", str(version)))
                                )
                    else:
                        for entry in self._ensure_list(query_params[param]):
                            my_params.append(
                                json.loads(query_params_name[param].replace("QPV", str(entry)))
                            )
                    continue

                if param == "api_supported_features":
                    if isinstance(query_params[param], dict):
                        for api_name, api_supp_feat in query_params[param].items():
                            my_params.append({"$and": [{"api_name": api_name}, {"api_supp_feats": api_supp_feat}]})
                    else:
                        my_params.append({query_params_name[param]: query_params[param]})
                    continue

                for entry in self._ensure_list(query_params[param]):
                    my_params.append({query_params_name[param]: entry})

            if my_params:
                my_query = {"$and": my_params}

            discovered_apis = services.find(my_query, {"_id": 0})

            json_docs = []
            if supp_feat is None:
                for discovered_api in discovered_apis:
                    vendor_specific_fields_path = find_attribute_in_body(discovered_api, "")
                    json_docs.append(
                        self._to_open_discovery_shape(
                            remove_vendor_specific_fields(discovered_api, vendor_specific_fields_path)
                        )
                    )
            else:
                supported_features = return_negotiated_supp_feat_dict(supp_feat)
                if supported_features["VendSpecQueryParams"]:
                    for discovered_api in discovered_apis:
                        vendor_specific_fields_path = find_attribute_in_body(discovered_api, "")
                        if vendor_specific_fields_path:
                            if vend_spec_query_params_n_values:
                                pass_filter = filter_apis_with_vendor_specific_params(
                                    discovered_api, vend_spec_query_params_n_values
                                )
                                if pass_filter:
                                    json_docs.append(self._to_open_discovery_shape(discovered_api))
                            else:
                                json_docs.append(self._to_open_discovery_shape(discovered_api))
                else:
                    for discovered_api in discovered_apis:
                        vendor_specific_fields_path = find_attribute_in_body(discovered_api, "")
                        if not vendor_specific_fields_path:
                            json_docs.append(self._to_open_discovery_shape(discovered_api))

            if len(json_docs) == 0:
                return not_found_error(
                    detail="No API Published accomplish filter conditions",
                    cause="No API Published accomplish filter conditions",
                )

            open_docs = [dict_to_camel_case(doc) for doc in json_docs]
            response_body = {"discApis": open_docs}
            if supp_feat is not None:
                response_body["suppFeat"] = supp_feat

            return make_response(clean_empty(response_body), 200)

        except (ValueError, KeyError) as exc:
            current_app.logger.error(f"Open discover bad request: {str(exc)}")
            return bad_request_error(
                detail="Invalid query parameter format",
                cause=str(exc),
                invalid_params=[],
            )
        except Exception as exc:
            exception = "An exception occurred in open discover services"
            current_app.logger.error(exception + "::" + str(exc))
            return internal_server_error(detail=exception, cause=str(exc))
