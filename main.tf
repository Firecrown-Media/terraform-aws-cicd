# AWS CI/CD Module for ECS Blue/Green Deployments
# Reusable Terraform module for CodePipeline, CodeBuild, and CodeDeploy

# CodeBuild Project
resource "aws_codebuild_project" "main" {
  name          = var.codebuild_project_name
  description   = var.codebuild_description
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                      = var.codebuild_image
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = var.codebuild_privileged_mode

    dynamic "environment_variable" {
      for_each = var.codebuild_environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = lookup(environment_variable.value, "type", "PLAINTEXT")
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      vpc_id = vpc_config.value.vpc_id
      subnets = vpc_config.value.subnets
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(var.tags, {
    Name      = var.codebuild_project_name
    Component = "cicd"
  })
}

# S3 Bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = var.artifacts_bucket_name

  tags = merge(var.tags, {
    Name      = var.artifacts_bucket_name
    Component = "cicd"
  })
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.artifacts_bucket_encryption_algorithm
      kms_master_key_id = var.artifacts_bucket_kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CodePipeline
resource "aws_codepipeline" "main" {
  name     = var.codepipeline_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  # Source Stage
  stage {
    name = "Source"

    dynamic "action" {
      for_each = var.source_config.type == "S3" ? [1] : []
      content {
        name             = "Source"
        category         = "Source"
        owner            = "AWS"
        provider         = "S3"
        version          = "1"
        output_artifacts = ["source_output"]

        configuration = {
          S3Bucket    = var.source_config.s3_bucket
          S3ObjectKey = var.source_config.s3_key
        }
      }
    }

    dynamic "action" {
      for_each = var.source_config.type == "GitHub" ? [1] : []
      content {
        name             = "Source"
        category         = "Source"
        owner            = "ThirdParty"
        provider         = "GitHub"
        version          = "1"
        output_artifacts = ["source_output"]

        configuration = {
          Owner      = var.source_config.github_owner
          Repo       = var.source_config.github_repo
          Branch     = var.source_config.github_branch
          OAuthToken = var.source_config.github_oauth_token
        }
      }
    }
  }

  # Build Stage
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  # Deploy Stage
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = var.deploy_config.provider
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = var.deploy_config.configuration
    }
  }

  tags = merge(var.tags, {
    Name      = var.codepipeline_name
    Component = "cicd"
  })
}

# Optional GitHub webhook
resource "aws_codepipeline_webhook" "github" {
  count           = var.source_config.type == "GitHub" && var.github_webhook_secret != "" ? 1 : 0
  name            = "${var.codepipeline_name}-webhook"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.main.name

  authentication_configuration {
    secret_token = var.github_webhook_secret
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.source_config.github_branch}"
  }

  tags = merge(var.tags, {
    Name      = "${var.codepipeline_name}-webhook"
    Component = "cicd"
  })
}

# CodeDeploy Application (optional)
resource "aws_codedeploy_app" "main" {
  count            = var.create_codedeploy_app ? 1 : 0
  compute_platform = var.codedeploy_compute_platform
  name             = var.codedeploy_app_name

  tags = merge(var.tags, {
    Name      = var.codedeploy_app_name
    Component = "cicd"
  })
}

