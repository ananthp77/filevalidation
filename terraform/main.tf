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
} # <-- This closing brace was missing
