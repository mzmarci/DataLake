resource "aws_s3_bucket" "nba_datalake" {
  bucket = var.nba_datalake_bucket


  tags = {
    Name        = "Datalake"
    Environment = "Dev"
    Project     = "DataCollection"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "datalake-bucket" {
  bucket = aws_s3_bucket.nba_datalake.id

  rule {
    id     = "log"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket" "datalake_versioning_bucket" {
  bucket = var.versioning_bucket
}

resource "aws_s3_bucket_versioning" "datalake_versioning" {
  bucket = aws_s3_bucket.datalake_versioning_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "versioning_bucket_config" {
  bucket = aws_s3_bucket.datalake_versioning_bucket.id

  depends_on = [aws_s3_bucket_versioning.datalake_versioning]

  rule {
    id     = "log"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.nba_datalake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create a Glue Database
# A Glue database acts as a container for tables.

resource "aws_glue_catalog_database" "datalake_database" {
  name = "my_glue_database"
}

# Create a Glue Table (Optional)
# using schema, we can define it manually:

resource "aws_glue_catalog_table" "datalake_catalog" {
  name          = "my_glue_table"
  database_name = aws_glue_catalog_database.datalake_database.name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.nba_datalake.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "SerDe"
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
    }

    columns {
      name = "id"
      type = "int"
    }

    columns {
      name = "name"
      type = "string"
    }
  }
}

# Create a Glue Crawler
# A crawler scans S3 and automatically detects schema.

resource "aws_glue_crawler" "datalake_crawler" {
  name          = "my-glue-crawler"
  role          = aws_iam_role.datalake_glue_role.arn
  database_name = aws_glue_catalog_database.datalake_database.name

  s3_target {
    path = "s3://${aws_s3_bucket.nba_datalake.id}/data/"

  }
}
# Create an IAM Role for Glue
# AWS Glue needs an IAM role to access S3 and other services.


resource "aws_iam_role" "datalake_glue_role" {
  name = "database_glue_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "datalake_glue_s3_access" {
  name       = "datalake_glue_s3_access"
  roles      = [aws_iam_role.datalake_glue_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Create a Glue Job
# A Glue Job is an ETL script that transforms data.

resource "aws_glue_job" "datalake_glue" {
  name     = "datalake-glue-job"
  role_arn = aws_iam_role.datalake_glue_role.arn
  command {
    script_location = "s3://${aws_s3_bucket.nba_datalake.id}/scripts/my_etl_script.py"
    name            = "glueetl"
  }
}

# Create an Athena Named Query

resource "aws_athena_named_query" "datalake_query" {
  name        = "DatalakeSampleQuery"
  description = "A sample Athena query to analyze my data"
  database    = aws_glue_catalog_database.datalake_database.name
  query       = <<EOF
SELECT *
FROM my_glue_table
WHERE id > 100;
EOF
}

# Create an Athena Workgroup
# Athena workgroups help to manage query settings, control costs, and monitor usage.

resource "aws_athena_workgroup" "datalake_workgroup" {
  name = "MyAthenaWorkgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.nba_datalake.id}/athena-results/"
    }
  }

  state = "ENABLED"
}