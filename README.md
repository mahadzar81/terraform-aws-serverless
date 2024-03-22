# terraform-aws-serverless
Deploy demo app on AWS serverless by utilizing API gateway, python lambda function, and RDS resources

## Requirements
* Install terraform cli [terraform](https://www.hashicorp.com/blog/announcing-the-hashicorp-linux-repository) on Linux.
* Install AWS CLI [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install)
* Terraform Remote State Backend with AWS S3 and DynamoDB  [How to create a Terraform S3 backend](https://hackernoon.com/deploying-a-terraform-remote-state-backend-with-aws-s3-and-dynamodb)

## Steps

```
# terraform workspace new terraform-aws-serverless
# terraform workspace select terraform-aws-serverless
# terraform plan -var-file env/$(terraform workspace show).tfvars
# terraform apply -auto-approve -var-file env/$(terraform workspace show).tfvars
```

## Example Environment tfvars

```
region = "ap-southeast-1"
object_ownership = "BucketOwnerPreferred"
control_object_ownership = true
ami = "ami-066eeae61f083f121"
instance_type = "t2.micro"
db_name = "college"
db_username = "demoapp"
db_password = "<password>"
cognito_user = "<user>"
cognito_password = "<password>"
count_instance = 1
user = "admin"
key_pair_id = "~/.ssh/id_rsa.pub"
```
## To verify

Register cognito-idp admin credential permanently using AWS CLI

```
 aws cognito-idp admin-set-user-password --user-pool-id <region endpoint> --username <username> --password <credential> --permanent
```

To test calling API gateway, first we need to get Bearer access_token from AWS Cognito IDP by using curl command

```
 curl --request POST --url https://cognito-idp.<regions>.amazonaws.com/<region end point> --header 'content-type: application/x-amz-json-1.1' --header 'x-amz-target: AWSCognitoIdentityProviderService.InitiateAuth' --data '{ "AuthParameters" : {"USERNAME" : "<username>", "PASSWORD" : "password"},"AuthFlow" : "USER_PASSWORD_AUTH","ClientId" : "<client ID>"}'
```

Call AWS Gateway using curl command

```
curl -X GET https://<rest-api-id>.execute-api.<region>.amazonaws.com/<stage>/ \
-H 'authorization: Bearer <access_token>' \
-H 'content-type: application/json'
```

## Modules

| Name |
|------|
|[AWS API Gateway v2 (HTTP/Websocket) Terraform module](https://github.com/terraform-aws-modules/terraform-aws-apigateway-v2) |
|[AWS Lambda Terraform module](https://github.com/terraform-aws-modules/terraform-aws-lambda) |
|[AWS RDS Terraform module](https://github.com/terraform-aws-modules/terraform-aws-rds) |
|[AWS VPC Terraform module](https://github.com/terraform-aws-modules/terraform-aws-vpc) |
|[AWS S3 bucket Terraform module](https://github.com/terraform-aws-modules/terraform-aws-s3-bucket) |


## License

MIT / BSD

## Author Information
