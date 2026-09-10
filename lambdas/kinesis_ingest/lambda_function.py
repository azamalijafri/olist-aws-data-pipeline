import base64
import json
import os
import uuid
from decimal import Decimal

import boto3

s3 = boto3.client("s3")
ddb = boto3.resource("dynamodb")

S3_BUCKET = os.environ["S3_BUCKET"]
DDB_TABLE = os.environ["DDB_TABLE"]


def day_key(ts):
    return ts[:10].replace("-", "")


def lambda_handler(event, context):
    table = ddb.Table(DDB_TABLE)
    records = []
    for rec in event["Records"]:
        payload = json.loads(base64.b64decode(rec["kinesis"]["data"]))
        records.append(payload)

    object_key = f"events/{uuid.uuid4().hex}.jsonl"
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=object_key,
        Body="\n".join(json.dumps(r) for r in records) + "\n",
    )

    for r in records:
        day = day_key(r["event_time"])
        ptype = r["payment_type"]
        for metric in (f"payments:{ptype}|{day}", f"payments:total|{day}"):
            table.update_item(
                Key={"metric": metric},
                UpdateExpression="ADD count_value :one, sum_value :val",
                ExpressionAttributeValues={
                    ":one": 1,
                    ":val": Decimal(str(float(r["payment_value"]))),
                },
            )

    print(f"processed {len(records)} records -> {object_key}")
    return {"statusCode": 200}