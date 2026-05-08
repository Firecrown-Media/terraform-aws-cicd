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
<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.9.0 |

## Modules

## Modules

No modules.

## Resources

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.pipeline_state_change](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.pipeline_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.codedeploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_codebuild_project.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_codedeploy_app.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app) | resource |
| [aws_codedeploy_deployment_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group) | resource |
| [aws_codepipeline.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | resource |
| [aws_codepipeline_webhook.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline_webhook) | resource |
| [aws_iam_role.codebuild_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codedeploy_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.codepipeline_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codebuild_vpc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codedeploy_ecs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.codepipeline_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.codebuild_additional_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.codedeploy_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.codepipeline_additional_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.codepipeline_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.codepipeline_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.codepipeline_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.codepipeline_artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sns_topic.pipeline_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.pipeline_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifacts_bucket_encryption_algorithm"></a> [artifacts\_bucket\_encryption\_algorithm](#input\_artifacts\_bucket\_encryption\_algorithm) | Encryption algorithm for artifacts bucket | `string` | `"AES256"` | no |
| <a name="input_artifacts_bucket_kms_key_id"></a> [artifacts\_bucket\_kms\_key\_id](#input\_artifacts\_bucket\_kms\_key\_id) | KMS key ID for artifacts bucket encryption | `string` | `null` | no |
| <a name="input_artifacts_bucket_name"></a> [artifacts\_bucket\_name](#input\_artifacts\_bucket\_name) | Name of the S3 bucket for pipeline artifacts | `string` | n/a | yes |
| <a name="input_buildspec_path"></a> [buildspec\_path](#input\_buildspec\_path) | Path to the buildspec file | `string` | `"buildspec.yml"` | no |
| <a name="input_codebuild_additional_policy_arns"></a> [codebuild\_additional\_policy\_arns](#input\_codebuild\_additional\_policy\_arns) | List of additional IAM policy ARNs to attach to CodeBuild role | `list(string)` | `[]` | no |
| <a name="input_codebuild_compute_type"></a> [codebuild\_compute\_type](#input\_codebuild\_compute\_type) | Compute type for CodeBuild | `string` | `"BUILD_GENERAL1_MEDIUM"` | no |
| <a name="input_codebuild_description"></a> [codebuild\_description](#input\_codebuild\_description) | Description of the CodeBuild project | `string` | `"Build project for CI/CD pipeline"` | no |
| <a name="input_codebuild_environment_variables"></a> [codebuild\_environment\_variables](#input\_codebuild\_environment\_variables) | Environment variables for CodeBuild | <pre>list(object({<br>    name  = string<br>    value = string<br>    type  = optional(string, "PLAINTEXT")<br>  }))</pre> | `[]` | no |
| <a name="input_codebuild_image"></a> [codebuild\_image](#input\_codebuild\_image) | Docker image for CodeBuild | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | no |
| <a name="input_codebuild_privileged_mode"></a> [codebuild\_privileged\_mode](#input\_codebuild\_privileged\_mode) | Enable privileged mode for CodeBuild (required for Docker builds) | `bool` | `true` | no |
| <a name="input_codebuild_project_name"></a> [codebuild\_project\_name](#input\_codebuild\_project\_name) | Name of the CodeBuild project | `string` | n/a | yes |
| <a name="input_codedeploy_app_name"></a> [codedeploy\_app\_name](#input\_codedeploy\_app\_name) | Name of the CodeDeploy application | `string` | `null` | no |
| <a name="input_codedeploy_auto_rollback_enabled"></a> [codedeploy\_auto\_rollback\_enabled](#input\_codedeploy\_auto\_rollback\_enabled) | Enable auto rollback for CodeDeploy | `bool` | `true` | no |
| <a name="input_codedeploy_auto_rollback_events"></a> [codedeploy\_auto\_rollback\_events](#input\_codedeploy\_auto\_rollback\_events) | Events that trigger auto rollback | `list(string)` | <pre>[<br>  "DEPLOYMENT_FAILURE"<br>]</pre> | no |
| <a name="input_codedeploy_compute_platform"></a> [codedeploy\_compute\_platform](#input\_codedeploy\_compute\_platform) | Compute platform for CodeDeploy | `string` | `"ECS"` | no |
| <a name="input_codedeploy_container_name"></a> [codedeploy\_container\_name](#input\_codedeploy\_container\_name) | Name of the container to update during CodeDeploy ECS deployment | `string` | `"app"` | no |
| <a name="input_codedeploy_deployment_config"></a> [codedeploy\_deployment\_config](#input\_codedeploy\_deployment\_config) | Deployment configuration for CodeDeploy | `string` | `"CodeDeployDefault.ECSAllAtOnce"` | no |
| <a name="input_codedeploy_deployment_group_name"></a> [codedeploy\_deployment\_group\_name](#input\_codedeploy\_deployment\_group\_name) | Name of the CodeDeploy deployment group | `string` | `null` | no |
| <a name="input_codedeploy_deployment_option"></a> [codedeploy\_deployment\_option](#input\_codedeploy\_deployment\_option) | Deployment option for CodeDeploy | `string` | `"WITH_TRAFFIC_CONTROL"` | no |
| <a name="input_codedeploy_deployment_type"></a> [codedeploy\_deployment\_type](#input\_codedeploy\_deployment\_type) | Deployment type for CodeDeploy | `string` | `"BLUE_GREEN"` | no |
| <a name="input_codedeploy_ecs_config"></a> [codedeploy\_ecs\_config](#input\_codedeploy\_ecs\_config) | ECS configuration for CodeDeploy | <pre>object({<br>    cluster_name = string<br>    service_name = string<br>  })</pre> | `null` | no |
| <a name="input_codedeploy_load_balancer_info"></a> [codedeploy\_load\_balancer\_info](#input\_codedeploy\_load\_balancer\_info) | Load balancer configuration for CodeDeploy | <pre>object({<br>    target_group_pair_info = object({<br>      prod_traffic_route = object({<br>        listener_arns = list(string)<br>      })<br>      target_groups = list(object({<br>        name = string<br>      }))<br>    })<br>  })</pre> | `null` | no |
| <a name="input_codedeploy_task_role_arns"></a> [codedeploy\_task\_role\_arns](#input\_codedeploy\_task\_role\_arns) | List of task role ARNs that CodeDeploy can pass to ECS tasks | `list(string)` | `[]` | no |
| <a name="input_codedeploy_termination_wait_time"></a> [codedeploy\_termination\_wait\_time](#input\_codedeploy\_termination\_wait\_time) | Time in minutes to wait before terminating blue instances | `number` | `5` | no |
| <a name="input_codepipeline_additional_policy_arns"></a> [codepipeline\_additional\_policy\_arns](#input\_codepipeline\_additional\_policy\_arns) | List of additional IAM policy ARNs to attach to CodePipeline role | `list(string)` | `[]` | no |
| <a name="input_codepipeline_name"></a> [codepipeline\_name](#input\_codepipeline\_name) | Name of the CodePipeline | `string` | n/a | yes |
| <a name="input_create_codedeploy_app"></a> [create\_codedeploy\_app](#input\_create\_codedeploy\_app) | Whether to create CodeDeploy application and deployment group | `bool` | `false` | no |
| <a name="input_create_sns_topic"></a> [create\_sns\_topic](#input\_create\_sns\_topic) | Whether to create an SNS topic for notifications | `bool` | `false` | no |
| <a name="input_deploy_config"></a> [deploy\_config](#input\_deploy\_config) | Deploy configuration for the pipeline | <pre>object({<br>    provider      = string<br>    configuration = map(string)<br>  })</pre> | <pre>{<br>  "configuration": {},<br>  "provider": "CodeDeployToECS"<br>}</pre> | no |
| <a name="input_deployment_type"></a> [deployment\_type](#input\_deployment\_type) | Type of deployment: 'codedeploy' for blue/green or 'ecs' for rolling deployment | `string` | `"codedeploy"` | no |
| <a name="input_enable_pipeline_notifications"></a> [enable\_pipeline\_notifications](#input\_enable\_pipeline\_notifications) | Enable CloudWatch events and SNS notifications for pipeline state changes | `bool` | `false` | no |
| <a name="input_eventbridge_role_arn"></a> [eventbridge\_role\_arn](#input\_eventbridge\_role\_arn) | IAM role ARN for EventBridge to use when publishing to SNS topics | `string` | `null` | no |
| <a name="input_github_webhook_secret"></a> [github\_webhook\_secret](#input\_github\_webhook\_secret) | Secret for GitHub webhook (GitHub v1 only) | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch logs retention in days | `number` | `30` | no |
| <a name="input_logs_kms_key_id"></a> [logs\_kms\_key\_id](#input\_logs\_kms\_key\_id) | KMS key ID for CloudWatch logs encryption | `string` | `null` | no |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | ARN of existing SNS topic for notifications | `string` | `null` | no |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | Name of the SNS topic for notifications | `string` | `null` | no |
| <a name="input_source_config"></a> [source\_config](#input\_source\_config) | Source configuration for the pipeline | <pre>object({<br>    type                  = string # "S3", "GitHub", or "GitHubV2"<br>    s3_bucket             = optional(string)<br>    s3_key                = optional(string)<br>    github_owner          = optional(string)<br>    github_repo           = optional(string)<br>    github_branch         = optional(string, "main")<br>    github_oauth_token    = optional(string) # For GitHub v1 (deprecated)<br>    github_connection_arn = optional(string) # For GitHub v2 (recommended)<br>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | VPC configuration for CodeBuild | <pre>object({<br>    vpc_id             = string<br>    subnets            = list(string)<br>    security_group_ids = list(string)<br>  })</pre> | `null` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_artifacts_bucket_arn"></a> [artifacts\_bucket\_arn](#output\_artifacts\_bucket\_arn) | ARN of the S3 bucket for artifacts |
| <a name="output_artifacts_bucket_name"></a> [artifacts\_bucket\_name](#output\_artifacts\_bucket\_name) | Name of the S3 bucket for artifacts |
| <a name="output_codebuild_log_group_name"></a> [codebuild\_log\_group\_name](#output\_codebuild\_log\_group\_name) | Name of the CodeBuild CloudWatch log group |
| <a name="output_codebuild_project_arn"></a> [codebuild\_project\_arn](#output\_codebuild\_project\_arn) | ARN of the CodeBuild project |
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | Name of the CodeBuild project |
| <a name="output_codebuild_role_arn"></a> [codebuild\_role\_arn](#output\_codebuild\_role\_arn) | ARN of the CodeBuild service role |
| <a name="output_codedeploy_app_arn"></a> [codedeploy\_app\_arn](#output\_codedeploy\_app\_arn) | ARN of the CodeDeploy application |
| <a name="output_codedeploy_app_name"></a> [codedeploy\_app\_name](#output\_codedeploy\_app\_name) | Name of the CodeDeploy application |
| <a name="output_codedeploy_deployment_group_name"></a> [codedeploy\_deployment\_group\_name](#output\_codedeploy\_deployment\_group\_name) | Name of the CodeDeploy deployment group |
| <a name="output_codedeploy_log_group_name"></a> [codedeploy\_log\_group\_name](#output\_codedeploy\_log\_group\_name) | Name of the CodeDeploy CloudWatch log group |
| <a name="output_codedeploy_role_arn"></a> [codedeploy\_role\_arn](#output\_codedeploy\_role\_arn) | ARN of the CodeDeploy service role |
| <a name="output_codepipeline_arn"></a> [codepipeline\_arn](#output\_codepipeline\_arn) | ARN of the CodePipeline |
| <a name="output_codepipeline_name"></a> [codepipeline\_name](#output\_codepipeline\_name) | Name of the CodePipeline |
| <a name="output_codepipeline_role_arn"></a> [codepipeline\_role\_arn](#output\_codepipeline\_role\_arn) | ARN of the CodePipeline service role |
| <a name="output_github_webhook_url"></a> [github\_webhook\_url](#output\_github\_webhook\_url) | GitHub webhook URL |
| <a name="output_pipeline_state_change_rule_arn"></a> [pipeline\_state\_change\_rule\_arn](#output\_pipeline\_state\_change\_rule\_arn) | ARN of the pipeline state change CloudWatch event rule |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | ARN of the SNS topic for notifications |
| <a name="output_sns_topic_name"></a> [sns\_topic\_name](#output\_sns\_topic\_name) | Name of the SNS topic for notifications |
<!-- END_TF_DOCS -->