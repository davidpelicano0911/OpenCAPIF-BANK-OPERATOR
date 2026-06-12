import uuid
from datetime import datetime, timezone
from db.db import get_mongo
from config import Config

from flask import request
from visibility_control.core.validate_user import ControlAccess

valid_user = ControlAccess()


def get_all_rules():
    db = get_mongo()
    col = db.get_col_by_name("visibility_rules")
    
    # The ID from the certificate (e.g., AMFe9d24...)
    cn = getattr(request, 'user_cn', None)

    # 1. Superadmin: No filters, returns everything
    if cn != "superadmin":
        # We look into CAPIF's provider registration to find the friendly name
        # assigned to this specific Certificate ID (CN)
        prov_col = db.get_col_by_name("provider_details") 
        provider = prov_col.find_one({"apiProvFuncs.apiProvFuncId": cn})
        
        friendly_name = provider.get('userName') if provider else None

        # The query uses an $or operator to ensure visibility:
        # - Rules where I am the owner (friendly_name)
        # - Rules I created or updated myself (cn)
        query_conditions = [{"updatedBy": cn}]
        if friendly_name:
            query_conditions.append({"providerSelector.userName": friendly_name})
        
        rules = list(col.find({"$or": query_conditions}, {"_id": 0}))
        return {"rules": rules}, 200
    
    rules = list(col.find({}, {"_id": 0}))
    return {"rules": rules}, 200


def create_new_rule(body):
    db = get_mongo()
    col = db.get_col_by_name("visibility_rules")

    # Get identity extracted by the decorator
    cn = request.user_cn
    cert_sig = request.cert_signature

    # Security check: If not superadmin, validate the mandatory identity
    if cn != "superadmin":
        ps = body.get('providerSelector', {})
        
        # We check apiProviderId if it exists, but we focus on the mandatory identity
        api_id = ps.get('apiProviderId', [None])[0]
        user_name = ps.get('userName')

        # Use the available ID to validate ownership via certificate signature
        # We prioritize apiProviderId, then userName as fallback for validation
        user_to_validate = api_id if api_id else user_name

        if user_to_validate:
            result = valid_user.validate_user_cert(user_to_validate, cert_sig)
            if result is not None:
                return result
        else:
            # If even userName is missing (despite being mandatory in your logic), 
            # we block it or handle it as a Bad Request
            return {"title": "Bad Request", "detail": "userName is mandatory"}, 400
    
    # 1. Generate a unique ruleId
    body['ruleId'] = str(uuid.uuid4())
    
    # 2. Generate current timestamp in UTC ISO 8601 format with 'Z'
    now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
    
    # 3. Handle and validate 'startsAt'
    if 'startsAt' not in body or not body['startsAt']:
        # If not provided, default to current time
        body['startsAt'] = now
    else:
        # If provided, validate ISO 8601 format
        try:
            datetime.fromisoformat(body['startsAt'].replace('Z', '+00:00'))
        except ValueError:
            return {
                "title": "Bad Request", 
                "detail": "Invalid startsAt format. Please use ISO 8601 (e.g., 2026-01-23T10:00:00Z)"
            }, 400

    # 4. 'updatedAt' is always set to current time during creation
    body['updatedAt'] = now

    # 5. Logic validation: endsAt must be greater than startsAt
    if 'endsAt' in body and body['endsAt']:
        try:
            # Convert strings to datetime objects for comparison
            start_dt = datetime.fromisoformat(body['startsAt'].replace('Z', '+00:00'))
            end_dt = datetime.fromisoformat(body['endsAt'].replace('Z', '+00:00'))
            
            if end_dt <= start_dt:
                return {
                    "title": "Bad Request", 
                    "detail": "Validation Error: endsAt must be later than startsAt"
                }, 400
        except ValueError:
            return {
                "title": "Bad Request", 
                "detail": "Invalid endsAt format."
            }, 400
        
    body['createdBy'] = cn 
    body['updatedBy'] = cn 

    # Save to MongoDB
    col.insert_one(body)
    
    # Remove Mongo internal ID before returning the response
    body.pop('_id', None)
    
    return body, 201

