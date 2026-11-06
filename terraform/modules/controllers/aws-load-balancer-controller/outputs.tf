output "role_arn" {
  description = "ARN of the IAM role assumed by the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "policy_arn" {
  description = "ARN of the IAM policy created for the AWS Load Balancer Controller"
  value       = aws_iam_policy.alb_controller.arn
}

output "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount created for the controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.alb_controller.name
}

output "release_status" {
  description = "Status of the deployed Helm release"
  value       = helm_release.alb_controller.status
}
