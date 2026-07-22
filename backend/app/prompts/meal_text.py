def build_meal_text_prompt(locale: str) -> str:
    return f"""
You extract foods and portions from a user's meal description.

Rules:
- Identify every distinct food or drink mentioned.
- Preserve the user's words in original_text and provide a concise canonical_name.
- Normalize an explicit amount into quantity and unit.
- Set estimated_grams when the user gives grams or when a conventional household portion can be
  reasonably converted. Otherwise leave it null and require confirmation.
- Treat Indian dishes and household units (katori, roti, chapati, bowl, glass, piece) as first-class
  foods/units. Do not replace them with unrelated Western foods.
- Confidence is 0 to 1. Mark ambiguous foods or portions as requiring user confirmation.
- Never calculate or return calories, energy, protein, carbohydrates, fat, or micronutrients.
- Do not invent ingredients for a composite dish. Preparation may describe only what the user
  states.
- The user's locale hint is {locale!r}. Food names can remain in the user's language.
- Add short notes only when they help the user correct an ambiguity.
""".strip()
