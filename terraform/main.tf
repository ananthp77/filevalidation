provider "google" {
  project = var.project_id
  region  = var.region
}
data "google_project" "project" {
  project_id = var.project_id
}
resource "google_project_iam_member" "allow_gcs_to_publish_to_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "data_bucket" {
  name          = "${var.project_id}-data-bucket"
  location      = var.region
  force_destroy = true
}

resource "google_bigquery_dataset" "dataset" {
  dataset_id                  = var.bq_dataset
  location                    = var.region
  delete_contents_on_destroy = true
}

resource "google_bigquery_table" "staging" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = var.staging_table
  deletion_protection = false

  schema = file("${path.module}/bq/staging_schema.json")
}


resource "google_bigquery_table" "final" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = var.final_table
  deletion_protection = false

  schema = file("${path.module}/bq/final_schema.json")
}


resource "google_bigquery_routine" "sp_validate_and_merge" {
  dataset_id   = google_bigquery_dataset.dataset.dataset_id
  routine_id   = "sp_validate_and_merge"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = file("${path.module}/bq/sp_validate_and_merge.sql")
}


resource "google_storage_bucket_object" "function_zip" {
  name   = "cloud-function.zip"
  bucket = google_storage_bucket.data_bucket.name
  source = "${path.module}/../cloud_function.zip"
}

resource "google_cloudfunctions2_function" "csv_ingest_function" {
  name        = "csv-ingest-function"
  location    = var.region
  description = "Triggered by GCS file upload and loads into BigQuery"

  build_config {
    runtime     = "python310"
    entry_point = "gcs_trigger"

    source {
      storage_source {
        bucket = google_storage_bucket.data_bucket.name
        object = google_storage_bucket_object.function_zip.name
      }
    }
  }

  service_config {
    environment_variables = {
      BQ_DATASET     = var.bq_dataset
      STAGING_TABLE  = var.staging_table
      BQ_PROCEDURE   = var.bq_procedure
    }
    timeout_seconds   = 60
    available_memory  = "256M"
    ingress_settings  = "ALLOW_ALL"
  }

  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.data_bucket.name
    }

    retry_policy = "RETRY_POLICY_RETRY"
  }
}
