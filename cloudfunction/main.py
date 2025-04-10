import csv
import os
from google.cloud import bigquery

REQUIRED_COLUMNS = ["id", "name", "email"]

def validate_row(row):
    return all(col in row for col in REQUIRED_COLUMNS)

def upload_to_bigquery(rows, dataset_id, table_id):
    client = bigquery.Client()
    table_ref = f"{client.project}.{dataset_id}.{table_id}"
    errors = client.insert_rows_json(table_ref, rows)
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")

def process_csv(bucket_name, file_name):
    from google.cloud import storage
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    data = blob.download_as_text().splitlines()
    reader = csv.DictReader(data)

    valid_rows = []
    for row in reader:
        if validate_row(row):
            valid_rows.append(row)

    if valid_rows:
        upload_to_bigquery(valid_rows, os.environ["DATASET_ID"], os.environ["TABLE_ID"])

def entry_point(event, context):
    bucket = event["bucket"]
    name = event["name"]
    print(f"Processing file: {name} from bucket: {bucket}")
    process_csv(bucket, name)
