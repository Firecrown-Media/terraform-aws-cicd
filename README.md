# Terraform AWS CI/CD Module

A reusable Terraform module for creating AWS CI/CD pipelines with CodePipeline, CodeBuild, and CodeDeploy.

## Features

- **CodePipeline**: Orchestrates the CI/CD workflow
- **CodeBuild**: Builds and packages applications
- **CodeDeploy**: Deploys applications (optional)
- **S3 Artifacts Storage**: Secure storage for build artifacts
- **SNS Notifications**: Optional notifications for pipeline events
- **VPC Support**: Optional VPC configuration for CodeBuild
- **Blue/Green Deployments**: Support for ECS blue/green deployments
- **Flexible Source**: Support for both GitHub and S3 sources

## Usage

### Basic Usage

```hcl
module "cicd" {
  source = "github.com/Firecrown-Media/terraform-aws-cicd"

  codepipeline_name       = "my-app-pipeline"
  codebuild_project_name  = "my-app-build"
  artifacts_bucket_name   = "my-app-pipeline-artifacts"

  source_config = {
    type          = "GitHub"
    github_owner  = "my-org"
    github_repo   = "my-app"
    github_branch = "main"
    github_oauth_token = var.github_oauth_token
  }

  deploy_config = {
    provider = "CodeDeployToECS"
    configuration = {
      ApplicationName     = "my-app"
      DeploymentGroupName = "my-app-dg"
      TaskDefinitionTemplateArtifact = "build_output"
      TaskDefinitionTemplatePath     = "taskdef.json"
      AppSpecTemplateArtifact        = "build_output"
      AppSpecTemplatePath           = "appspec.yaml"
    }
  }

  tags = {
    Project     = "my-app"
    Environment = "production"
  }
}
```

### With CodeDeploy Blue/Green ECS Deployment

```hcl
module "cicd" {
  source = "github.com/Firecrown-Media/terraform-aws-cicd"

  codepipeline_name       = "wordpress-pipeline"
  codebuild_project_name  = "wordpress-build"
  artifacts_bucket_name   = "wordpress-pipeline-artifacts"

  # CodeBuild configuration
  codebuild_environment_variables = [
    {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    },
    {
      name  = "ECR_REPOSITORY_URI"
      value = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app"
    }
  ]

  # VPC configuration for CodeBuild
  vpc_config = {
    vpc_id             = "vpc-12345678"
    subnets            = ["subnet-12345678", "subnet-87654321"]
    security_group_ids = ["sg-12345678"]
  }

  # Source configuration
  source_config = {
    type          = "GitHub"
    github_owner  = "my-org"
    github_repo   = "my-wordpress-app"
    github_branch = "main"
    github_oauth_token = var.github_oauth_token
  }

  # Create CodeDeploy resources
  create_codedeploy_app           = true
  codedeploy_app_name            = "wordpress-app"
  codedeploy_deployment_group_name = "wordpress-deployment-group"
  codedeploy_compute_platform    = "ECS"
  codedeploy_deployment_type     = "BLUE_GREEN"

  # ECS configuration for CodeDeploy
  codedeploy_ecs_config = {
    cluster_name = "wordpress-cluster"
    service_name = "wordpress-service"
  }

  # Load balancer configuration
  codedeploy_load_balancer_info = {
    target_group_pair_info = {
      prod_traffic_route = {
        listener_arns = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/f2f7dc8efc522ab2"]
      }
      target_groups = [
        { name = "wordpress-blue-tg" },
        { name = "wordpress-green-tg" }
      ]
    }
  }

  # Task role ARNs that CodeDeploy can pass to ECS
  codedeploy_task_role_arns = [
    "arn:aws:iam::123456789012:role/wordpress-task-role",
    "arn:aws:iam::123456789012:role/wordpress-execution-role"
  ]

  # Deploy configuration
  deploy_config = {
    provider = "CodeDeployToECS"
    configuration = {
      ApplicationName     = "wordpress-app"
      DeploymentGroupName = "wordpress-deployment-group"
      TaskDefinitionTemplateArtifact = "build_output"
      TaskDefinitionTemplatePath     = "taskdef.json"
      AppSpecTemplateArtifact        = "build_output"
      AppSpecTemplatePath           = "appspec.yaml"
    }
  }

  # SNS notifications
  enable_pipeline_notifications = true
  create_sns_topic = true
  sns_topic_name   = "wordpress-pipeline-notifications"

  # Additional CodeBuild policies (for ECR access)
  codebuild_additional_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]

  tags = {
    Project     = "wordpress"
    Environment = "production"
    Component   = "cicd"
  }
}
```

