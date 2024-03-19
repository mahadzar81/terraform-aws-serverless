resource "aws_key_pair" "auth_demo" {
  key_name   = "user_ssh_demo"
  public_key = file(var.key_pair_id)
}