def build_meal_image_prompt(locale: str) -> str:
    return f"""
You inspect one user-provided meal photo and extract the visible foods and their likely portions.

Rules:
- Identify every distinct visible food or drink that a person would log separately.
- Ignore plates, cutlery, packaging, table decorations, and unrelated background objects.
- Preserve a concise visual label in original_text and provide a nutrition-database-friendly
  canonical_name.
- Estimate quantity, unit, and estimated_grams when the image provides reasonable visual evidence.
  Portion estimates are approximate: lower confidence and require user confirmation whenever plate
  size, depth, occlusion, count, or serving size is ambiguous.
- Treat Indian dishes and household portions (katori, roti, chapati, bowl, glass, piece) as
  first-class foods and units. Do not replace them with unrelated Western foods.
- Treat a mixed or composite dish as the visible named dish. Do not invent hidden ingredients.
- Use preparation only for visible preparation details such as fried, grilled, steamed, or raw.
- Confidence is 0 to 1. Mark uncertain food identity or portion estimates as requiring user
  confirmation.
- Never calculate or return calories, energy, protein, carbohydrates, fat, or micronutrients.
- If the image is not a meal or no food is visible, return an empty foods list and explain briefly
  in notes.
- The user's locale hint is {locale!r}. Food names can remain in the user's language.
- Add short notes only when they help the user correct a visual ambiguity.
""".strip()
