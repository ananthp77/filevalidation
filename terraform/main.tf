provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "csv_bucket" {
  name     = "${var.project_id}-csv-bucket"
  location = var.region
}

resource "google_bigquery_dataset" "data_dataset" {
  dataset_id = "data_pipeline"
  location   = var.region
}

resource "google_bigquery_table" "staging_table" {
  dataset_id = google_bigquery_dataset.data_dataset.dataset_id
  table_id   = "staging"
  schema     = file("${path.module}/bq/staging_schema.json")
}

resource "google_bigquery_table" "final_table" {
  dataset_id = google_bigquery_dataset.data_dataset.dataset_id
  table_id   = "final"
  schema     = file("${path.module}/bq/final_schema.json")
}

resource "google_storage_bucket_object" "cloudfunction_zip" {
  name   = "cloudfunction-source.zip"
  bucket = google_storage_bucket.csv_bucket.name
  source = "${path.module}/cloudfunction/cloudfunction-source.zip"
}

resource "google_cloudfunctions2_function" "validator_fn" {
  name     = "validate-csv-function"
  location = var.region
  build_config {
    runtime     = "python311"
    entry_point = "validate_csv"
    source {
      storage_source {
        bucket = google_storage_bucket.csv_bucket.name
        object = google_storage_bucket_object.cloudfunction_zip.name
      }
    }
  }

  service_config {
    timeout_seconds  = 60
    available_memory = "256M"
  }

  event_trigger {
  event_type     = "google.cloud.storage.object.v1.finalized"
  trigger_region = var.region
  event_filters {
    attribute = "bucket"
    value     = google_storage_bucket.csv_bucket.name
  }
}

resource "google_workflows_workflow" "csv_pipeline" {
  name            = "csv-pipeline"
  region          = var.region
  source_contents = file("${path.module}/workflows/csv_pipeline.yaml")

}