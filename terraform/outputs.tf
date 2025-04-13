output "bucket_name" {
  value = google_storage_bucket.data_bucket.name
}

output "function_name" {
  value = google_cloudfunctions2_function.csv_ingest_function.name
}
