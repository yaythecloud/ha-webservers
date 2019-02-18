resource "aws_key_pair" "example-keypair2" {
  key_name = "${var.aws_key_name}"
  public_key = "${file(var.public_key)}"
}
