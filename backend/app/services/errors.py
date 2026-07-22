class ServiceError(Exception):
    code = "service_error"


class MissingAPIKeyError(ServiceError):
    code = "missing_api_key"


class InvalidAPIKeyError(ServiceError):
    code = "invalid_api_key"


class ModelResponseError(ServiceError):
    code = "invalid_model_response"


class UpstreamUnavailableError(ServiceError):
    code = "upstream_unavailable"
