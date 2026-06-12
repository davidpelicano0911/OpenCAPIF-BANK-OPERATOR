def info_from_o_auth2_client_credentials(token):
    """Compatibility hook for OpenAPI security schemes.

    Authentication enforcement is performed with flask_jwt_extended decorators.
    """
    return {"scopes": [], "uid": token}


def validate_scope_o_auth2_client_credentials(required_scopes, token_scopes):
    """Compatibility hook for OpenAPI security schemes."""
    return set(required_scopes).issubset(set(token_scopes))