def get_rule_by_id(rule_id):
    """
    Retrieve a specific visibility rule by its ID.
    - Superadmin: Can view any rule.
    - Providers: Can view rules they own (userName) or created (updatedBy).
    """
    db = get_mongo()
    col = db.get_col_by_name("visibility_rules")
    cn = request.user_cn
    
    # 1. Fetch the rule from the database
    # We exclude the MongoDB internal _id field immediately
    rule = col.find_one({"ruleId": rule_id}, {"_id": 0})
    
    if not rule:
        return {"title": "Not Found", "detail": "Rule not found"}, 404

    # 2. Authorization Check: Superadmin bypass
    if cn == "superadmin":
        return rule, 200

    # 3. Identity Translation for Providers
    # Link the certificate CN to the registered Friendly Username
    prov_col = db.get_col_by_name("provider_details")
    provider = prov_col.find_one({"apiProvFuncs.apiProvFuncId": cn})
    friendly_name = provider.get('userName') if provider else None

    # 4. Permission Validation
    # is_owner: Checks the logical owner in the rule (userName)
    # is_creator: Checks the cryptographic signer (updatedBy)
    is_owner = rule.get('providerSelector', {}).get('userName') == friendly_name
    is_creator = rule.get('updatedBy') == cn

    if is_owner or is_creator:
        return rule, 200
    
    # 5. Deny access if the requester is neither the owner nor the creator
    return {
        "title": "Unauthorized", 
        "detail": "You do not have permission to view this rule"
    }, 401

def delete_rule_by_id(rule_id):
    """
    Delete a specific visibility rule after verifying ownership.
    - Superadmin: Can delete any rule.
    - Providers: Can only delete rules assigned to them or created by them.
    """
    db = get_mongo()
    col = db.get_col_by_name("visibility_rules")
    cn = request.user_cn

    # 1. Retrieve the rule to check metadata
    rule = col.find_one({"ruleId": rule_id})
    if not rule:
        return {"title": "Not Found", "detail": "Rule not found"}, 404

    # 2. Authorization Check: Superadmin bypass
    if cn == "superadmin":
        col.delete_one({"ruleId": rule_id})
        return None, 204

    # 3. Identity Translation for Providers
    # Resolve the certificate ID to the registered friendly username
    prov_col = db.get_col_by_name("provider_details")
    provider = prov_col.find_one({"apiProvFuncs.apiProvFuncId": cn})
    friendly_name = provider.get('userName') if provider else None

    # 4. Permissions Validation
    # is_owner: Checks if the rule's userName matches the provider's registered name.
    # is_creator: Checks if the rule was signed by the current certificate ID.
    is_owner = rule.get('providerSelector', {}).get('userName') == friendly_name
    is_creator = rule.get('updatedBy') == cn

    if is_owner or is_creator:
        res = col.delete_one({"ruleId": rule_id})
        if res.deleted_count > 0:
            return None, 204
    
    # 5. Deny access if no ownership is proven
    return {
        "title": "Unauthorized", 
        "detail": "You do not have permission to delete this rule"
    }, 401

def update_rule_patch(rule_id, body):
    """
    Update a specific visibility rule using PATCH logic.
    - Superadmin: Can modify any rule.
    - Providers: Can only modify rules they own or created.
    """
    db = get_mongo()
    col = db.get_col_by_name("visibility_rules")
    cn = request.user_cn
    
    # 1. Fetch existing rule to verify existence and check ownership
    existing_rule = col.find_one({"ruleId": rule_id})
    if not existing_rule:
        return {"title": "Not Found", "detail": "Rule not found"}, 404
    
    # 2. Authorization Check: Superadmin bypass
    if cn != "superadmin":
        # Resolve Certificate CN to the registered Friendly Username
        prov_col = db.get_col_by_name("provider_details")
        provider = prov_col.find_one({"apiProvFuncs.apiProvFuncId": cn})
        friendly_name = provider.get('userName') if provider else None

        # Ownership Validation:
        # - Check if the rule's userName matches the provider's registered name
        # - OR check if the rule was last updated/created by this specific certificate
        is_owner = existing_rule.get('providerSelector', {}).get('userName') == friendly_name
        is_creator = existing_rule.get('updatedBy') == cn

        if not (is_owner or is_creator):
            return {
                "title": "Unauthorized", 
                "detail": "You do not have permission to modify this rule"
            }, 401

    # 3. Metadata Updates
    now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
    body['updatedAt'] = now
    body['updatedBy'] = cn # Track who performed the update
    
    # 4. Date Logic Validation
    # Ensure startsAt is earlier than endsAt, even if only one is being updated
    new_start = body.get('startsAt', existing_rule.get('startsAt'))
    new_end = body.get('endsAt', existing_rule.get('endsAt'))
    
    if new_start and new_end:
        try:
            s = datetime.fromisoformat(new_start.replace('Z', '+00:00'))
            e = datetime.fromisoformat(new_end.replace('Z', '+00:00'))
            if e <= s:
                return {
                    "title": "Bad Request", 
                    "detail": "Validation Error: endsAt must be later than startsAt"
                }, 400
        except ValueError:
            return {"title": "Bad Request", "detail": "Invalid date format."}, 400

    # 5. Apply changes to Database
    # We use $set to only modify the fields provided in the PATCH body
    col.update_one({"ruleId": rule_id}, {"$set": body})
    
    # Return the fully updated object (excluding Mongo's internal _id)
    updated_rule = col.find_one({"ruleId": rule_id}, {"_id": 0})
    return updated_rule, 200