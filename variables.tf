variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for all subnets"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the VMs (must be inside the region)"
  type        = string
  default     = "us-central1-a"
}

# One entry per VPC. Add or remove entries here and Terraform adapts.
# CIDR ranges must NOT overlap, otherwise peering will fail.
variable "vpcs" {
  description = "VPC name => subnet CIDR range"
  type        = map(string)
  default = {
    shared = "10.0.0.0/24"
    b3     = "10.1.0.0/24"
    b4     = "10.2.0.0/24"
    bsys   = "10.3.0.0/24"
  }
}
