import re


def find_attribute_in_body(test, path):
    f_key = []
    if type(test) == dict:
        for k, v in test.items():
            if 'vendorSpecific' in k:
                if path == '':
                    temp_path = k
                else:
                    temp_path = path + "." + k
                f_key.append(temp_path)
            elif type(v) == dict:
                if path == '':
                    temp_path = k
                else:
                    temp_path = path + "." + k
                f_key += find_attribute_in_body(v, temp_path)
            elif type(v) == list:
                if path == '':
                    temp_path = k
                else:
                    temp_path = path + "." + k
                for i, val in enumerate(v):
                    f_key += find_attribute_in_body(val, temp_path + "." + str(i))
    return f_key


def remove_vendor_specific_fields(discoved_api, vendor_specific_fields_path):
    for path in vendor_specific_fields_path:
        tmp_body = discoved_api
        parts = path.split('.')
        vs_field = parts[-1]
        for path_piece in parts[:-1]:
            if path_piece.isnumeric():
                path_piece = int(path_piece)
            tmp_body = tmp_body[path_piece]
        del tmp_body[vs_field]
    return discoved_api


def nested_key_exists(dictionary, keys):
    _dict = dictionary
    for key in keys:
        if isinstance(_dict, dict) and key in _dict:
            _dict = _dict[key]
        else:
            return False, -1
    return True, _dict


def filter_apis_with_vendor_specific_params(discoved_api, vend_spec_query_params_n_values):
    pass_filter = True
    for k, v in vend_spec_query_params_n_values.items():
        parts = k.split('.')
        exists, value = nested_key_exists(discoved_api, parts)
        if exists:
            if v != value:
                pass_filter = False
                break
    return pass_filter
