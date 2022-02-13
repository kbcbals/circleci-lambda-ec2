terraform {
  required_version = ">= 0.12"
}


 variable "profile" {
  description = "Profile with permissions to provision the AWS resources."
  default     = "bala"
}

variable "region" {
  description = "Region to provision the resources into."
  default     = "eu-west-2"
}

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}




provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "hello_lambda.py"
  output_path = "hello_lambda.zip"
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_lambda_function" "lambda" {
  function_name = "hello_lambda"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.iam_for_lambda.arn
  handler = "hello_lambda.lambda_handler"
  runtime = "python3.6"

  environment {
    variables = {
      greeting = "Hello from the Great person!!!!!!"
    }
  }
}

 
resource "aws_cloudwatch_event_rule" "every_five_minutes" {
    name = "every-five-minutes"
    description = "Fires every five minutes"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_every_five_minutes" {
    rule = "${aws_cloudwatch_event_rule.every_five_minutes.name}"
    target_id = "lambda"
    arn = "${aws_lambda_function.lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_five_minutes.arn}"
}




module "networking" {
  source = "./networking"
  cidr   = "10.0.0.0/16"

  az-subnet-mapping = [
    {
      name = "subnet1"
      az   = "eu-west-2a"
      cidr = "10.0.0.0/24"
    },
    {
      name = "subnet2"
      az   = "eu-west-2c"
      cidr = "10.0.1.0/24"
    },
  ]
}

# Create a security group that will allow us to both
# SSH into the instance as well as access prometheus
# publicly (note.: you'd not do this in prod - otherwise
# you'd have prometheus publicly exposed).
resource "aws_security_group" "allow-ssh-and-egress" {
  name = "main"

  description = "Allows SSH traffic into instances as well as all eggress."
  vpc_id      = "${module.networking.vpc-id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh-all"
  }
}



/*
  provision an ec32 instance and will need to  trigger the circleci
*/

resource "aws_instance" "inst1" {
  instance_type = "t2.micro"
  ami           = "${data.aws_ami.ubuntu.id}"
  key_name      = "${aws_key_pair.main.id}"
  subnet_id     = "${module.networking.az-subnet-id-mapping["subnet1"]}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-ssh-and-egress.id}",
  ]

  provisioner "file" {
    source      = "script.sh"
    destination = "/root/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/script.sh",
      "/root/script.sh args",
    ]
  }
 


}


