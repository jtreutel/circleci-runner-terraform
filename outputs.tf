output "runner_private_ips" {
  #value = zipmap(
  #    lookup(aws_instance.circleci_runner.*.tags, "Name"),
  #    aws_instance.circleci_runner.*.private_ip
  #)
  value = {
    for instance in aws_instance.circleci_runner :
    instance.tags["Name"] => instance.private_ip
  }

}

output "runner_public_ips" {
  value = var.assign_public_ip == true ? {
    for instance in aws_instance.circleci_runner :
    instance.tags["Name"] => instance.public_ip
  } : null
}