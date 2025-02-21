output "datalake_bucket" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.nba_datalake.id
}

output "catalog_database" {
  description = "The name of the S3 bucket"
  value       = aws_glue_catalog_database.datalake_database.name
}
output "catalog_table" {
  description = "The name of the S3 bucket"
  value       = aws_glue_catalog_table.datalake_catalog.name
}

output "glue_crawler" {
  description = "The name of the S3 bucket"
  value       = aws_glue_crawler.datalake_crawler.name
}

output "glue_job" {
  description = "The name of the S3 bucket"
  value       = aws_glue_job.datalake_glue.name
}

output "athena_named_query" {
  description = "The name of the S3 bucket"
  value       = aws_athena_named_query.datalake_query.name
}

output "athena_workgroup" {
  description = "The name of the S3 bucket"
  value       = aws_athena_workgroup.datalake_workgroup.name
}