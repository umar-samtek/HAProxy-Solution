variable "s3_bucket" {
  default = "idr-haproxy-9ew9"

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
    values = ["idr-cloud-dev-data-a", "idr-cloud-dev-data-b"]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "IDR-Cloud-SG"
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
  iam_instance_profile = "s3-access-haproxy"

  name = "haproxy"
  key_name = "key-cms-idr-cloud"

  # Launch configuration
  #
  # launch_configuration = "my-existing-launch-configuration" # Use the existing launch configuration
  # create_lc = false # disables creation of launch configuration
  lc_name = "haproxy-lc"
  user_data = templatefile("${path.module}/files/userdata.tpl", { s3_bucket = "${var.s3_bucket}"})

  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [data.aws_security_group.default.id]
  # load_balancers  = [module.elb.this_elb_id]

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
############
resource "aws_lb" "idr-nlb-haproxy" {
  name               = "idr-nlb-haproxy"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.all.ids
  enable_deletion_protection = false
  tags = {
    Environment = "Dev"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.idr-nlb-haproxy.arn}"
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.idr-haproxy-nlbtg.arn}"
  }
}

## Target Group for ELB
resource "aws_lb_target_group" "idr-haproxy-nlbtg" {
  name        = "idr-haproxy"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
}

# ## Target Group ARN
# resource "aws_lb_target_group_attachment" "idr-haproxy-tgattachment" {
#   target_group_arn = "${aws_lb_target_group.idr-haproxy-nlbtg.arn}"
#   target_id        = module.example_asg.this_autoscaling_group_id
#   port             = 80
# }

# VPC Endpoint
############
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.us-east-1.s3"
}

data "aws_route_table" "rt1" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev-data-a"]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_route_table" "rt2" {
  filter {
    name = "tag:Name"
    values = ["idr-cloud-dev-data-b"]
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