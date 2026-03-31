terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  # credentials = file(var.credentials)
  project     = var.project
  region      = var.region
}


resource "google_storage_bucket" "terraform_bucket" {
  name          = var.gcs_bucket_name
  location      = var.location
  force_destroy = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true


  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}



resource "google_bigquery_dataset" "terraform_dataset" {
  dataset_id = var.bq_dataset_name
  location   = var.location
}