provider "google" {
  project = var.project_id
  region  = var.region
}

# GCS Bucket for raw files and Cloud Function source
resource "google_storage_bucket" "csv_bucket" {
  name     = "${var.project_id}-csv-bucket"
  location = var.region
}

# Upload Cloud Function ZIP to GCS
resource "google_storage_bucket_object" "cloudfunction_zip" {
  name   = "cloudfunction/cloudfunction-source.zip"
  bucket = google_storage_bucket.csv_bucket.name
  source = "../cloudfunction/cloudfunction-source.zip"
}

# BigQuery Dataset
resource "google_bigquery_dataset" "data_dataset" {
  dataset_id = "data_pipeline"
  location   = var.region
}

# BigQuery Tables
resource "google_bigquery_table" "staging_table" {
  dataset_id = google_bigquery_dataset.data_dataset.dataset_id
  table_id   = "staging"
  schema     = file("./bq/staging_schema.json")
  deletion_protection = false
}

resource "google_bigquery_table" "final_table" {
  dataset_id = google_bigquery_dataset.data_dataset.dataset_id
  table_id   = "final"
  schema     = file("./bq/final_schema.json")
  deletion_protection = false
}

# Cloud Function (2nd Gen)
resource "google_cloudfunctions2_function" "validator_fn" {
  name     = "csv-validator"
  location = var.region

  build_config {
    runtime     = "python310"
    entry_point = "validate_csv"
    source {
      storage_source {
        bucket = google_storage_bucket.csv_bucket.name
        object = google_storage_bucket_object.cloudfunction_zip.name
      }
    }
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    ingress_settings   = "ALLOW_ALL"
    environment        = "GEN_2"
  }

  event_trigger {
    event_type     = "google.cloud.storage.object.v1.finalized"
    trigger_region = var.region
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.csv_bucket.name
    }
  }
}

# Workflows definition
resource "google_workflows_workflow" "csv_pipeline" {
  name     = "csv-pipeline"
  region   = var.region
  description = "Load CSV, deduplicate, clean, and merge"

  source_contents = file("${path.module}/workflows/csv_pipeline.yaml")
}
