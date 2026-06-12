import json

from flask import Response

from ..encoder import CustomJSONEncoder
from ..models.problem_details import ProblemDetails
from ..util import serialize_clean_camel_case

mimetype = "application/json"


def make_response(obj, status):
    return Response(json.dumps(obj, cls=CustomJSONEncoder), status=status, mimetype=mimetype)


def internal_server_error(detail, cause):
    prob = ProblemDetails(title="Internal Server Error", status=500, detail=detail, cause=cause)
    return make_response(serialize_clean_camel_case(prob), 500)


def bad_request_error(detail, cause, invalid_params):
    prob = ProblemDetails(
        title="Bad Request",
        status=400,
        detail=detail,
        cause=cause,
        invalid_params=invalid_params,
    )
    return make_response(serialize_clean_camel_case(prob), 400)


def not_found_error(detail, cause):
    prob = ProblemDetails(title="Not Found", status=404, detail=detail, cause=cause)
    return make_response(serialize_clean_camel_case(prob), 404)
