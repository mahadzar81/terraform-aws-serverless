variable "ami" {
  type    = string
  default = null
}
variable "region" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}
variable "cognito_user" {
  type = string
}
variable "cognito_password" {
  type = string
}
variable "command" {
  description = "Run initial command during initial bootstrap"
  type    = list(string)
}
variable "count_instance" {
  type = number
}
variable "key_pair_id" {
  type = string
}
variable "user" {
  type = string
}
variable "private_key" {
  description = "ssh user private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}
variable "create_routes_and_integrations" {
  description = "Whether to create routes and integrations resources"
  type        = bool
  default     = true
}
variable "object_ownership" {
  description = "Object ownership. Valid values: BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter. 'BucketOwnerEnforced': ACLs are disabled, and the bucket owner automatically owns and has full control over every object in the bucket. 'BucketOwnerPreferred': Objects uploaded to the bucket change ownership to the bucket owner if the objects are uploaded with the bucket-owner-full-control canned ACL. 'ObjectWriter': The uploading account will own the object if the object is uploaded with the bucket-owner-full-control canned ACL."
  type        = string
  default     = "BucketOwnerPreferred"
}
variable "control_object_ownership" {
  description = "Whether to manage S3 Bucket Ownership Controls on this bucket."
  type        = bool
  default     = false
}






