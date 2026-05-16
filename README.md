# medical_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Recent Full-Stack Updates

- Added course metadata support across backend/admin/mobile:
  - New `courses.instructor_name` (default: `Umidjon Mukarramov`)
  - New `courses.cover_image_url`
  - Mobile/admin/backend now read/write these fields with backward-compatible fallbacks.
- Added new Supabase migration:
  - `backend/supabase/migrations/017_courses_cover_instructor_and_pomodoro.sql`
  - Includes course columns, `pomodoro_sessions` table/index/RLS, daily leaderboard view, and `course-covers` storage bucket policies.
  - `backend/supabase/migrations/018_home_performance_indexes.sql`
  - Adds `course_banners.sort_order` and home-read indexes for faster active banners/courses listing.
- Added new backend endpoints:
  - `GET /api/v1/leaderboard/pomodoro/daily`
  - `POST /api/v1/leaderboard/pomodoro/session`
- Improved client UX:
  - Course card title cleanup (`talaba` suffix removal), larger title typography, cover image usage.
  - Course detail hero now shows real cover image with loading/error fallback.
  - Slide overlay auto-hides after 1 second and reappears briefly on navigation.
  - Course/comment stats now include unique commenters count.
  - Ranking page now includes a dedicated `Pomodoro` tab with daily backend data.
  - Home data loading tuned: in-flight request dedupe + short TTL cache for slides/banners/catalog, plus immediate skeleton sections.
