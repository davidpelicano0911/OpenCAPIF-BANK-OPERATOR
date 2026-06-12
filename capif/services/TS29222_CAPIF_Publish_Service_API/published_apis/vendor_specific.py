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
                    f_key += find_attribute_in_body(val, temp_path + "." +  str(i))
    return f_key


def vendor_specific_key_n_value(vendor_specific_fields, body):
    vendor_specific = {}
    for field in vendor_specific_fields:
        parts = field.split('.')
        tmp_body = body
        for part in parts:
            if part.isnumeric():
                part = int(part)
            v = tmp_body[part]
            tmp_body = v
        vendor_specific[field] = v
    return vendor_specific

def add_vend_spec_fields(vendor_specific, serviceapidescription_dict):
    pattern = re.compile(r'(?<!^)(?=[A-Z])')
    for field, value in vendor_specific.items():
        parts = field.split('.')
        tmp_body = serviceapidescription_dict
        vs_field = parts[-1]
        for part in parts[:-1]:
            if part.isnumeric():
                part = int(part)
            else:
                part = pattern.sub('_', part).lower()
            tmp_body = tmp_body[part]
        tmp_body[vs_field] = value
    return serviceapidescription_dict