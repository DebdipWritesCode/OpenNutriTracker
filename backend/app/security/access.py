import hashlib
import secrets
from typing import Annotated

from fastapi import Header, Request

from app.security.rate_limit import InMemoryRateLimiter
from app.services.errors import (
    AccessTokenRequiredError,
    InvalidAccessTokenError,
    RateLimitExceededError,
    SecurityConfigurationError,
)

AuthorizationHeader = Annotated[
    str | None,
    Header(
        alias="Authorization",
        description="Application access token using the Bearer scheme.",
        include_in_schema=True,
    ),
]


def _client_identifier(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    client_ip = forwarded.split(",", 1)[0].strip() if forwarded else None
    if not client_ip and request.client:
        client_ip = request.client.host
    return client_ip or "unknown"


async def authorize_ai_request(
    request: Request,
    authorization: AuthorizationHeader = None,
) -> None:
    settings = request.app.state.settings
    configured_secret = settings.access_token

    # Local/test installs may keep authentication disabled. Production fails
    # closed so accidentally omitting the deployment secret never exposes the
    # server-side OpenAI key to the public internet.
    if configured_secret is None:
        if settings.environment == "production":
            raise SecurityConfigurationError(
                "AI access is unavailable until ONT_AI_ACCESS_TOKEN is configured"
            )
        subject = _client_identifier(request)
    else:
        if not authorization or not authorization.startswith("Bearer "):
            raise AccessTokenRequiredError("A Bearer access token is required")
        supplied = authorization.removeprefix("Bearer ").strip()
        expected = configured_secret.get_secret_value()
        if not supplied or not secrets.compare_digest(supplied, expected):
            raise InvalidAccessTokenError("The application access token is invalid")
        # Never retain the credential itself as the limiter key.
        token_fingerprint = hashlib.sha256(supplied.encode()).hexdigest()[:16]
        subject = f"{token_fingerprint}:{_client_identifier(request)}"

    limiter: InMemoryRateLimiter = request.app.state.rate_limiter
    retry_after = await limiter.check(subject)
    if retry_after is not None:
        raise RateLimitExceededError(
            "Too many AI requests; try again shortly",
            retry_after=retry_after,
        )
