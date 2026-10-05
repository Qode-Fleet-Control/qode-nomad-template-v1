# Nomad template

Provisioned from [`Qode-Fleet-Control/fleet-template-v1`](https://github.com/Qode-Fleet-Control/fleet-template-v1) — the fleet
lifecycle contract (`bin/`, `fleet.conf`, `compose.yaml`, deploy workflows) with a set of [Nomad](https://developer.hashicorp.com/nomad) job specifications
laid on top.

**This repo is a job, not a service.** Its container checks the job specs — `nomad fmt
-check`, then `nomad job validate` and `nomad job plan` (a scheduler dry-run) for each one
against a throwaway `nomad agent -dev` it starts inside the container on 127.0.0.1 — and
exits 0 when all of it passes. Nothing is published and nothing listens on `$PORT`.

## What is in it

| file | |
|---|---|
| `jobs/web.nomad.hcl` | a `service` job: N docker tasks behind a dynamic port, Nomad-native service registration + HTTP check, canary rolling updates with auto-revert, restart policy, `shutdown_delay` |
| `jobs/cleanup.nomad.hcl` | a periodic `batch` job (nightly cron, no overlap) |
| `scripts/check.sh` | the job: `nomad fmt -check -recursive jobs`, dev agent up, `job validate` + `job plan` per spec, agent down |

Both specs use HCL2 `variable` blocks — override with `-var` / `-var-file` at run time:

    nomad job run -var="image=nginx:1.29-alpine" -var="count=3" jobs/web.nomad.hcl

## Run it

**On the fleet:** `bin/run` builds the image (`docker compose build`) and stops there —
`DOCKER_START_CMD` is empty because there is no server. Run the job with
`docker compose run --rm app`.

**With docker:**

    docker compose build
    docker compose run --rm app        # exit 0 = fmt, validate and plan passed for every spec

**Without docker** (needs `nomad` >= 1.5 on `PATH`):

    sh scripts/check.sh                # starts/stops its own dev agent on 127.0.0.1:${NOMAD_DEV_PORT:-4646}
    NOMAD_ADDR=http://your-cluster:4646 nomad job run jobs/web.nomad.hcl

`FLEET_RUNTIME=process bin/run` runs `BUILD_CMD` (`nomad fmt -check`) and then stops at the
start step, by design.

## Origin

    hand-written — Nomad ships `nomad job init`, but it writes a single example.nomad.hcl
    demo (a redis task); these specs follow the job-specification docs instead

## Deviations, and why

- `Dockerfile` is a job image on `hashicorp/nomad:2.0.7`: its `ENTRYPOINT` is cleared and the
  default command is `scripts/check.sh`. Runs as non-root `app` (uid 10001).
- The check uses a dev agent rather than plain offline `nomad job validate`: offline
  validation skips the server-side checks, and `nomad job plan` needs a scheduler. The
  container has no docker daemon, so the docker driver's own `config {}` schema is not
  checked (Nomad only checks it when the driver is loaded); a typo inside `config {}` is
  found by `nomad job run` on a real cluster.
- `nomad job plan` exits 1 when the job would create allocations — the normal result for a
  new job — so the check accepts 0 and 1 and fails on anything higher.

## Verified

**The docker job has NOT been verified yet.** On 2026-10-05 the build host's docker disk
stayed below the 6 GB floor (0-3 GB free) for over three hours, so `docker compose build`
was never run for this repo. Build and run it once before trusting it:

    docker compose build && docker compose run --rm app; docker compose down --rmi local -v

What WAS checked, with the real CLIs outside docker (same `scripts/check.sh` the image runs):

    nomad 2.0.7: sh scripts/check.sh        # fmt ok; dev agent up; validate + plan of web and cleanup
                                            # ("All tasks successfully allocated") -> exit 0, agent stopped

## Serving over HTTP

There is no HTTP surface. If you add one, listen on `0.0.0.0:$PORT`, serve at `/`, set
`PORT`, `HEALTH_PATH`, `START_CMD` and `DOCKER_START_CMD` in `fleet.conf`, and publish
`"${PORT}:${PORT}"` in `compose.yaml`. See `docs/fleet-lifecycle.md`.
