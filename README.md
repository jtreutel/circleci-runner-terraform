# circleci-runner-terraform
Terraform plan to deploy a CircleCI Runner cluster.

## Requirements

- Terraform (>= 0.13.6)
- CircleCI CLI (>= 0.1.11924)

## How to Use

1. Create a namespace, resource class, and runner token as described in [the documentation.](https://circleci.com/docs/2.0/runner-installation/#authentication)
1. Copy the terraform.tfvars.example file and replace required values
2. Check optional values to ensure the runners are configured appropriately for your use case
3. Run `terraform plan` and inspect proposed changes
4. Run `terraform apply` to apply changes
5. Verify that runners are registered with your CircleCI org by using the command `circleci runner instance list <your-org-namespace-here>`

**Optional:** If you would like to do a sandbox deploy to test the Terraform plan, follow these steps:

1. Enter the necessary values in terraform.tfvars.example and save your changes
2. Run the following bash command: `base64 terraform.tfvars.example`
3. Store the output in a context or project-level variable named BASE64_TFVARS.


## Resources Created by Terraform

- aws_autoscaling_group.circleci_runner
- aws_launch_template.circleci_runner
- aws_placement_group.circleci_runner
- aws_security_group.circleci_runner
- aws_security_group_rule.allow_inbound_ssh
- aws_security_group_rule.allow_outbound

## Terraform Variables

### Required 

| Name | Default | Description|
|------|---------|------------|
|aws_region|none|Region in which Runners will be deployed.|
|vpc_id|none|VPC into which the runners will be deployed.|
|subnet_list|none|List of subnets into which runners will be deployed.|
|asg_min_size|none|Minimum number of runners.|
|asg_max_size|none|Maximum number of runners.|
|asg_desired_size|none|Desired number of runners.|
|runner_auth_token|none|Runner auth token.  [See docs for how to generate one.](https://circleci.com/docs/2.0/runner-installation/#authentication)|

### Optional

| Name | Default | Description|
|------|---------|------------|
|resource_prefix|`""`|Optional prefix to add to runner Name tag.|
|extra_tags|`{}`|Optional list of additional tags to apply to CircleCI Runners, EBS volumes, and Auto Scaling resources.|
|instance_size|`t3.large`|Runner instance size.|
|root_volume_size|`100`|Runner root volume size.|
|root_volume_type|`gp3`|Runner root volume type.|
|key_name|`""`|Name of EC2 key pair that will be used when creating the instances.  If blank, you will not be able to SSH into the Runners.|
|inbound_cidrs|`null`|List of CIDRs from which SSH traffic to the runners will be allowed.  If empty, no SSH traffic will be allowed.|
|outbound_cidrs|`null`|List of CIDRs to which traffic from the runners will be allowed.  If empty, all outbound traffic from the runners will be allowed.|
|assign_public_ip|`false`|Set to true to assign public IPs to the runners.|
|launch_template_version|`$Latest`|Launch template version. Leave as default if you're not sure what to do.|