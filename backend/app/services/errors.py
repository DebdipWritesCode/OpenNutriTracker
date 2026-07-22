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


class AccessTokenRequiredError(ServiceError):
    code = "access_token_required"


class InvalidAccessTokenError(ServiceError):
    code = "invalid_access_token"


class SecurityConfigurationError(ServiceError):
    code = "security_not_configured"


class RateLimitExceededError(ServiceError):
    code = "rate_limit_exceeded"

    def __init__(self, message: str, *, retry_after: int) -> None:
        super().__init__(message)
        self.retry_after = retry_after
