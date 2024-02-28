# terraform-aws-serverless
Deploy demo app on AWS serverless by utilizing API gateway, python lambda function, and RDS resources

## Requirements
Install terraform cli [terraform](https://www.hashicorp.com/blog/announcing-the-hashicorp-linux-repository) on Linux.
Install AWS CLI [AWS CLI] (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install)

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

## License

MIT / BSD

## Author Information
