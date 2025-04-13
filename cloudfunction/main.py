import functions_framework
from google.cloud import bigquery, storage
import os
from datetime import datetime

DEFAULT_DATE = "1700-01-01"
def transform_data(row):
    try:
        if not is_valid_date(row["signup_date"]):
            row["signup_date"] = DEFAULT_DATE
        if not is_valid_date(row["last_login"]):
            row["last_login"] = DEFAULT_DATE
        row["purchase_amount"] = abs(float(row["purchase_amount"]))
    except Exception as e:
        print(f"Error transforming row {row}: {str(e)}")
    return row

def is_valid_date(date_str):
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
        return True
    except ValueError:
        return False

@functions_framework.cloud_event
def gcs_trigger(cloud_event):
    file = cloud_event.data["name"]
    bucket = cloud_event.data["bucket"]
    dataset = os.environ["BQ_DATASET"]
    staging_table = os.environ["STAGING_TABLE"]
    procedure = os.environ["BQ_PROCEDURE"]
    uri = f"gs://{bucket}/{file}"
    bq_client = bigquery.Client()
    storage_client = storage.Client()
    schema = [
        bigquery.SchemaField("id", "INTEGER", mode="REQUIRED"),
        bigquery.SchemaField("name", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("email", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("age", "INTEGER", mode="REQUIRED"),
        bigquery.SchemaField("country", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("signup_date", "DATE", mode="REQUIRED"),
        bigquery.SchemaField("last_login", "DATE", mode="REQUIRED"),
        bigquery.SchemaField("status", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("purchase_amount", "FLOAT", mode="REQUIRED"),
        bigquery.SchemaField("membership_level", "STRING", mode="REQUIRED"),
    ]
    bucket = storage_client.bucket(bucket)
    blob = bucket.blob(file)
    content = blob.download_as_text()
    rows = []
    lines = content.splitlines()

    for line in lines[1:]:
        row_data = line.split(",")
        transformed_row = transform_data({
            "id": row_data[0],
            "name": row_data[1],
            "email": row_data[2],
            "age": row_data[3],
            "country": row_data[4],
            "signup_date": row_data[5],
            "last_login": row_data[6],
            "status": row_data[7],
            "purchase_amount": row_data[8],
            "membership_level": row_data[9],
        })
        rows.append(transformed_row)


    table_id = f"{bq_client.project}.{dataset}.{staging_table}"
    '''job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        schema=schema,
        skip_leading_rows=1,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Or WRITE_TRUNCATE, depending on your use case
    )'''
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )


    load_job = bq_client.load_table_from_json(rows, table_id, job_config=job_config)
    load_job.result()

    print(f"Loaded data into {table_id}.")

    if procedure:
        query = f"CALL `{dataset}.{procedure}`();"
        query_job = bq_client.query(query)
        query_job.result()
        print("Stored procedure executed.")
