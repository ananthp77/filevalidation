output "gcs_bucket" {
  value = google_storage_bucket.csv_bucket.name
}

output "bigquery_dataset" {
  value = google_bigquery_dataset.data_dataset.dataset_id
}

output "cloud_function_name" {
  value = google_cloudfunctions2_function.validator_fn.name
}

output "workflow_name" {
  value = google_workflows_workflow.csv_pipeline.name
}