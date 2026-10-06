# Production environment values for the Qwiklabs GCP project.
# Pass with:  terraform plan -var-file=environments/production.tfvars
# No secrets here: the lab password is never stored in this repo.
project_id = "qwiklabs-gcp-03-14c91c25fc1"
region     = "us-central1"
zone       = "us-central1-a"

extra_subnets = {
  shared-2 = {
    vpc  = "shared"
    cidr = "10.0.1.0/24"
  }
}