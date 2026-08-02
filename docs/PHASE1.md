# Phase 1 — Make it run

**Goal**: understand the system by getting it fully working on your own
machines.

## Tasks

- Install each service's runtime and dependencies (see each service's
  README).
- Set up local instances of MySQL, PostgreSQL, MongoDB, and Redis.
- Configure every service's `.env` from its `.env.example`.
- Get the full user journey working:
  register/login -> browse catalog -> book an event -> notification worker
  logs the async event -> submit a review -> AI Insight returns a
  sentiment result.
- Run the analytics job (`services/analytics-service-python/job.py`) and
  confirm the dashboard tab in the frontend shows real data: a bookings-
  over-time chart, a review-sentiment breakdown chart, and a sortable,
  filterable table of events with their booking/revenue/sentiment stats.
- Find and fix the deliberately broken thing(s) in this repo.

## Deliverables

1. A video demo [done by every team member on her or his machine] of the full journey working end-to-end, including the dashboard
   showing data generated from bookings and reviews you actually created.
2. `PHASE1_NOTES.md` in your team's copy of this repo, listing every bug you
   found, where it was, and how you fixed it.
3. All services runnable independently, each with a one-line start command.

4. Create GitHub repo per team , make it private add TAs:e.salem@fci-cu.edu.eg  and marwa.ahmed@fci-cu.edu.eg

5. Drawing architecture diagram for the whole project add it to the project on GitHub

6. Send phase 1 video link and architecture diagram link via : https://forms.gle/17NbUmgJdErR5j9V7

## Exit criteria

Every service starts cleanly from its documented command, the full user
journey completes without manual workarounds, the dashboard reflects real
data after running the analytics job, and your notes file accurately
reflects what you actually found and fixed.

## Grading (this phase)

| Area | Weight |
|---|---|
| All services run correctly, no undocumented manual steps | 35% |
| Dashboard shows real, correct data after running the analytics job | 15% |
| Bugs found are real, fixes are correct (not symptom-masking) | 25% |
| Demonstrated understanding of why each service exists | 15% |
| Quality of `PHASE1_NOTES.md` | 10% |

This project has further phases. Instructions, requirements, and grading
for each subsequent phase will be provided once your team's phase 1 work
is reviewed.
