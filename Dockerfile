# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry.
#
# A job image, not a server: the default command runs scripts/check.sh, which
# format-checks the job specs, starts a throwaway `nomad agent -dev` inside the
# container (127.0.0.1 only), validates and dry-runs (`nomad job plan`) every
# spec against it, stops it, and exits 0 when all of it passes. Nothing is
# published and nothing listens on $PORT.

FROM hashicorp/nomad:2.0.7 AS runtime
ARG BUILD_ID=""
ENV BUILD_ID=$BUILD_ID HOME=/home/app
RUN adduser -D -u 10001 -h /home/app app \
 && mkdir /app && chown app:app /app
WORKDIR /app
COPY --chown=app:app . .
USER app
# the base image's ENTRYPOINT wraps `nomad`; the job is a script
ENTRYPOINT []
CMD ["sh", "scripts/check.sh"]
