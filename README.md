# Terraform AWS CI/CD Module

A reusable Terraform module for creating AWS CI/CD pipelines with CodePipeline, CodeBuild, and flexible deployment options.

## Features

- **CodePipeline**: Orchestrates the CI/CD workflow
- **CodeBuild**: Builds and packages applications
- **Flexible Deployment**: Support for both CodeDeploy blue/green and standard ECS rolling deployments
- **S3 Artifacts Storage**: Secure storage for build artifacts
- **SNS Notifications**: Optional notifications for pipeline events
- **VPC Support**: Optional VPC configuration for CodeBuild
- **Multiple Source Types**: Support for GitHub (v1/v2) and S3 sources

## Usage

### Standard ECS Rolling Deployment

```hcl
module "cicd" {
  source = "github.com/Firecrown-Media/terraform-aws-cicd"

  # Basic configuration
  codepipeline_name      = "my-app-pipeline"
  codebuild_project_name = "my-app-build"
  artifacts_bucket_name  = "my-app-pipeline-artifacts"

  # Use standard ECS rolling deployment
  deployment_type = "ecs"

  # Source configuration (GitHub v2 recommended)
  source_config = {
    type                  = "GitHubV2"
    github_owner          = "my-org"
    github_repo           = "my-app"
    github_branch         = "main"
    github_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/xyz"
  }

  # Deploy configuration for ECS rolling deployment
  deploy_config = {
    provider = "ECS"
    configuration = {
      ClusterName = "my-ecs-cluster"
      ServiceName = "my-ecs-service"
    }
  }

  tags = {
    project     = "my-app"
    environment = "production"
  }
}
```

### CodeDeploy Blue/Green ECS Deployment

```hcl
module "cicd" {
  source = "github.com/Firecrown-Media/terraform-aws-cicd"

  # Basic configuration
  codepipeline_name      = "wordpress-pipeline"
  codebuild_project_name = "wordpress-build"
  artifacts_bucket_name  = "wordpress-pipeline-artifacts"

  # Use CodeDeploy for blue/green deployment
  deployment_type = "codedeploy"

  # Source configuration
  source_config = {
    type                  = "GitHubV2"
    github_owner          = "my-org"
    github_repo           = "my-wordpress-app"
    github_branch         = "main"
    github_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/xyz"
  }

  # Create CodeDeploy resources
  create_codedeploy_app            = true
  codedeploy_app_name             = "wordpress-app"
  codedeploy_deployment_group_name = "wordpress-deployment-group"
  codedeploy_compute_platform     = "ECS"
  codedeploy_deployment_type      = "BLUE_GREEN"

  # ECS configuration for CodeDeploy
  codedeploy_ecs_config = {
    cluster_name = "wordpress-cluster"
    service_name = "wordpress-service"
  }

  # Load balancer configuration for blue/green
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

  # Deploy configuration for CodeDeploy
  deploy_config = {
    provider = "CodeDeployToECS"
    configuration = {
      ApplicationName     = "wordpress-app"
      DeploymentGroupName = "wordpress-deployment-group"
    }
  }

  # Task role ARNs that CodeDeploy can pass to ECS
  codedeploy_task_role_arns = [
    "arn:aws:iam::123456789012:role/wordpress-task-role",
    "arn:aws:iam::123456789012:role/wordpress-execution-role"
  ]

  # Additional CodeBuild policies (for ECR access)
  codebuild_additional_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]

  tags = {
    project     = "wordpress"
    environment = "production"
    component   = "cicd"
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
    project = "my-app"
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
| deployment_type | Type of deployment: 'codedeploy' for blue/green or 'ecs' for rolling deployment | `string` | `"codedeploy"` | no |
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

The `deploy_config` variable supports different deployment providers based on the `deployment_type`:

### ECS Rolling Deployment
```hcl
deployment_type = "ecs"
deploy_config = {
  provider = "ECS"
  configuration = {
    ClusterName = "my-ecs-cluster"
    ServiceName = "my-ecs-service"
  }
}
```
**Note**: For ECS rolling deployments, your build process should generate an `imagedefinitions.json` file.

### CodeDeploy Blue/Green to ECS
```hcl
deployment_type = "codedeploy"
deploy_config = {
  provider = "CodeDeployToECS"
  configuration = {
    ApplicationName     = "my-app"
    DeploymentGroupName = "my-deployment-group"
  }
}
```
**Note**: For CodeDeploy blue/green deployments, your build process should generate `taskdef.json` and `appspec.yaml` files.

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