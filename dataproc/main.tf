# dataproc staging bucket
resource "google_storage_bucket" "dataproc_staging_bucket_info" {
  name          = var.dataproc_staging_bucket_name
  location      = lookup(var.bucket_location, var.cluster_location)
  force_destroy = "true"
}


resource "google_dataproc_cluster" "dataproc_cluster" {
  provider = google-beta

  name    = var.cluster_name
  project = var.project_id
  region  = var.region

  labels  = var.labels

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc_staging_bucket_info.name

    master_config {
      num_instances     = var.master_num_instances
      machine_type      = var.master_machine_type
      disk_config {
        boot_disk_type    = var.master_boot_disk_type
        boot_disk_size_gb = var.master_boot_disk_size_gb
        num_local_ssds    = var.master_num_local_ssds
      }
    }

    worker_config {
      num_instances     = var.worker_num_instances
      machine_type      = var.worker_machine_type
      disk_config {
        boot_disk_type    = var.worker_boot_disk_type
        boot_disk_size_gb = var.worker_boot_disk_size_gb
        num_local_ssds    = var.worker_num_local_ssds
      }
    }

    preemptible_worker_config {
      num_instances     = var.preemptible_num_instances
      disk_config {
        boot_disk_type    = var.preemptible_boot_disk_type
        boot_disk_size_gb = var.preemptible_boot_disk_size_gb
        num_local_ssds    = var.preemptible_num_local_ssds
      }
    }

    # Override or set some custom properties
    software_config {
      image_version       = var.image_version

      override_properties = {
        "dataproc:dataproc.allow.zero.workers"        = "true"
        "dataproc:dataproc.conscrypt.provider.enable" = "false"
        # "projects/qwiklabs-gcp-01-df6bb7e75177/locations/global/keyRings/my-keyring/cryptoKeys/my-key"
        # "projects/projectId/locations/locationId/keyRings/keyRingId/cryptoKeys/keyId"
        "dataproc:ranger.kms.key.uri" = "projects/gooddxai-dataproc/locations/global/keyRings/gooddxai-keyring/cryptoKeys/ranger-key" 
        "dataproc:ranger.admin.password.uri" = "gs://gooddxai-default-1019667713070/ranger/admin-password.encrypted"
      }
    }

    # component gateway
    endpoint_config { 
      enable_http_port_access = true
    }

    gce_cluster_config {
	    service_account = var.service_account
	    service_account_scopes = [
        "https://www.googleapis.com/auth/monitoring",
        "useraccounts-ro",
        "storage-rw",
        "logging-write",
         ]
      subnetwork          = var.subnetwork
      zone                = var.zone
      internal_ip_only    = true
      tags                = var.network_tags
    }

    # You can define multiple initialization_action blocks
    initialization_action {
      script      = "gs://dataproc-initialization-actions/cloud-sql-proxy/cloud-sql-proxy.sh"
      timeout_sec = 500
    }
    initialization_action {
      script      = "gs://dataproc-initialization-actions/stackdriver/stackdriver.sh"
      timeout_sec = 500
    }
    # initialization_action {
    #   script      = "gs://dataproc-initialization-actions/ganglia/ganglia.sh"
    #   timeout_sec = 500
    # }
    # initialization_action {
    #   script      = "gs://dataproc-initialization-actions/docker/docker.sh"
    #   timeout_sec = 500
    # }
    # initialization_action {
    #   script      = "gs://dataproc-initialization-actions/livy/livy.sh"
    #   timeout_sec = 500
    # }
    # initialization_action {
    #   script      = "gs://dataproc-initialization-actions/kafka/kafka.sh"
    #   timeout_sec = 500
    # }
    # initialization_action {
    #   script      = "gs://dataproc-initialization-actions/atlas/atlas.sh"
    #   timeout_sec = 500
    # }
    initialization_action {
      script      = "gs://dataproc-initialization-actions/oozie/oozie.sh"
      timeout_sec = 500
    }
    initialization_action {
      script      = "gs://dataproc-initialization-actions/hue/hue.sh"
      timeout_sec = 500
    }
    autoscaling_config {
      policy_uri = google_dataproc_autoscaling_policy.asp.name
    }
  }

  depends_on = [google_storage_bucket.gdx_staging_bucket_info]

  timeouts {
    create = "30m"
    delete = "30m"
  }
}

resource "google_dataproc_autoscaling_policy" "asp" {
  policy_id = "dataproc-policy"
  location  = var.cluster_location

  worker_config {
    max_instances = 3
  }

  basic_algorithm {
    yarn_config {
      graceful_decommission_timeout = "30s"

      scale_up_factor   = 0.5
      scale_down_factor = 0.5
    }
  }
}