import json

from flask import Response

from ..encoder import CustomJSONEncoder
from ..models.problem_details import ProblemDetails
from ..util import serialize_clean_camel_case

mimetype = "application/json"


def make_response(object, status):
    res = Response(json.dumps(object,  cls=CustomJSONEncoder), status=status, mimetype=mimetype)

    return res


def internal_server_error(detail, cause):
    prob = ProblemDetails(title="Internal Server Error", status=500, detail=detail, cause=cause)
    prob = serialize_clean_camel_case(prob)

    return Response(json.dumps(prob, cls=CustomJSONEncoder), status=500, mimetype=mimetype)


def forbidden_error(detail, cause):
    prob = ProblemDetails(title="Forbidden", status=403, detail=detail, cause=cause)
    prob = serialize_clean_camel_case(prob)

    return Response(json.dumps(prob, cls=CustomJSONEncoder), status=403, mimetype=mimetype)


def bad_request_error(detail, cause, invalid_params):
    prob = ProblemDetails(title="Bad Request", status=400, detail=detail, cause=cause, invalid_params=invalid_params)
    prob = serialize_clean_camel_case(prob)

    return Response(json.dumps(prob, cls=CustomJSONEncoder), status=400, mimetype=mimetype)


def not_found_error(detail, cause):
    prob = ProblemDetails(title="Not Found", status=404, detail=detail, cause=cause)
    prob = serialize_clean_camel_case(prob)

    return Response(json.dumps(prob, cls=CustomJSONEncoder), status=404, mimetype=mimetype)


def unauthorized_error(detail, cause):
    prob = ProblemDetails(title="Unauthorized", status=401, detail=detail, cause=cause)
    prob = serialize_clean_camel_case(prob)

    return Response(json.dumps(prob, cls=CustomJSONEncoder), status=401, mimetype=mimetype)