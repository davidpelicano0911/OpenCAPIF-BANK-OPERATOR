from functools import wraps

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app, request

from ..core.responses import bad_request_error, unauthorized_error
from logs import util
from logs.models.interface_description import \
    InterfaceDescription  # noqa: E501
from logs.models.invocation_logs_retrieve_res import \
    InvocationLogsRetrieveRes  # noqa: E501
from logs.models.net_slice_id import NetSliceId  # noqa: E501
from logs.models.operation import Operation  # noqa: E501
from logs.models.problem_details import ProblemDetails  # noqa: E501
from logs.models.protocol import Protocol  # noqa: E501

from ..core.auditoperations import AuditOperations
from ..core.responses import bad_request_error
from ..core.validate_user import ControlAccess

audit_operations = AuditOperations()
valid_user = ControlAccess()


def cert_validation():
    def _cert_validation(f):
        @wraps(f)
        def __cert_validation(*args, **kwargs):

            request.view_args
            cert_tmp = request.headers.get('X-Ssl-Client-Cert')
            
            if not cert_tmp:
                return unauthorized_error("Client certificate required", "X-Ssl-Client-Cert header is missing")
            
            cert_raw = cert_tmp.replace('\t', '')

            cert = x509.load_pem_x509_certificate(str.encode(cert_raw), default_backend())

            cn = cert.subject.get_attributes_for_oid(x509.OID_COMMON_NAME)[0].value.strip()

            if cn != "superadmin":
                cert_signature = cert.signature.hex()
                result = valid_user.validate_user_cert(cert_signature)

                if result is not None:
                    return result

            result = f(**kwargs)
            return result
        return __cert_validation
    return _cert_validation

@cert_validation()
def api_invocation_logs_get(aef_id=None, api_invoker_id=None, time_range_start=None, time_range_end=None, api_id=None, api_name=None, api_version=None, protocol=None, operation=None, result=None, resource_name=None, src_interface=None, dest_interface=None, supported_features=None, net_slice_info=None):  # noqa: E501
    """api_invocation_logs_get

    Query and retrieve service API invocation logs stored on the CAPIF core function. # noqa: E501

    :param aef_id: String identifying the API exposing function.
    :type aef_id: str
    :param api_invoker_id: String identifying the API invoker which invoked the service API.
    :type api_invoker_id: str
    :param time_range_start: Start time of the invocation time range.
    :type time_range_start: str
    :param time_range_end: End time of the invocation time range.
    :type time_range_end: str
    :param api_id: String identifying the API invoked.
    :type api_id: str
    :param api_name: Contains the API name set to the value of the \&quot;&lt;apiName&gt;\&quot; placeholder of the API URI as defined in clause 5.2.4 of 3GPP TS 29.122 [14]. 
    :type api_name: str
    :param api_version: Version of the API which was invoked.
    :type api_version: str
    :param protocol: Protocol invoked.
    :type protocol: dict | bytes
    :param operation: Operation that was invoked on the API.
    :type operation: dict | bytes
    :param result: Result or output of the invocation.
    :type result: str
    :param resource_name: Name of the specific resource invoked.
    :type resource_name: str
    :param src_interface: Interface description of the API invoker.
    :type src_interface: dict | bytes
    :param dest_interface: Interface description of the API invoked.
    :type dest_interface: dict | bytes
    :param supported_features: To filter irrelevant responses related to unsupported features
    :type supported_features: str
    :param net_slice_info: Contains the identifier(s) of the network slice(s) within which the API shall be available. 
    :type net_slice_info: list | bytes

    :rtype: Union[InvocationLogsRetrieveRes, Tuple[InvocationLogsRetrieveRes, int], Tuple[InvocationLogsRetrieveRes, int, Dict[str, str]]
    """
    current_app.logger.debug("Audit logs")

    if aef_id is None or api_invoker_id is None:
        return bad_request_error(detail="aef_id and api_invoker_id parameters are mandatory",
                                 cause="Mandatory parameters missing", invalid_params=[
                {"param": "aef_id or api_invoker_id", "reason": "missing"}])


    time_range_start = util.deserialize_datetime(time_range_start)
    time_range_end = util.deserialize_datetime(time_range_end)
    if request.is_json:
        protocol =  Protocol.from_dict(request.get_json())  # noqa: E501
    if request.is_json:
        operation =  Operation.from_dict(request.get_json())  # noqa: E501
    if request.is_json:
        src_interface =  InterfaceDescription.from_dict(request.get_json())  # noqa: E501
    if request.is_json:
        dest_interface =  InterfaceDescription.from_dict(request.get_json())  # noqa: E501
    if request.is_json:
        net_slice_info = [NetSliceId.from_dict(d) for d in request.get_json()]  # noqa: E501
   
    query_params = {"aef_id": aef_id,
                    "api_invoker_id": api_invoker_id,
                    "time_range_start": time_range_start,
                    "time_range_end": time_range_end,
                    "api_id": api_id,
                    "api_name": api_name,
                    "api_version": api_version,
                    "protocol": protocol,
                    "operation": operation,
                    "result": result,
                    "resource_name": resource_name,
                    "src_interface": src_interface,
                    "dest_interface": dest_interface,
                    "supported_features": supported_features
                    }

    response = audit_operations.get_logs(query_params)
    return response
