# A periodic batch job: runs a short-lived container every night and exits.
#
#   nomad job run jobs/cleanup.nomad.hcl
#   nomad job periodic force cleanup      # run it now

variable "datacenters" {
  type        = list(string)
  description = "Datacenters the job may run in."
  default     = ["dc1"]
}

job "cleanup" {
  datacenters = var.datacenters
  type        = "batch"

  periodic {
    crons            = ["0 3 * * *"]
    time_zone        = "UTC"
    prohibit_overlap = true
  }

  group "cleanup" {
    restart {
      attempts = 1
      mode     = "fail"
    }

    task "cleanup" {
      driver = "docker"

      config {
        image   = "alpine:3.22"
        command = "/bin/sh"
        args    = ["-c", "echo cleaning up && sleep 5 && echo done"]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}
