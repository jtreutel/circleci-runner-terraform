#-------------------------------------------------------------------------------
# REQUIRED VARS
# Required input values without which the plan will not run.
#-------------------------------------------------------------------------------



variable "aws_region" {
  type        = string
  description = "Region in which Runners will be deployed."
}

variable "vpc_id" {
  type        = string
  description = "VPC into which the runners will be deployed."
}

variable "subnet_list" {
  type        = list(string)
  description = "List of subnets into which runners will be deployed."
}

variable "asg_min_size" {
  type        = number
  description = "Minimum number of runners."
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of runners."
}

variable "asg_desired_size" {
  type        = number
  description = "Desired number of runners."
}

variable "runner_auth_token" {
  type        = string
  description = "Runner auth token.  See docs for how to generate one." #See https://circleci.com/docs/2.0/runner-installation/#authentication
}

variable "circle_token" {
  type        = string
  description = "CircleCI API token.  See docs for how to generate one." #See https://circleci.com/docs/2.0/managing-api-tokens/
  sensitive   = true
}

variable "resource_class" {
  type        = string
  description = "Name of the runner cluster resource class, e.g. acmecorp/xlarge"
  sensitive   = true
}

variable "scaling_triggers" {
  type = list(
    object(
      {
        alarm_period         = number
        alarm_threshold      = number
        asg_scale_percentage = number
        asg_scale_cooldown   = number
      }
    )
  )

  #The below default is provided as an example only -- please consider your scaling needs and write appropriate alarms and scaling policies.
  # In this example, the cloudwatch alarm will trigger when the job queue depth is at >= 3 for 120 seconds.  Auto scaling will scale the cluster out by 50% of its current size and then wait 300 seconds before scaling again using this policy.
  default = [
    {
      alarm_period         = 120
      alarm_threshold      = 3
      asg_scale_percentage = 50
      asg_scale_cooldown   = 300
    }
  ]
  description = "A list of objects that define Cloudwatch alarms and EC2 auto scaling policies used to autoscale the runner cluster."
}

#-------------------------------------------------------------------------------
# OPTIONAL VARS
# Default values supplied, but you should still review each one.
#-------------------------------------------------------------------------------



variable "resource_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix to add to runner Name tag. We recommend including the resource class name here or in an extra tag."
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Optional list of additional tags to apply to CircleCI Runners, EBS volumes, and Auto Scaling resources."
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

variable "assign_public_ip" {
  type        = bool
  default     = false
  description = "Set to true to assign public IPs to the runners."
}

variable "secrets_manager_kms_key_id" {
  type        = string
  default     = ""
  description = "KMS key that will be used to encrypt secrets containing CircleCI API token and resource class.  WARNING!  If empty, Terraform will create a KMS CMK that allows all AWS account users to decrypt these secrets."
}

variable "launch_template_version" {
  type        = string
  default     = "$Latest"
  description = "Launch template version. Leave as default unless you have a specific reason to change this."
}

variable "metric_namespace" {
  type        = string
  default     = "CircleCI"
  description = "Cloudwatch metric namespace to which job queue depth metrics will be written."
}

variable "metric_name" {
  type        = string
  default     = "Job Queue Depth"
  description = "Name given to Cloudwatch job queue depth metric."
}