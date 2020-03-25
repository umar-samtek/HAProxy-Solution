provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_instance_profile" "default" {
  name_prefix = var.name
  role        = aws_iam_role.default.name
}

resource "aws_iam_role" "default" {
  name_prefix        = var.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "default" {
  name_prefix = var.name
  description = "IAM Policy for S3 Access via HA Proxy"
  policy      = var.iam_policy
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

module "autoscaling" {
  source               = "terraform-aws-modules/autoscaling/aws"
  version              = "~> 3.0"
  iam_instance_profile = aws_iam_instance_profile.default.name
  target_group_arns    = [aws_lb_target_group.default.arn]

  name      = var.name
  key_name  = var.key_name
  lc_name   = var.name
  user_data = templatefile("${path.module}/files/userdata.tpl", { s3_bucket_endpoint = "${var.s3_bucket}.s3.amazonaws.com:443" })

  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.default.id]

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = var.ebs_block_size
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = var.root_block_size
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = var.name
  vpc_zone_identifier       = data.aws_subnet_ids.all.ids
  health_check_type         = "EC2"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = var.environment
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = var.name
      propagate_at_launch = true
    },
  ]
}

resource "aws_lb" "default" {
  name                       = var.name
  internal                   = true
  load_balancer_type         = "network"
  subnets                    = data.aws_subnet_ids.all.ids
  enable_deletion_protection = false
  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "default" {
  load_balancer_arn = aws_lb.default.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

resource "aws_lb_target_group" "default" {
  name        = var.name
  port        = 443
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group" "default" {
  name        = var.name
  description = "SG for HA proxy"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "All traffic from self"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow HTTPS traffic from Load Balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block] // hack! until https://github.com/terraform-providers/terraform-provider-aws/pull/2901 is merged, getting NLB IPs, is somewhat complex
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.us-east-1.s3"
}


resource "aws_vpc_endpoint_route_table_association" "ex1" {
  route_table_id  = data.aws_route_table.rt1.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "ex2" {
  route_table_id  = data.aws_route_table.rt2.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
