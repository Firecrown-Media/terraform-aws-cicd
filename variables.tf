# Core Configuration Variables
variable "codepipeline_name" {
  description = "Name of the CodePipeline"
  type        = string
}

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "codebuild_description" {
  description = "Description of the CodeBuild project"
  type        = string
  default     = "Build project for CI/CD pipeline"
}

variable "artifacts_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  type        = string
}

# CodeBuild Configuration
variable "codebuild_compute_type" {
  description = "Compute type for CodeBuild"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"
  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM", 
      "BUILD_GENERAL1_LARGE",
      "BUILD_GENERAL1_2XLARGE"
    ], var.codebuild_compute_type)
    error_message = "CodeBuild compute type must be a valid value."
  }
}

variable "codebuild_image" {
  description = "Docker image for CodeBuild"
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "codebuild_privileged_mode" {
  description = "Enable privileged mode for CodeBuild (required for Docker builds)"
  type        = bool
  default     = true
}

variable "buildspec_path" {
  description = "Path to the buildspec file"
  type        = string
  default     = "buildspec.yml"
}

variable "codebuild_environment_variables" {
  description = "Environment variables for CodeBuild"
  type = list(object({
    name  = string
    value = string
    type  = optional(string, "PLAINTEXT")
  }))
  default = []
}

# VPC Configuration (optional)
variable "vpc_config" {
  description = "VPC configuration for CodeBuild"
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# Source Configuration
variable "source_config" {
  description = "Source configuration for the pipeline"
  type = object({
    type                     = string # "S3", "GitHub", or "GitHubV2"
    s3_bucket               = optional(string)
    s3_key                  = optional(string)
    github_owner            = optional(string)
    github_repo             = optional(string)
    github_branch           = optional(string, "main")
    github_oauth_token      = optional(string) # For GitHub v1 (deprecated)
    github_connection_arn   = optional(string) # For GitHub v2 (recommended)
  })
  
  validation {
    condition = contains(["S3", "GitHub", "GitHubV2"], var.source_config.type)
    error_message = "Source type must be either 'S3', 'GitHub', or 'GitHubV2'."
  }
}

variable "github_webhook_secret" {
  description = "Secret for GitHub webhook"
  type        = string
  default     = ""
  sensitive   = true
}

# Deployment Type Configuration
variable "deployment_type" {
  description = "Type of deployment: 'codedeploy' for blue/green or 'ecs' for rolling deployment"
  type        = string
  default     = "codedeploy"
  validation {
    condition     = contains(["codedeploy", "ecs"], var.deployment_type)
    error_message = "Deployment type must be either 'codedeploy' or 'ecs'."
  }
}

# Deploy Configuration
variable "deploy_config" {
  description = "Deploy configuration for the pipeline"
  type = object({
    provider      = string
    configuration = map(string)
  })
  default = {
    provider = "CodeDeployToECS"
    configuration = {}
  }
}

# CodeDeploy Configuration (optional)
variable "create_codedeploy_app" {
  description = "Whether to create CodeDeploy application and deployment group"
  type        = bool
  default     = false
}

variable "codedeploy_app_name" {
  description = "Name of the CodeDeploy application"
  type        = string
  default     = ""
}

variable "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  type        = string
  default     = ""
}

variable "codedeploy_compute_platform" {
  description = "Compute platform for CodeDeploy"
  type        = string
  default     = "ECS"
  validation {
    condition     = contains(["EC2", "Lambda", "ECS"], var.codedeploy_compute_platform)
    error_message = "CodeDeploy compute platform must be EC2, Lambda, or ECS."
  }
}

variable "codedeploy_deployment_config" {
  description = "Deployment configuration for CodeDeploy"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "codedeploy_deployment_type" {
  description = "Deployment type for CodeDeploy"
  type        = string
  default     = "BLUE_GREEN"
  validation {
    condition     = contains(["IN_PLACE", "BLUE_GREEN"], var.codedeploy_deployment_type)
    error_message = "Deployment type must be IN_PLACE or BLUE_GREEN."
  }
}

variable "codedeploy_deployment_option" {
  description = "Deployment option for CodeDeploy"
  type        = string
  default     = "WITH_TRAFFIC_CONTROL"
  validation {
    condition     = contains(["WITH_TRAFFIC_CONTROL", "WITHOUT_TRAFFIC_CONTROL"], var.codedeploy_deployment_option)
    error_message = "Deployment option must be WITH_TRAFFIC_CONTROL or WITHOUT_TRAFFIC_CONTROL."
  }
}

variable "codedeploy_termination_wait_time" {
  description = "Time in minutes to wait before terminating blue instances"
  type        = number
  default     = 5
  validation {
    condition     = var.codedeploy_termination_wait_time >= 0 && var.codedeploy_termination_wait_time <= 2880
    error_message = "Termination wait time must be between 0 and 2880 minutes."
  }
}

variable "codedeploy_container_name" {
  description = "Name of the container to update during CodeDeploy ECS deployment"
  type        = string
  default     = "app"
}

variable "codedeploy_auto_rollback_enabled" {
  description = "Enable auto rollback for CodeDeploy"
  type        = bool
  default     = true
}

variable "codedeploy_auto_rollback_events" {
  description = "Events that trigger auto rollback"
  type        = list(string)
  default     = ["DEPLOYMENT_FAILURE"]
}

variable "codedeploy_ecs_config" {
  description = "ECS configuration for CodeDeploy"
  type = object({
    cluster_name = string
    service_name = string
  })
  default = null
}

variable "codedeploy_load_balancer_info" {
  description = "Load balancer configuration for CodeDeploy"
  type = object({
    target_group_pair_info = object({
      prod_traffic_route = object({
        listener_arns = list(string)
      })
      target_groups = list(object({
        name = string
      }))
    })
  })
  default = null
}

# S3 Configuration
variable "artifacts_bucket_encryption_algorithm" {
  description = "Encryption algorithm for artifacts bucket"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.artifacts_bucket_encryption_algorithm)
    error_message = "Encryption algorithm must be AES256 or aws:kms."
  }
}

variable "artifacts_bucket_kms_key_id" {
  description = "KMS key ID for artifacts bucket encryption"
  type        = string
  default     = ""
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 30
}

variable "logs_kms_key_id" {
  description = "KMS key ID for CloudWatch logs encryption"
  type        = string
  default     = ""
}

# SNS Notifications
variable "create_sns_topic" {
  description = "Whether to create an SNS topic for notifications"
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "ARN of existing SNS topic for notifications"
  type        = string
  default     = ""
}

variable "enable_pipeline_notifications" {
  description = "Enable CloudWatch events and SNS notifications for pipeline state changes"
  type        = bool
  default     = false
}

# CodeBuild Additional Policies
variable "codebuild_additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to CodeBuild role"
  type        = list(string)
  default     = []
}

# CodeDeploy Task Role ARNs
variable "codedeploy_task_role_arns" {
  description = "List of task role ARNs that CodeDeploy can pass to ECS tasks"
  type        = list(string)
  default     = []
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}