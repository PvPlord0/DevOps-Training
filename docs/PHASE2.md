# Phase 2 — Containerize it, run it by hand

**Goal**: package every service as a container using Podman, and
orchestrate the whole system yourself with plain `podman` commands —
no Compose yet, that's next phase.

## Tasks

- Write a `Containerfile` in each `services/<name>/` folder (multi-stage
  where it matters — the frontend and the Java service especially).
  The `analytics-service-python` folder has two entrypoints (`app/main.py`,
  the API, and `job.py`, the background job) — one image should support
  running either, via the container's start command.
- Write `infra/scripts/run-all.sh`: a bash script that, run top to bottom on
  a clean machine using proper podman commands you learnt , does all of the following:
  1. Creates a dedicated Podman network (`podman network create
     eventhub-net`) so containers can resolve each other by name.
  2. Starts MySQL, PostgreSQL, MongoDB, Redis, and RabbitMQ as containers on
     that network, each with a fixed `--name` and a persistent volume.
  3. Builds each service's image from its `Containerfile`.
  4. Runs each service container on the same network, passing config in via
     `-e` flags or `--env-file`, pointing at the *container names* of its
     dependencies (e.g. the auth service's `PGHOST` should be the Postgres
     container's name, not `localhost`).
  5. Waits for each dependency to actually be ready before starting
     whatever depends on it — a fixed `sleep` is not acceptable; poll a
     health check or the port instead.
  6. Runs the analytics job once at the end (`podman run --rm
     <analytics-image> python job.py`) so the dashboard has real data by
     the time the script finishes.
- Externalize all config/secrets — nothing hardcoded in an image.
- Add a health check to each long-running container. (The analytics job
  container is not long-running, so it doesn't need one — think about why
  that distinction matters, you'll need it again in phase 4.)

## Deliverables

1. `Containerfile` in each `services/<name>/` folder.
2. `infra/scripts/run-all.sh`, runnable end-to-end.
3. Proof the full user journey from phase 1 still works, now fully
   containerized and orchestrated by hand -- including the dashboard
   showing real data after `run-all.sh` completes.
4. A short note on any issues you faced and how you solved
   them (add to `infra/scripts/NOTES.md`).

5. Each team memeber to setup the environment on his/her machine recording the professional video demostrating the phase work
submit the video here https://forms.gle/QXK3rN2nux771QNWA 

6. DO NOT USE DOCKER COMPOSE
