import boto3
import json
import time
import requests
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

# AWS configurations
region = "eu-west-1"  # Replace with your preferred AWS region
bucket_name = os.getenv("AWS_BUCKET_NAME")  # Change to a unique S3 bucket name
glue_database_name = "aws_glue_catalog_database.datalake_database.name"
athena_output_location = f"s3://{bucket_name}/athena-results/"

# Sportsdata.io configurations (loaded from .env)
api_key = os.getenv("SPORTS_DATA_API_KEY")  # Get API key from .env
nba_endpoint = os.getenv("NBA_ENDPOINT")  # Get NBA endpoint from .env

# Create AWS clients
s3_client = boto3.client("s3", region_name=region)
glue_client = boto3.client("glue", region_name=region)
athena_client = boto3.client("athena", region_name=region)


def create_bucket_if_not_exists(self):
        """Create S3 bucket if it doesn't exist."""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"Bucket {self.bucket_name} exists.")
        except:
            print(f"Creating bucket {self.bucket_name}...")
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
                print(f"Successfully created bucket {self.bucket_name}.")
            except Exception as e:
                print(f"Error creating bucket: {e}")
                raise

def create_glue_database():
    """Create a Glue database for the data lake if it doesn't exist."""
    try:
        glue_client.create_database(
            DatabaseInput={
                "Name": glue_database_name,
                "Description": "Glue database for NBA sports analytics.",
            }
        )
        print(f"Glue database '{glue_database_name}' created successfully.")
    except Exception as e:
        print(f"Error creating Glue database: {e}")

def fetch_nba_data():
    """Fetch NBA player data from sportsdata.io."""
    try:
        headers = {"Ocp-Apim-Subscription-Key": api_key}
        response = requests.get(nba_endpoint, headers=headers)
        response.raise_for_status()  # Raise an error for bad status codes
        print("Fetched NBA data successfully.")
        return response.json()  # Return JSON response
    except Exception as e:
        print(f"Error fetching NBA data: {e}")
        return []

# def fetch_nba_data():

#      print(json.dumps(nba_data, indent=2))  # Debugging step

# if not nba_data:
#     print("No data received from API, skipping upload.")
#     return []


def convert_to_line_delimited_json(data):
    """Convert data to line-delimited JSON format."""
    print("Converting data to line-delimited JSON format...")
    return "\n".join([json.dumps(record) for record in data])

def upload_data_to_s3(data):
    """Upload NBA data to the S3 bucket."""
    try:
        if not data:
            print("No data to upload. Skipping...")
            return

        line_delimited_data = convert_to_line_delimited_json(data)
        file_key = "raw-data/nba_player_data.jsonl"

        response = s3_client.put_object(
            Bucket=bucket_name,
            Key=file_key,
            Body=line_delimited_data,
            ContentType="application/json"
        )
        print(f"Uploaded data to S3: {file_key}, Response: {response}")

    except Exception as e:
        print(f"Error uploading data to S3: {e}")


def create_glue_table():
    """Create a Glue table for the data if it doesn't exist."""
    try:
        glue_client.create_table(
            DatabaseName=glue_database_name,
            TableInput={
                "Name": "nba_players",
                "StorageDescriptor": {
                    "Columns": [
                        {"Name": "PlayerID", "Type": "int"},
                        {"Name": "FirstName", "Type": "string"},
                        {"Name": "LastName", "Type": "string"},
                        {"Name": "Team", "Type": "string"},
                        {"Name": "Position", "Type": "string"},
                        {"Name": "Points", "Type": "int"}
                    ],
                    "Location": f"s3://{bucket_name}/raw-data/",
                    "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
                    "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
                    "SerdeInfo": {
                        "SerializationLibrary": "org.openx.data.jsonserde.JsonSerDe"
                    },
                },
                "TableType": "EXTERNAL_TABLE",
            },
        )
        print(f"Glue table 'nba_players' created successfully.")
    except Exception as e:
        print(f"Error creating Glue table: {e}")

def configure_athena():
    """Set up Athena output location if it doesn't exist."""
    try:
        athena_client.start_query_execution(
            QueryString="CREATE DATABASE IF NOT EXISTS nba_analytics",
            QueryExecutionContext={"Database": glue_database_name},
            ResultConfiguration={"OutputLocation": athena_output_location},
        )
        print("Athena output location configured successfully.")
    except Exception as e:
        print(f"Error configuring Athena: {e}")

# Main workflow
def main():
    print("Setting up data lake for NBA sports analytics...")
    create_s3_bucket()
    time.sleep(5)  # Ensure bucket creation propagates
    create_glue_database()
    nba_data = fetch_nba_data()
    if nba_data:  # Only proceed if data was fetched successfully
        upload_data_to_s3(nba_data)
    create_glue_table()
    configure_athena()
    print("Data lake setup complete.")

if __name__ == "__main__":
    main()
