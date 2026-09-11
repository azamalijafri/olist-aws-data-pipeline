import argparse
import csv
import json
import os
import time
import uuid
from pathlib import Path

import boto3

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_env():
    env_path = REPO_ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip())


load_env()

STREAM = os.environ["KINESIS_STREAM"]
REGION = os.environ["OLIST_REGION"]
RAW_DIR = os.environ["RAW_CSV_DIR"]
PAYMENTS_CSV = f"{RAW_DIR}/olist_order_payments_dataset.csv"
ORDERS_CSV = f"{RAW_DIR}/olist_orders_dataset.csv"


def load_order_dates(path):
    dates = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            dates[row["order_id"]] = row["order_purchase_timestamp"]
    return dates


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=5000)
    ap.add_argument("--stream", default=STREAM)
    ap.add_argument("--sleep", type=float, default=0.0)
    args = ap.parse_args()

    client = boto3.client("kinesis", region_name=REGION)
    order_dates = load_order_dates(ORDERS_CSV)

    batch = []
    sent = 0
    with open(PAYMENTS_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            event = {
                "event_id": str(uuid.uuid4()),
                "event_time": order_dates.get(row["order_id"], ""),
                "source": "olist_csv",
                "order_id": row["order_id"],
                "payment_sequential": int(row["payment_sequential"]),
                "payment_type": row["payment_type"],
                "payment_installments": int(row["payment_installments"]),
                "payment_value": float(row["payment_value"]),
            }
            batch.append(
                {
                    "Data": json.dumps(event),
                    "PartitionKey": event["payment_type"],
                }
            )
            sent += 1
            if len(batch) == 500 or sent >= args.limit:
                client.put_records(StreamName=args.stream, Records=batch)
                print(f"sent {sent}")
                batch = []
                if sent >= args.limit:
                    break
                if args.sleep:
                    time.sleep(args.sleep)

    if batch:
        client.put_records(StreamName=args.stream, Records=batch)
        print(f"sent {sent}")

    print("done")


if __name__ == "__main__":
    main()