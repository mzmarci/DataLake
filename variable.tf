variable "nba_datalake_bucket" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "nbagame-datalake"
}

variable "versioning_bucket" {
  description = "Key versioning for S3 bucket"
  default     = "key-versioning-bucket"
}