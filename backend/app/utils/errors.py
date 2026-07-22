import logging

from fastapi import Request, status
from fastapi.responses import JSONResponse

from app.schemas.error import ErrorDetail, ErrorResponse
from app.services.errors import (
    InvalidAPIKeyError,
    MissingAPIKeyError,
    ModelResponseError,
    ServiceError,
    UpstreamUnavailableError,
)

logger = logging.getLogger(__name__)


def _status_for(error: ServiceError) -> int:
    if isinstance(error, (MissingAPIKeyError, InvalidAPIKeyError)):
        return status.HTTP_401_UNAUTHORIZED
    if isinstance(error, (ModelResponseError, UpstreamUnavailableError)):
        return status.HTTP_502_BAD_GATEWAY
    return status.HTTP_500_INTERNAL_SERVER_ERROR


async def service_error_handler(request: Request, error: ServiceError) -> JSONResponse:
    status_code = _status_for(error)
    request_id = getattr(request.state, "request_id", None)
    if status_code >= 500:
        logger.error(
            "Service request failed",
            extra={"error_code": error.code, "request_id": request_id},
        )
    body = ErrorResponse(
        error=ErrorDetail(code=error.code, message=str(error), request_id=request_id)
    )
    return JSONResponse(status_code=status_code, content=body.model_dump(exclude_none=True))
