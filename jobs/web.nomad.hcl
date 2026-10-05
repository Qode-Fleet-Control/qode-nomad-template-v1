# A long-running service: N copies of a web container behind a dynamic port, registered
# with Nomad's built-in service discovery and health-checked over HTTP.
#
#   nomad job run -var="image=nginx:1.29-alpine" -var="count=3" jobs/web.nomad.hcl

variable "datacenters" {
  type        = list(string)
  description = "Datacenters the job may run in."
  default     = ["dc1"]
}

variable "image" {
  type        = string
  description = "Container image to run."
  default     = "nginx:1.29-alpine"
}

variable "count" {
  type        = number
  description = "Number of instances."
  default     = 2
}

job "web" {
  datacenters = var.datacenters
  type        = "service"

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    canary            = 1
    auto_promote      = true
  }

  group "web" {
    count = var.count

    # give the service registry time to drop an instance before it is killed
    shutdown_delay = "5s"

    network {
      port "http" {
        to = 80
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    service {
      name     = "web"
      port     = "http"
      provider = "nomad"
      tags     = ["http"]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = var.image
        ports = ["http"]
      }

      env {
        APP_ENV = "production"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
