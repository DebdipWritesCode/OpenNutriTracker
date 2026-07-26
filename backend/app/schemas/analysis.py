import base64
import binascii
from typing import Annotated, Literal, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

MealText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=2, max_length=4000)]
MealCorrectionText = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=2, max_length=1000),
]
ImageMimeType = Literal["image/jpeg", "image/png", "image/webp"]
MAX_IMAGE_BYTES = 3_000_000
MAX_IMAGE_BASE64_LENGTH = 4_000_000


class AnalyzeTextRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: MealText
    locale: str = Field(default="en", min_length=2, max_length=20)


class AnalyzeImageRequest(BaseModel):
    """A short-lived image payload used only for a single vision request."""

    model_config = ConfigDict(extra="forbid")

    image_base64: str = Field(min_length=4, max_length=MAX_IMAGE_BASE64_LENGTH)
    mime_type: ImageMimeType
    locale: str = Field(default="en", min_length=2, max_length=20)

    @field_validator("image_base64")
    @classmethod
    def validate_image_payload(cls, value: str) -> str:
        try:
            decoded = base64.b64decode(value, validate=True)
        except (ValueError, binascii.Error) as exc:
            raise ValueError("image_base64 must be valid Base64") from exc
        if not decoded:
            raise ValueError("The meal photo is empty")
        if len(decoded) > MAX_IMAGE_BYTES:
            raise ValueError("The meal photo must be 3 MB or smaller")
        return value

    @model_validator(mode="after")
    def validate_image_signature(self) -> Self:
        self.decoded_image()
        return self

    def decoded_image(self) -> bytes:
        decoded = base64.b64decode(self.image_base64, validate=True)
        valid_signature = {
            "image/jpeg": decoded.startswith(b"\xff\xd8\xff"),
            "image/png": decoded.startswith(b"\x89PNG\r\n\x1a\n"),
            "image/webp": decoded.startswith(b"RIFF")
            and len(decoded) >= 12
            and decoded[8:12] == b"WEBP",
        }[self.mime_type]
        if not valid_signature:
            raise ValueError("The meal photo does not match its declared image type")
        return decoded


class ExtractedFood(BaseModel):
    """A food mention extracted by the model; never model-calculated nutrition."""

    model_config = ConfigDict(extra="forbid")

    original_text: str = Field(min_length=1, max_length=300)
    canonical_name: str = Field(min_length=1, max_length=200)
    quantity: float | None = Field(default=None, gt=0, le=10000)
    unit: str | None = Field(default=None, max_length=50)
    estimated_grams: float | None = Field(default=None, gt=0, le=10000)
    preparation: str | None = Field(default=None, max_length=200)
    confidence: float = Field(ge=0, le=1)
    requires_user_confirmation: bool = False

    @field_validator("canonical_name", "original_text", "preparation", "unit", mode="before")
    @classmethod
    def strip_text_fields(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class MealExtraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    foods: list[ExtractedFood] = Field(default_factory=list, max_length=50)
    notes: list[str] = Field(default_factory=list, max_length=20)


class MealCorrectionTurn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    instruction: MealCorrectionText
    assistant_message: str = Field(min_length=1, max_length=300)


class RefineImageRequest(AnalyzeImageRequest):
    """A stateless correction request that re-sends the photo and current draft."""

    correction: MealCorrectionText
    current_foods: list[ExtractedFood] = Field(min_length=1, max_length=50)
    correction_history: list[MealCorrectionTurn] = Field(
        default_factory=list,
        max_length=10,
    )


class MealRefinement(MealExtraction):
    assistant_message: str = Field(min_length=1, max_length=300)


class AnalyzeTextResponse(MealExtraction):
    model_used: str


class RefineImageResponse(MealRefinement):
    model_used: str