# CodeDeploy Deployment Group (optional)
resource "aws_codedeploy_deployment_group" "main" {
  count                 = var.create_codedeploy_app ? 1 : 0
  app_name              = aws_codedeploy_app.main[0].name
  deployment_group_name = var.codedeploy_deployment_group_name
  service_role_arn      = aws_iam_role.codedeploy_role[0].arn

  deployment_config_name = var.codedeploy_deployment_config

  deployment_style {
    deployment_type   = var.codedeploy_deployment_type
    deployment_option = var.codedeploy_deployment_option
  }

  dynamic "blue_green_deployment_config" {
    for_each = var.codedeploy_deployment_type == "BLUE_GREEN" ? [1] : []
    content {
      terminate_blue_instances_on_deployment_success {
        action                         = "TERMINATE"
        termination_wait_time_in_minutes = var.codedeploy_termination_wait_time
      }

      deployment_ready_option {
        action_on_timeout = "CONTINUE_DEPLOYMENT"
      }
    }
  }

  dynamic "ecs_service" {
    for_each = var.codedeploy_ecs_config != null ? [var.codedeploy_ecs_config] : []
    content {
      cluster_name = ecs_service.value.cluster_name
      service_name = ecs_service.value.service_name
    }
  }

  dynamic "load_balancer_info" {
    for_each = var.codedeploy_load_balancer_info != null ? [var.codedeploy_load_balancer_info] : []
    content {
      dynamic "target_group_pair_info" {
        for_each = load_balancer_info.value.target_group_pair_info != null ? [load_balancer_info.value.target_group_pair_info] : []
        content {
          dynamic "prod_traffic_route" {
            for_each = target_group_pair_info.value.prod_traffic_route != null ? [target_group_pair_info.value.prod_traffic_route] : []
            content {
              listener_arns = prod_traffic_route.value.listener_arns
            }
          }
          
          dynamic "target_group" {
            for_each = target_group_pair_info.value.target_groups
            content {
              name = target_group.value.name
            }
          }
        }
      }
    }
  }

  auto_rollback_configuration {
    enabled = var.codedeploy_auto_rollback_enabled
    events  = var.codedeploy_auto_rollback_events
  }

  tags = merge(var.tags, {
    Name      = var.codedeploy_deployment_group_name
    Component = "cicd"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.codebuild_project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_id != "" ? var.logs_kms_key_id : null

  tags = merge(var.tags, {
    Name      = "${var.codebuild_project_name}-logs"
    Component = "cicd"
  })
}

resource "aws_cloudwatch_log_group" "codedeploy" {
  count             = var.create_codedeploy_app ? 1 : 0
  name              = "/aws/codedeploy/${var.codedeploy_app_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_id != "" ? var.logs_kms_key_id : null

  tags = merge(var.tags, {
    Name      = "${var.codedeploy_app_name}-logs"
    Component = "cicd"
  })
}

# Optional SNS Topic for pipeline notifications
resource "aws_sns_topic" "pipeline_notifications" {
  count = var.create_sns_topic ? 1 : 0
  name  = var.sns_topic_name

  tags = merge(var.tags, {
    Name      = var.sns_topic_name
    Component = "cicd"
  })
}

# CloudWatch Event Rule for pipeline state changes
resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  count       = var.enable_pipeline_notifications ? 1 : 0
  name        = "${var.codepipeline_name}-state-change"
  description = "Capture pipeline state changes"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.main.name]
    }
  })

  tags = merge(var.tags, {
    Name      = "${var.codepipeline_name}-state-change"
    Component = "cicd"
  })
}

# CloudWatch Event Rule for stage state changes
resource "aws_cloudwatch_event_rule" "stage_state_change" {
  count       = var.enable_pipeline_notifications ? 1 : 0
  name        = "${var.codepipeline_name}-stage-state-change"
  description = "Capture pipeline stage state changes"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Stage Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.main.name]
    }
  })

  tags = merge(var.tags, {
    Name      = "${var.codepipeline_name}-stage-state-change"
    Component = "cicd"
  })
}

# SNS Topic targets for notifications
resource "aws_cloudwatch_event_target" "pipeline_sns" {
  count     = var.enable_pipeline_notifications && var.sns_topic_arn != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.pipeline_state_change[0].name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      pipeline = "$.detail.pipeline"
      state    = "$.detail.state"
      region   = "$.region"
      time     = "$.time"
    }
    input_template = <<EOF
{
  "pipeline": "<pipeline>",
  "state": "<state>",
  "region": "<region>",
  "time": "<time>",
  "message": "Pipeline <pipeline> is now in <state> state"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "stage_sns" {
  count     = var.enable_pipeline_notifications && var.sns_topic_arn != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.stage_state_change[0].name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      pipeline = "$.detail.pipeline"
      stage    = "$.detail.stage"
      state    = "$.detail.state"
      region   = "$.region"
      time     = "$.time"
    }
    input_template = <<EOF
{
  "pipeline": "<pipeline>",
  "stage": "<stage>",
  "state": "<state>",
  "region": "<region>",
  "time": "<time>",
  "message": "Pipeline <pipeline> stage <stage> is now in <state> state"
}
EOF
  }
}