#!/bin/sh
# The job: format-check every job spec, then validate and dry-run (`nomad job plan`) each
# one against a throwaway dev-mode Nomad agent started here, on 127.0.0.1 only. Exits
# non-zero on the first failure.
set -eu
cd "$(dirname "$0")/.."

echo "==> nomad fmt -check"
nomad fmt -check -recursive jobs

data=$(mktemp -d)
export NOMAD_ADDR="http://127.0.0.1:${NOMAD_DEV_PORT:-4646}"
printf 'ports {\n  http = %s\n}\n' "${NOMAD_DEV_PORT:-4646}" > "$data/ports.hcl"
echo "==> nomad agent -dev (background, log: $data/agent.log)"
nomad agent -dev -bind=127.0.0.1 -network-interface=lo -data-dir="$data/data" \
  -config="$data/ports.hcl" >"$data/agent.log" 2>&1 &
agent=$!
trap 'kill "$agent" 2>/dev/null || true; wait "$agent" 2>/dev/null || true; rm -rf "$data"' EXIT

i=0
until nomad node status 2>/dev/null | grep -q ready; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then echo "nomad dev agent did not come up:" >&2; tail -40 "$data/agent.log" >&2; exit 1; fi
  sleep 1
done

for job in jobs/*.nomad.hcl; do
  echo "==> nomad job validate $job"
  nomad job validate "$job"
  echo "==> nomad job plan $job"
  # plan exits 1 when the job would create allocations (the normal case for a new job),
  # 255 on an error
  rc=0; nomad job plan "$job" || rc=$?
  if [ "$rc" -gt 1 ]; then echo "nomad job plan $job failed ($rc)" >&2; exit "$rc"; fi
done
echo "nomad: all job specs valid"
