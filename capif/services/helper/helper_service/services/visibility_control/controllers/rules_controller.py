import connexion
from typing import Dict, Tuple, Union

#from ..auth import cert_validation

from visibility_control.auth import cert_validation

# Importamos la lógica del CORE 
from ..core.visibility_control_core import (
    get_all_rules, 
    create_new_rule, 
    get_rule_by_id, 
    delete_rule_by_id, 
    update_rule_patch
)

from visibility_control.models.error import Error
from visibility_control.models.rule import Rule
from visibility_control.models.rule_create_request import RuleCreateRequest
from visibility_control.models.rule_patch_request import RulePatchRequest
from visibility_control.models.rules_get200_response import RulesGet200Response
from visibility_control import util

@cert_validation()
def rules_get():
    """List rules"""
    return get_all_rules()

@cert_validation()
def rules_post(body): 
    """
    Create a rule
    """
    if body is not None:
        return create_new_rule(body)
    if connexion.request.is_json:
        body = connexion.request.get_json()
        return create_new_rule(body)
        
    return Error(title="Bad Request", detail="JSON body required", status=400), 400

@cert_validation()
def rules_rule_id_delete(rule_id):
    """Delete a rule"""
    return delete_rule_by_id(rule_id)

@cert_validation()
def rules_rule_id_get(rule_id):
    """Get a rule"""
    return get_rule_by_id(rule_id)

@cert_validation()
def rules_rule_id_patch(rule_id, body):
    """Update a rule (partial)"""
    if connexion.request.is_json:
        body = connexion.request.get_json()
        return update_rule_patch(rule_id, body)
    return Error(title="Bad Request", detail="JSON body required", status=400), 400