### With External SNS Topic

```hcl
module "cicd" {
  source = "github.com/Firecrown-Media/terraform-aws-cicd"

  codepipeline_name       = "my-app-pipeline"
  codebuild_project_name  = "my-app-build"
  artifacts_bucket_name   = "my-app-pipeline-artifacts"

  source_config = {
    type        = "S3"
    s3_bucket   = "my-source-bucket"
    s3_key      = "source.zip"
  }

  deploy_config = {
    provider = "S3"
    configuration = {
      BucketName = "my-deployment-bucket"
      Extract    = "true"
    }
  }

  # Use existing SNS topic
  enable_pipeline_notifications = true
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:existing-topic"

  tags = {
    Project = "my-app"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| codepipeline_name | Name of the CodePipeline | `string` | n/a | yes |
| codebuild_project_name | Name of the CodeBuild project | `string` | n/a | yes |
| artifacts_bucket_name | Name of the S3 bucket for pipeline artifacts | `string` | n/a | yes |
| source_config | Source configuration for the pipeline | `object` | n/a | yes |
| deploy_config | Deploy configuration for the pipeline | `object` | `{"provider": "CodeDeployToECS", "configuration": {}}` | no |
| codebuild_compute_type | Compute type for CodeBuild | `string` | `"BUILD_GENERAL1_MEDIUM"` | no |
| codebuild_image | Docker image for CodeBuild | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | no |
| codebuild_privileged_mode | Enable privileged mode for CodeBuild | `bool` | `true` | no |
| buildspec_path | Path to the buildspec file | `string` | `"buildspec.yml"` | no |
| codebuild_environment_variables | Environment variables for CodeBuild | `list(object)` | `[]` | no |
| vpc_config | VPC configuration for CodeBuild | `object` | `null` | no |
| create_codedeploy_app | Whether to create CodeDeploy application and deployment group | `bool` | `false` | no |
| enable_pipeline_notifications | Enable CloudWatch events and SNS notifications | `bool` | `false` | no |
| create_sns_topic | Whether to create an SNS topic for notifications | `bool` | `false` | no |
| sns_topic_arn | ARN of existing SNS topic for notifications | `string` | `""` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| codepipeline_name | Name of the CodePipeline |
| codepipeline_arn | ARN of the CodePipeline |
| codebuild_project_name | Name of the CodeBuild project |
| codebuild_project_arn | ARN of the CodeBuild project |
| artifacts_bucket_name | Name of the S3 bucket for artifacts |
| artifacts_bucket_arn | ARN of the S3 bucket for artifacts |
| codepipeline_role_arn | ARN of the CodePipeline service role |
| codebuild_role_arn | ARN of the CodeBuild service role |
| codedeploy_role_arn | ARN of the CodeDeploy service role |
| sns_topic_arn | ARN of the SNS topic for notifications |
| github_webhook_url | GitHub webhook URL |

## Source Configuration

The `source_config` variable supports two types of sources:

### GitHub Source
```hcl
source_config = {
  type               = "GitHub"
  github_owner       = "my-organization"
  github_repo        = "my-repository"
  github_branch      = "main"
  github_oauth_token = var.github_oauth_token
}
```

### S3 Source
```hcl
source_config = {
  type      = "S3"
  s3_bucket = "my-source-bucket"
  s3_key    = "path/to/source.zip"
}
```

## Deploy Configuration

The `deploy_config` variable is flexible and supports different deployment providers:

### CodeDeploy to ECS
```hcl
deploy_config = {
  provider = "CodeDeployToECS"
  configuration = {
    ApplicationName                = "my-app"
    DeploymentGroupName           = "my-deployment-group"
    TaskDefinitionTemplateArtifact = "build_output"
    TaskDefinitionTemplatePath     = "taskdef.json"
    AppSpecTemplateArtifact        = "build_output"
    AppSpecTemplatePath           = "appspec.yaml"
  }
}
```

### S3 Deployment
```hcl
deploy_config = {
  provider = "S3"
  configuration = {
    BucketName = "my-deployment-bucket"
    Extract    = "true"
  }
}
```

## SNS Notifications

The module supports SNS notifications for pipeline state changes:

- **Pipeline state changes**: Notifies when the pipeline starts, succeeds, or fails
- **Stage state changes**: Notifies when individual stages start, succeed, or fail

You can either create a new SNS topic using the module or use an existing one.

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0

## License

This module is released under the MIT License.