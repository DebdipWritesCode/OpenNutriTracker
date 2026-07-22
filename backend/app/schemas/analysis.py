from typing import Annotated

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
)

MealText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=2, max_length=4000)]


class AnalyzeTextRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: MealText
    locale: str = Field(default="en", min_length=2, max_length=20)


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


class AnalyzeTextResponse(MealExtraction):
    model_used: str
