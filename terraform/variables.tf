
/* variable "credentials" {
  description = "My Credentials"
  default     = "<Path to your Service Account json file>"
  #ex: if you have a directory where this file is called keys with your service account json file
  #saved there as my-creds.json you could use default = "./keys/my-creds.json"
} */



variable "project" {
  description = "AML Dashboard"
  default     = "aml-dashboard-491905"
}

variable "region" {
  description = "Region"
  #Update the below to your desired region
  default     = "us-central1"
}

variable "location" {
  description = "Project Location"
  #Update the below to your desired location
  default     = "us-central1"
}

variable "bq_dataset_name" {
  description = "AML Dashboard IBM synthetic data"
  #Update the below to what you want your dataset to be called
  default     = "aml_dashboard_pmg_dataset"
}

variable "gcs_bucket_name" {
  description = "My Storage Bucket Name"
  #Update the below to a unique bucket name
  default     = "aml_dashboard_pmg_bucket"
}

variable "gcs_storage_class" {
  description = "Bucket Storage Class"
  default     = "STANDARD"
}