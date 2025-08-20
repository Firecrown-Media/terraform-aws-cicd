# Output values for the CI/CD module

# CodePipeline Outputs
output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.main.name
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.main.arn
}

# CodeBuild Outputs
output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.main.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.main.arn
}

# S3 Outputs
output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.arn
}

# IAM Role Outputs
output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_role.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_role.arn
}

output "codedeploy_role_arn" {
  description = "ARN of the CodeDeploy service role"
  value       = var.create_codedeploy_app ? aws_iam_role.codedeploy_role[0].arn : null
}

# CodeDeploy Outputs (conditional)
output "codedeploy_app_name" {
  description = "Name of the CodeDeploy application"
  value       = var.create_codedeploy_app ? aws_codedeploy_app.main[0].name : null
}

output "codedeploy_app_arn" {
  description = "ARN of the CodeDeploy application"
  value       = var.create_codedeploy_app ? aws_codedeploy_app.main[0].arn : null
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = var.create_codedeploy_app ? aws_codedeploy_deployment_group.main[0].deployment_group_name : null
}

# CloudWatch Outputs
output "codebuild_log_group_name" {
  description = "Name of the CodeBuild CloudWatch log group"
  value       = aws_cloudwatch_log_group.codebuild.name
}

output "codedeploy_log_group_name" {
  description = "Name of the CodeDeploy CloudWatch log group"
  value       = var.create_codedeploy_app ? aws_cloudwatch_log_group.codedeploy[0].name : null
}

# SNS Outputs (conditional)
output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = var.create_sns_topic ? aws_sns_topic.pipeline_notifications[0].arn : null
}

output "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  value       = var.create_sns_topic ? aws_sns_topic.pipeline_notifications[0].name : null
}

# GitHub Webhook Output (conditional)
output "github_webhook_url" {
  description = "GitHub webhook URL"
  value       = var.source_config.type == "GitHub" && var.github_webhook_secret != "" ? aws_codepipeline_webhook.github[0].url : null
}

# CloudWatch Event Rule Outputs (conditional)
output "pipeline_state_change_rule_arn" {
  description = "ARN of the pipeline state change CloudWatch event rule"
  value       = var.enable_pipeline_notifications ? aws_cloudwatch_event_rule.pipeline_state_change[0].arn : null
}

