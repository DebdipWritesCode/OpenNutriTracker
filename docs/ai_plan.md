# AI Nutrition Tracker
> OpenNutriTracker + AI Layer

## Goal

Build an AI-powered nutrition tracker on top of OpenNutriTracker.

Primary goals:
- AI meal logging (text + image)
- Accurate calorie & macro estimation
- Indian food support
- Personalized serving estimation
- Privacy-first
- Self-hosted backend
- Bring Your Own OpenAI API Key

---

# Tech Stack

## Frontend
- Flutter (OpenNutriTracker)

## Backend
- FastAPI

## Database
Initially:
- SQLite

Future:
- PostgreSQL

## AI

Primary:
- GPT-5.4-mini

Fallback:
- GPT-5.4

## Nutrition Sources

- USDA FoodData Central
- Open Food Facts
- Indian Food Composition Tables (IFCT)

---

# Overall Architecture

                    Flutter App
                          │
                    HTTPS REST API
                          │
                    FastAPI Backend
                          │
      ┌───────────────────┼────────────────────┐
      │                   │                    │
      ▼                   ▼                    ▼
 OpenAI Models      Nutrition Engine      User Database
      │                   │                    │
      │             USDA / OFF / IFCT         │
      └───────────────────┼────────────────────┘
                          │
                   Structured JSON

---

# Milestone 1
## Understand Existing Project

Goal:
Become familiar with OpenNutriTracker.

Tasks

- [x] Build project
- [ ] Run Android app
- [x] Explore project structure
- [x] Understand navigation
- [x] Understand local database
- [x] Understand food logging flow
- [x] Understand calorie calculations
- [x] Understand state management
- [x] Understand recipe system

Deliverable

Can confidently modify existing features.

---

# Milestone 2
## Backend Setup

Create FastAPI backend.

Structure

backend/
    app/
        routers/
        services/
        models/
        schemas/
        prompts/
        database/
        utils/

Tasks

- [x] FastAPI project
- [x] Docker
- [x] Environment variables
- [x] OpenAI SDK
- [x] Health endpoint
- [x] Logging
- [x] CORS
- [x] API documentation

Deliverable

Running backend.

---

# Milestone 3
## Flutter ↔ Backend Communication

Tasks

- [x] HTTP Client
- [x] API abstraction
- [x] Error handling
- [x] Loading UI
- [x] Retry logic

Deliverable

Flutter can communicate with backend.

---

# Milestone 4
## Text Meal Logging

Example

"I ate

190g rice
100g chicken
200g curd"

Pipeline

Flutter

↓

FastAPI

↓

GPT

↓

JSON

↓

Flutter

Tasks

- [x] Prompt design
- [x] Structured outputs
- [x] Validation
- [x] Display preview
- [x] Edit before save

Deliverable

Natural language logging.

---

# Milestone 5
## Image Recognition

Pipeline

Image

↓

GPT Vision

↓

Detected Foods

↓

Estimated Portions

↓

Nutrition Engine

↓

Calories

Tasks

- [ ] Image upload
- [ ] Vision prompt
- [ ] JSON parsing
- [ ] Confidence scores
- [ ] Manual corrections
- [ ] Save meal

Deliverable

Photo → Meal.

---

# Milestone 6
## Nutrition Engine

Purpose

Never ask the LLM to calculate calories.

Instead

Food
↓

Nutrition Database

↓

Calories

Tasks

- [x] USDA integration
- [x] OpenFoodFacts integration
- [ ] IFCT integration
- [ ] Unit conversion
- [x] Portion conversion
- [x] Macro calculation

Deliverable

Reliable nutrition.

---

# Milestone 7
## Indian Food Support

Tasks

- [ ] Common Indian dishes
- [ ] Homemade meals
- [ ] Curry estimation
- [ ] Rice estimation
- [ ] Chapati estimation
- [ ] Dal estimation

Deliverable

Good Indian accuracy.

---

# Milestone 8
## User Portion Memory

Idea

User edits

Rice

180g

↓

Actually

200g

↓

Store correction

Next time

Predict

200g

Tasks

- [ ] Portion history
- [ ] Plate history
- [ ] User preferences
- [ ] Serving estimation

Deliverable

Personalized estimates.

---

# Milestone 9
## AI Assistant

Examples

"How much protein left today?"

"What should I eat?"

"Can I fit dessert?"

Tasks

- [ ] Daily summaries
- [ ] Remaining calories
- [ ] Protein tracking
- [ ] Suggestions
- [ ] Weekly reports

Deliverable

Nutrition assistant.

---

# Milestone 10
## Barcode Scanner

Tasks

- [ ] Barcode camera
- [ ] OpenFoodFacts lookup
- [ ] Autofill macros

Deliverable

Packaged food support.

---

# Milestone 11
## Analytics

Tasks

- [ ] Weekly calories
- [ ] Protein average
- [ ] Weight trends
- [ ] AI insights

Deliverable

Advanced dashboard.

---

# Future Features

## Voice Logging

"I had two eggs and a protein shake."

---

## Meal Planning

Generate meals for remaining macros.

---

## Grocery Suggestions

Suggest groceries based on meal plan.

---

## Restaurant Estimation

Estimate calories from restaurant meals.

---

## OCR

Read nutrition labels.

---

## Multiple Images

Breakfast

Lunch

Dinner

Daily analysis.

---

# Backend Endpoints

GET

/health

POST

/analyze/text

POST

/analyze/image

POST

/analyze/barcode

POST

/chat

GET

/foods/search

POST

/meal/save

GET

/meals

GET

/summary/daily

GET

/summary/weekly

---

# AI Prompt Strategy

Vision

Return ONLY JSON.

Never estimate calories.

Only identify

- foods
- estimated grams
- confidence

Text

Extract foods.

Normalize units.

Return JSON.

Chat

Nutrition coach.

Never hallucinate macros.

Always use backend calculations.

---

# Definition of Done

✅ One photo logs an entire meal.

✅ User can edit estimates.

✅ Calories are database-backed.

✅ Indian meals work well.

✅ Personalized serving estimates improve over time.

✅ Runs entirely on self-hosted backend.

✅ Uses user's own OpenAI API key.
  
  
