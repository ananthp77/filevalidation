import csv, io
from google.cloud import storage
from google.cloud.workflows.executions_v1beta import ExecutionsClient

def validate_csv(event, context):
    client = storage.Client()
    bucket = client.bucket(event['bucket'])
    blob = bucket.blob(event['name'])
    content = blob.download_as_text()

    reader = csv.DictReader(io.StringIO(content))
    for row in reader:
        if not row.get("id") or not row.get("name"):
            raise ValueError("Validation failed: Missing required fields.")

    executions_client = ExecutionsClient()
    parent = f"projects/YOUR_PROJECT_ID/locations/YOUR_REGION/workflows/csv-pipeline"
    executions_client.create_execution(request={"parent": parent})