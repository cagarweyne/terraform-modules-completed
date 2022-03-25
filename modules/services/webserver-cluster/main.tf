locals {
	http_port 		= 80
  any_port 			= 0
  any_protocol 	= "-1"
  tcp_protocol  = "tcp"
  all_ips				= ["0.0.0.0/0"]
}

variable "server_port" {
  description = "The port the server will be listening on"
  default = 8080
  type = number
}

resource "aws_security_group" "instance" {

  name = "${var.cluster_name}-instance"

  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_launch_configuration" "example" {
  image_id = "ami-0baa981b80a5a70f1"
  instance_type = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

  lifecycle {
    create_before_destroy = true 
  }
}

# get the details of default vpc
data "aws_vpc" "default" {
  default = true 
}

# use the default vpc id and get the default subnets ids
data "aws_subnet_ids" "default_subnet_ids" {
  vpc_id = data.aws_vpc.default.id 
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  # use the default sibnet ids
  vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size 

  tag {
    key = "Name"
    value = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"

  ingress {
    from_port = local.http_port
    to_port = local.http_port 
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  egress {
    from_port = local.any_port
    to_port = local.any_port
    protocol = local.any_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_lb" "example" {
  name = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default_subnet_ids.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn 
  port = local.http_port
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {
  name = "${var.cluster_name}-target-group"

  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 1

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}
