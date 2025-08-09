# IAM Roles and Policies for CI/CD Pipeline

# CodePipeline Service Role
resource "aws_iam_role" "codepipeline_role" {
  name_prefix = "${substr(var.codepipeline_name, 0, 32)}-pipeline-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.codepipeline_name}-pipeline-role"
    Component = "cicd"
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name_prefix = "${substr(var.codepipeline_name, 0, 32)}-pipeline-"
  role        = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.main.arn
      }
    ], var.create_codedeploy_app ? [
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      }
    ] : [])
  })
}

# CodeBuild Service Role
resource "aws_iam_role" "codebuild_role" {
  name_prefix = "${substr(var.codebuild_project_name, 0, 32)}-build-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.codebuild_project_name}-build-role"
    Component = "cicd"
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name_prefix = "${substr(var.codebuild_project_name, 0, 32)}-build-"
  role        = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.codebuild.arn,
          "${aws_cloudwatch_log_group.codebuild.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# VPC-specific policies for CodeBuild (when VPC is configured)
resource "aws_iam_role_policy" "codebuild_vpc_policy" {
  count       = var.vpc_config != null ? 1 : 0
  name_prefix = "${substr(var.codebuild_project_name, 0, 32)}-vpc-"
  role        = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "arn:aws:ec2:*:*:network-interface/*"
        Condition = {
          StringEquals = {
            "ec2:Subnet" = [for subnet in var.vpc_config.subnets : "arn:aws:ec2:*:*:subnet/${subnet}"]
          }
        }
      }
    ]
  })
}

# Additional CodeBuild policies can be attached via this policy attachment
resource "aws_iam_role_policy_attachment" "codebuild_additional_policies" {
  for_each   = toset(var.codebuild_additional_policy_arns)
  role       = aws_iam_role.codebuild_role.name
  policy_arn = each.value
}

# CodeDeploy Service Role (optional)
resource "aws_iam_role" "codedeploy_role" {
  count       = var.create_codedeploy_app ? 1 : 0
  name_prefix = "${substr(var.codedeploy_app_name, 0, 32)}-deploy-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.codedeploy_app_name}-deploy-role"
    Component = "cicd"
  })
}

# Attach AWS managed policy for CodeDeploy based on compute platform
resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  count      = var.create_codedeploy_app ? 1 : 0
  policy_arn = local.codedeploy_managed_policy_arn
  role       = aws_iam_role.codedeploy_role[0].name
}

# Additional CodeDeploy policy for ECS Blue/Green deployments
resource "aws_iam_role_policy" "codedeploy_ecs_policy" {
  count       = var.create_codedeploy_app && var.codedeploy_compute_platform == "ECS" ? 1 : 0
  name_prefix = "${substr(var.codedeploy_app_name, 0, 32)}-ecs-"
  role        = aws_iam_role.codedeploy_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateTaskSet",
          "ecs:DeleteTaskSet",
          "ecs:DescribeServices",
          "ecs:UpdateServicePrimaryTaskSet",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "lambda:InvokeFunction",
          "cloudwatch:DescribeAlarms",
          "sns:Publish",
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ], length(var.codedeploy_task_role_arns) > 0 ? [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.codedeploy_task_role_arns
      }
    ] : [])
  })
}

# SNS Topic Policy (if SNS notifications are enabled)
resource "aws_sns_topic_policy" "pipeline_notifications" {
  count = var.enable_pipeline_notifications && var.create_sns_topic ? 1 : 0
  arn   = aws_sns_topic.pipeline_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.pipeline_notifications[0].arn
      }
    ]
  })
}

# Local values for IAM policy ARNs
locals {
  codedeploy_managed_policy_arn = {
    "EC2"    = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
    "Lambda" = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
    "ECS"    = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  }[var.codedeploy_compute_platform]
}