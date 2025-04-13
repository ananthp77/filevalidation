variable "project_id" {
    default = "empyrean-aurora-456314-b8"
}
variable "region" {
  default = "europe-west2"
}
variable "bq_dataset" {
  default = "ingestion"
}
variable "staging_table" {
  default = "staging_data"
}
variable "final_table" {
  default = "final_data"
}
variable "bq_procedure" {
  default = "sp_validate_and_merge"
}
