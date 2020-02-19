variable "s3_bucket" {
  default = "test-ha-proxy-bucket-gi-prod"

}

provider "aws" {
  region = "us-east-1"
}

##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "default" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev"]
  }
}

data "aws_subnet_ids" "all" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev-private-a", "idr-cloud-dev-private-b"]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "Snowflakesg"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["743302140042"] # Amazon

  filter {
    name = "name"

    values = [
      "amzn2-gi-*"
    ]
  }
}

######
# Launch configuration and autoscaling group
######
module "example_asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"


  name = "haproxy"
  key_name = "idr-haproxy-test-key"

  # Launch configuration
  #
  # launch_configuration = "my-existing-launch-configuration" # Use the existing launch configuration
  # create_lc = false # disables creation of launch configuration
  lc_name = "haproxy-lc"
  user_data = templatefile("${path.module}/files/userdata.tpl", { s3_bucket = "${var.s3_bucket}"})

  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [data.aws_security_group.default.id]
  load_balancers  = [module.elb.this_elb_id]

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "50"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = "haproxy-asg"
  vpc_zone_identifier       = data.aws_subnet_ids.all.ids
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 0
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "IDRCloud"
      propagate_at_launch = true
    },
  ]
}

######
# ELB
######
module "elb" {
  source = "terraform-aws-modules/elb/aws"

  name = "elb-example"

  subnets         = data.aws_subnet_ids.all.ids
  security_groups = [data.aws_security_group.default.id]
  internal        = true

  listener = [
    {
      instance_port     = "443"
      instance_protocol = "HTTP"
      lb_port           = "443"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = {
    target              = "HTTP:443/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}
############
# VPC Endpoint
############
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.us-east-1.s3"
}

data "aws_route_table" "rt1" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev-private-a"]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_route_table" "rt2" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev-private-b"]
  }
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_endpoint_route_table_association" "ex1" {
  route_table_id  = data.aws_route_table.rt1.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "ex2" {
  route_table_id  = data.aws_route_table.rt2.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}