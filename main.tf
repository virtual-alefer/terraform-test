provider "aws" {
    region = "us-east-2"
}

resource "aws_instance" "example" {
    ami           = "ami-0e3664fd55710525b"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
        user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    user_data_replace_on_change = true
    tags = {
        Name = "ExampleInstance"
    }
}

resource "aws_security_group" "instance" {
    name        = "terraform-example-instance"
    description = "Allow HTTP traffic on port ${var.server_port}"

    ingress {
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_template" "example" {
    name          = "example-launch-template"
    image_id      = "ami-0e3664fd55710525b"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
    user_data = base64encode(<<-EOF
                #!/bin/bash
                echo "Hello, World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    )
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_autoscaling_group" "example" {
    name                      = "example-autoscaling-group"
    min_size                  = 2
    max_size                  = 10
    health_check_type         = "ELB"
    vpc_zone_identifier       = data.aws_subnets.default.ids

    launch_template {
        id      = aws_launch_template.example.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "ExampleAutoScalingGroup"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_lb" "example" {
    name               = "terraform-asg-lb"
    load_balancer_type = "application"
    subnets            = data.aws_subnets.default.ids
    security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "fixed-response"
        
        fixed_response {
            content_type = "text/plain"
            message_body = "404 Not Found"
            status_code  = "404"
        }
    }
}

resource "aws_security_group" "alb" {
    name        = "terraform-example-alb"
    description = "Allow HTTP traffic on port ${var.server_port}"

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "asg" {
    name     = "example-target-group"
    port     = var.server_port
    protocol = "HTTP"
    vpc_id   = data.aws_vpc.default.id

    health_check {
        path                = "/"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200-299"
    }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority     = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}










variable "number_example" {
    description = "An example number variable"
    type    = number
    default = 43
}

variable "list_example" {
    description = "An example list variable"
    type    = list(string)
    default = ["item1", "item2", "item3"]
}

variable "list_metrics_example" {
  description = "An example list of numeric list in Terraform"
  type = list(number)
  default = [1, 2, 3]
}

variable "map_example" {
    description = "An example map variable"
    type    = map(string)
    default = {
        key1 = "value1",
        key2 = "value2",
        key3 = "value3"
    }
}

variable "object_example" {
    description = "An example object variable"
    type = object({
        name = string
        age  = number
    })
    default = {
        name = "John Doe"
        age  = 30
    }
}

variable "server_port" {
    description = "The port on which the server will listen"
    type        = number
    default     = 8080
}

output "instance_public_ip" {
    value = aws_instance.example.public_ip
    description = "The public IP address of the example instance"
}
