
from api_invoker_management.models.api_invoker_enrolment_details import \
    APIInvokerEnrolmentDetails  # noqa: E501
from api_invoker_management.models.problem_details import \
    ProblemDetails  # noqa: E501
from flask import current_app, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..core.apiinvokerenrolmentdetails import InvokerManagementOperations

invoker_operations = InvokerManagementOperations()

@jwt_required()
def create_onboarded_api_invoker(body):  # noqa: E501
    """Request the Creation of a new On-boarded API Invoker.

     # noqa: E501

    :param api_invoker_enrolment_details: 
    :type api_invoker_enrolment_details: dict | bytes

    :rtype: Union[APIInvokerEnrolmentDetails, Tuple[APIInvokerEnrolmentDetails, int], Tuple[APIInvokerEnrolmentDetails, int, Dict[str, str]]
    """
    identity = get_jwt_identity()
    username, uuid = identity.split()

    current_app.logger.debug("Creating Invoker")
    if request.is_json:
        body = APIInvokerEnrolmentDetails.from_dict(request.get_json())  # noqa: E501

    res = invoker_operations.add_apiinvokerenrolmentdetail(body, username, uuid)

    return res
