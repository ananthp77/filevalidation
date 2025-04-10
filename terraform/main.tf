provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "csv_bucket" {
  name     = var.bucket_name
  location = var.region
}

resource "google_bigquery_dataset" "data_dataset" {
  dataset_id = var.dataset_id
  location   = var.region
}

resource "google_bigquery_table" "data_table" {
  dataset_id = google_bigquery_dataset.data_dataset.dataset_id
  table_id   = var.table_id

  schema = jsonencode([
    { name = "id", type = "STRING", mode = "REQUIRED" },
    { name = "name", type = "STRING", mode = "NULLABLE" },
    { name = "email", type = "STRING", mode = "NULLABLE" }
  ])
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "function_source.zip"
  bucket = google_storage_bucket.csv_bucket.name
  source = "${path.module}/cloudfunction.zip"
}

resource "google_cloudfunctions_function" "csv_handler" {
  name        = "csv-handler"
  description = "Triggered when CSV lands in GCS, validates and loads to BQ"
  runtime     = "python310"
  entry_point = "entry_point"
  source_archive_bucket = google_storage_bucket.csv_bucket.name
  source_archive_object = google_storage_bucket_object.function_zip.name
  trigger_bucket = google_storage_bucket.csv_bucket.name
  region      = var.region

  environment_variables = {
    DATASET_ID = var.dataset_id
    TABLE_ID   = var.table_id
  }
}
