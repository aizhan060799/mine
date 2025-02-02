variable "eks_cluster_name" {
  type = string
}

variable "k8s_version" {
  type    = string
  default = "1.31"
}

variable "public_subnets" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "instance_types" {
  type = list(string)
}

variable "desired_capacity" {
  description = "The desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "The minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "The maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "cluster_addons" {
  description = "List of EKS add-ons to install"
  type        = set(string)
}

# variable "admin" {
#   description = "AWSReserved_Administrator"
#   type        = string
# }

# variable "github-runner-cicd" {
#   description = "GitHubActionsCICDrole"
#   type        = string
# }

# variable "github-runner-terraform" {
#   description = "GitHubActionsTerraformIAMrole"
#   type        = string
# }