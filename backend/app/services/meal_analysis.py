import logging
from dataclasses import dataclass

from openai import (
    APIConnectionError,
    APIStatusError,
    APITimeoutError,
    AsyncOpenAI,
    AuthenticationError,
    NotFoundError,
    RateLimitError,
)

from app.config import Settings
from app.prompts import build_meal_text_prompt
from app.schemas.analysis import AnalyzeTextRequest, MealExtraction
from app.services.errors import (
    InvalidAPIKeyError,
    MissingAPIKeyError,
    ModelResponseError,
    UpstreamUnavailableError,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class MealAnalysisResult:
    extraction: MealExtraction
    model_used: str


class MealAnalysisService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def analyze_text(
        self,
        request: AnalyzeTextRequest,
        request_api_key: str | None,
    ) -> MealAnalysisResult:
        api_key = self._resolve_api_key(request_api_key)
        client = AsyncOpenAI(
            api_key=api_key,
            timeout=self.settings.openai_timeout_seconds,
            max_retries=0,
        )
        models = list(
            dict.fromkeys(
                [
                    self.settings.openai_primary_model,
                    self.settings.openai_fallback_model,
                ]
            )
        )
        last_error: Exception | None = None

        try:
            for index, model in enumerate(models):
                try:
                    response = await client.responses.parse(
                        model=model,
                        instructions=build_meal_text_prompt(request.locale),
                        input=request.text,
                        text_format=MealExtraction,
                        reasoning={"effort": "none"},
                        max_output_tokens=self.settings.openai_max_output_tokens,
                        store=False,
                    )
                    if response.output_parsed is None:
                        raise ModelResponseError("The model did not return a meal extraction")
                    return MealAnalysisResult(response.output_parsed, model)
                except AuthenticationError as exc:
                    raise InvalidAPIKeyError("The provided OpenAI API key was rejected") from exc
                except (NotFoundError, RateLimitError, APITimeoutError, APIConnectionError) as exc:
                    last_error = exc
                    if index < len(models) - 1:
                        logger.warning(
                            "Meal extraction model failed; attempting configured fallback",
                            extra={"model": model, "error_type": type(exc).__name__},
                        )
                        continue
                    break
                except APIStatusError as exc:
                    last_error = exc
                    if exc.status_code >= 500 and index < len(models) - 1:
                        logger.warning(
                            "Meal extraction upstream failed; attempting configured fallback",
                            extra={"model": model, "status_code": exc.status_code},
                        )
                        continue
                    break
        finally:
            await client.close()

        if isinstance(last_error, ModelResponseError):
            raise last_error
        raise UpstreamUnavailableError(
            "OpenAI meal extraction is temporarily unavailable"
        ) from last_error

    def _resolve_api_key(self, request_api_key: str | None) -> str:
        if request_api_key and request_api_key.strip():
            return request_api_key.strip()
        if self.settings.openai_api_key is not None:
            return self.settings.openai_api_key.get_secret_value()
        raise MissingAPIKeyError(
            "Provide X-OpenAI-API-Key or configure ONT_AI_OPENAI_API_KEY on the server"
        )
