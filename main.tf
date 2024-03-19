provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "maza-remote-state-storage-s3"
    region         = "ap-southeast-1"
    key            = "infrastructure/tfremote/terraform.tfstate"
    dynamodb_table = "terraform-state-lock-dynamo"
  }
}

data "aws_availability_zones" "available" {}

locals {
  name   = "demo-aws-lambda"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  domain_name = "terraform-aws-modules.modules.tf" # trimsuffix(data.aws_route53_zone.this.name, ".")
  subdomain   = "complete-http"

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-rds"
  }
}

################################################################################
# ec2 jump node
################################################################################

resource "aws_instance" "ec2-jump-node"  {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.auth_demo.key_name
  subnet_id = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group_ssh.security_group_id]
  
  associate_public_ip_address = true
  source_dest_check           = false
  count   = var.count_instance

  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_size           = "30"
    volume_type           = "standard"
    delete_on_termination = true
  }

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ec2-instance"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    private_key = file(var.private_key)
    user        = var.user
    # timeout     = "15m"
  }
  # install mysql-client on jump nodes
  provisioner "remote-exec" {
    inline = var.command
    on_failure = continue

  }
}

##################
# Extra resources
##################

resource "random_pet" "this" {
  length = 2
}

resource "aws_cloudwatch_log_group" "logs" {
  name = random_pet.this.id
}

################################################################################
# HTTP API Gateway
################################################################################

module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  name          = "demo-aws-lambda-http-API"
  description   = "HTTP API Gateway Integrate with AWS Lambda"
  protocol_type = "HTTP"
  #domain_name   = local.domain_name
  # domain_name_certificate_arn = module.acm.acm_certificate_arn
  create_api_domain_name = false
  create_routes_and_integrations = true

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.logs.arn
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"
  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 100
  }

  integrations = {

    "POST /demo-aws-lambda" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      authorization_type     = "JWT"
      authorizer_key         = "cognito"
      authorizer_id            = aws_apigatewayv2_authorizer.some_authorizer.id
      #authorization_scopes   = "tf/something.relevant.read,tf/something.relevant.write" # Should comply with the resource server configuration part of the cognito user pool
    }
     "$default" = {
      lambda_arn = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      authorization_type     = "JWT"
      authorizer_key         = "cognito"
      authorizer_id            = aws_apigatewayv2_authorizer.some_authorizer.id
      #authorization_scopes   = "tf/something.relevant.read,tf/something.relevant.write"
    }
  }
}

#############################
# AWS API Gateway Authorizer
#############################

resource "aws_apigatewayv2_authorizer" "some_authorizer" {
  api_id           = module.api_gateway.apigatewayv2_api_id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = random_pet.this.id

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.client.id]
    issuer   = "https://${aws_cognito_user_pool.this.endpoint}"
  }
}

########################
# AWS Cognito User Pool
########################

resource "aws_cognito_user_pool" "this" {
  name = "user-pool-${random_pet.this.id}"

   schema {
    name                     = "terraform"
    attribute_data_type      = "Boolean"
    mutable                  = false
    required                 = false
    developer_only_attribute = false
  }

  schema {
    name                     = "foo"
    attribute_data_type      = "String"
    mutable                  = false
    required                 = false
    developer_only_attribute = false
    string_attribute_constraints {}
  }
}
resource "aws_cognito_user" "example" {
  user_pool_id = aws_cognito_user_pool.this.id
  username = var.cognito_user
  password = var.cognito_password

  attributes = {
    terraform      = true
    foo            = "bar"
    email          = "email@gmail.com"
    email_verified = true
  }
}
resource "aws_cognito_user_pool_client" "client" {
  name = "demo-aws-lambda-http-API"

  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret     = false
  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
}

################################################################################
# Lambda Module
################################################################################

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  function_name = "demo-aws-lambda"
  description   = "My awesome lambda function"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  architectures = ["x86_64"]
  publish        = true

  create_package         = false
  local_existing_package = "app-demo_package.zip"
  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }
 
  create_lambda_function_url = true
  authorization_type         = "NONE"
  cors = {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
  invoke_mode = "BUFFERED"

  vpc_subnet_ids                     = module.vpc.private_subnets
  vpc_security_group_ids             = [module.security_group_ssh.security_group_id]
  attach_network_policy              = true
  replace_security_groups_on_destroy = true
  replacement_security_group_ids     =[module.security_group_ssh.security_group_id]
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  identifier = local.name

  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine               = "mysql"
  engine_version       = "8.0.35"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
 #instance_class       = "db.t4g.large"
  instance_class       = "db.m5d.large"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  manage_master_user_password = false
  port     = 3306

  # S3 import https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Procedural.Importing.html
  s3_import = {
    source_engine_version = "8.0.35"
    bucket_name           = module.import_s3_bucket.s3_bucket_id
    ingestion_role        = aws_iam_role.s3_import.arn
  }

  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["audit", "general"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "S3 import VPC example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_self = [
    {
      rule        = "https-443-tcp"
      description = "Allow all internal HTTPs"
    },
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  # egress
  computed_egress_with_self = [
    {
      rule        = "https-443-tcp"
      description = "Allow all internal HTTPs"
    },
  ]
  number_of_computed_egress_with_self = 1

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
  
  tags = local.tags
}

module "security_group_ssh" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Allow ssh, ICMP, HTTP access for All"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp", "ssh-tcp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

module "import_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix = "${local.name}-"
  object_ownership = var.object_ownership
  control_object_ownership  = var.control_object_ownership 
  acl           = "private"
  force_destroy = true

  tags = local.tags
}

data "aws_iam_policy_document" "s3_import_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_import" {
  name_prefix           = "${local.name}-"
  description           = "IAM role to allow RDS to import MySQL backup from S3"
  assume_role_policy    = data.aws_iam_policy_document.s3_import_assume.json
  force_detach_policies = true

  tags = local.tags
}

data "aws_iam_policy_document" "s3_import" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
      module.import_s3_bucket.s3_bucket_arn
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${module.import_s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "s3_import" {
  name_prefix = "${local.name}-"
  role        = aws_iam_role.s3_import.id
  policy      = data.aws_iam_policy_document.s3_import.json

  # We need the files uploaded before the RDS instance is created, and the instance
  # also needs this role so this is an easy way of ensuring the backup is uploaded before
  # the instance creation starts
  provisioner "local-exec" {
    command = "tar -xzvf college.tar.gz && aws s3 sync ${path.module}/college s3://${module.import_s3_bucket.s3_bucket_id}"
  }
}