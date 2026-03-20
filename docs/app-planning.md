---
name: DinnerPlanner app
overview: Build a Flutter iOS+Android dinner planner that imports online recipes via Share Sheet, organizes weekly meals, supports editable ingredients, and computes/caches nutrition facts using Supabase (Auth + Postgres + Storage) plus a small recipe-import service.
todos:
  - id: supabase-schema
    content: Define Postgres tables, indexes, and RLS policies for recipes, ingredients, steps, meal plans, and nutrition cache.
    status: pending
  - id: flutter-auth-bootstrap
    content: Add Supabase Auth to Flutter app and create sign-in/sign-up flow.
    status: pending
  - id: recipes-planner-crud
    content: Implement recipes CRUD + weekly planner CRUD against Supabase.
    status: pending
  - id: share-import-flow
    content: Implement Share Sheet URL intake and import preview/save flow.
    status: pending
  - id: recipe-import-service
    content: Create a small recipe-import HTTP service that extracts schema.org JSON-LD (fallback scraper) and returns normalized recipe JSON.
    status: pending
  - id: nutrition-integration
    content: Integrate nutrition computation, ingredient matching, caching, and invalidation when ingredients are edited.
    status: pending
isProject: false
---

# DinnerPlanner (Flutter + Supabase) Implementation Plan

## Target architecture

- **Mobile app (Flutter)**
  - Auth (Supabase)
  - Recipe browsing/search (optional later)
  - **Recipe import via Share Sheet** (URL shared from browser)
  - Meal/recipe editor (ingredients + steps editable)
  - Weekly meal planner (calendar/week grid)
  - Nutrition view per recipe + per serving
  - Offline-friendly caching (local DB) for recent recipes/weeks
- **Backend**
  - **Supabase**: Auth + Postgres (core data) + Storage (images)
  - **Recipe Import service** (small HTTP service you host): given a URL, returns normalized recipe fields
    - Parse **schema.org Recipe JSON-LD** first; fallback to a scraper
    - Save the normalized recipe to Supabase
  - **Nutrition**
    - Normalize ingredients -> nutrition-items via a nutrition data source
    - Cache computed nutrition per recipe (and invalidate when ingredients change)

```mermaid
flowchart LR
  Browser[BrowserRecipePage] -->|ShareURL| App[FlutterApp]
  App -->|POST /import {url}| ImportSvc[RecipeImportService]
  ImportSvc -->|Extract title,ingredients,steps,image| App
  App -->|Upsert recipe + ingredients| Supabase[(Supabase Postgres)]
  App -->|Upload image| Storage[Supabase Storage]
  App -->|Request nutrition calc| NutritionSvc[NutritionCompute]
  NutritionSvc -->|Cache results| Supabase
  App --> Planner[WeeklyMealPlanner]
  Planner --> Supabase
```



## Data model (Supabase Postgres)

- `profiles` (user)
- `recipes`
  - `id`, `user_id`, `title`, `source_url`, `image_path`, `servings`, `created_at`, `updated_at`
- `recipe_steps`
  - `id`, `recipe_id`, `step_index`, `text`
- `recipe_ingredients`
  - `id`, `recipe_id`, `name_raw`, `quantity`, `unit`, `notes`, `sort_index`
  - optional: `food_match_id` for nutrition mapping
- `meal_plans`
  - `id`, `user_id`, `week_start_date`
- `meal_plan_entries`
  - `id`, `meal_plan_id`, `date`, `meal_slot` (breakfast/lunch/dinner/snack), `recipe_id`
- `recipe_nutrition_cache`
  - `recipe_id`, `per_serving_json`, `total_json`, `computed_at`, `ingredients_hash`

Security

- **RLS** everywhere by `auth.uid()`.
- Storage bucket policies scoped to user.

## App UX scope (MVP screens)

- Auth (sign in/up)
- Home (this week)
- Planner (week grid; tap slot -> pick recipe)
- Recipes list
- Recipe detail (steps, ingredients, nutrition)
- Recipe edit (edit ingredients/steps; re-compute nutrition)
- Import flow (handles URL share; shows preview then save)

## Recipe import (Share Sheet)

- Flutter integration using platform share-intent plugins:
  - Android: receive shared `text/plain` URL intent
  - iOS: share extension / URL handoff (plugin-dependent)
- App calls `RecipeImportService` to extract:
  - title, image, servings (if present), ingredients, steps
- If extraction fails: fall back to “semi-manual” import with pre-filled fields.

## Nutrition computation

- Choose a nutrition data provider/library (depends on what you mean by “super base”):
  - Map each ingredient line to a canonical food item + quantity
  - Compute totals and per-serving
  - Cache results keyed by a stable `ingredients_hash`

## Milestones

- **Milestone 1**: Supabase project setup, schema, RLS, Auth in app
- **Milestone 2**: Recipes CRUD (manual create/edit) + planner CRUD
- **Milestone 3**: Share Sheet URL import + import preview/save
- **Milestone 4**: Nutrition provider integration + caching + invalidation
- **Milestone 5**: Polish (images, offline cache, search, onboarding)

## Key files/modules (expected)

- Flutter app
  - `lib/main.dart` (bootstrap)
  - `lib/features/auth/`*
  - `lib/features/recipes/*` (model, repo, UI)
  - `lib/features/planner/*`
  - `lib/features/import/*` (share intent + import flow)
  - `lib/services/supabase_client.dart`
- Import service (new)
  - `import_service/` (HTTP endpoint `/import`)

## Assumptions (locked for this plan)

- You want **iOS + Android**, so Flutter is the best default.
- You want **Share Sheet URL import** on day 1.
- Supabase is the system of record for user data.

