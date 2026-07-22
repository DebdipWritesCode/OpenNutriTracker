from typing import Any

from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str
    request_id: str | None = None
    context: dict[str, Any] | None = None


class ErrorResponse(BaseModel):
    error: ErrorDetail
