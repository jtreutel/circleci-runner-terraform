variable "resource_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix to add to runner Name tag."
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Optional list of additional tags to apply to CircleCI Runners and their EBS volumes."
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region in which Runners will be deployed.  us-east-1 is recommended as storage performance will be better."
}

variable "cluster_size" {
  type        = number
  default     = 1
  description = "Number of runners to create."
}

variable "instance_size" {
  type        = string
  default     = "t3.large"
  description = "Runner instance size."
}

variable "root_volume_size" {
  type        = string
  default     = "100"
  description = "Runner root volume size."
}

variable "root_volume_type" {
  type        = string
  default     = "gp3"
  description = "Runner root volume type."
}

variable "key_name" {
  type        = string
  default     = ""
  description = "Name of EC2 key pair that will be used when creating the instances.  If blank, you will not be able to SSH into the Runners."
}

variable "inbound_cidrs" {
  type        = list(string)
  default     = null
  description = "List of CIDRs from which SSH traffic to the runners will be allowed.  If empty, no SSH traffic will be allowed."
}

variable "outbound_cidrs" {
  type        = list(string)
  default     = null
  description = "List of CIDRs to which traffic from the runners will be allowed.  If empty, all outbound traffic from the runners will be allowed."
}

variable "vpc_id" {
  type        = string
  description = "VPC into which the runners will be deployed."
}

variable "subnet_id" {
  type        = string
  description = "Subnet into which the runners will be deployed."
}

variable "assign_public_ip" {
  type        = bool
  default     = false
  description = "Set to true to assign public IPs to the runners."
}