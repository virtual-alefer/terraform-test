provider "aws" {
    region = "us-east-2"
}

resource "aws_instance" "example" {
    ami           = "ami-0c55b159cbfafe1f0"
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

resource "aws_launch_configuration" "example" {
    name          = "example-launch-configuration"
    image_id      = "ami-0c55b159cbfafe1f0"
    instance_type  = "t2.micro"
    security_groups = [aws_security_group.instance.id]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    
}

resource "aws_autoscaling_group" "example" {
    name                      = "example-autoscaling-group"
    launch_configuration      = aws_launch_configuration.example.name
    min_size                  = 2
    max_size                  = 10
    vpc_zone_identifier       = [aws_subnet.example.id]
    health_check_type         = "EC2"
    health_check_grace_period = 300
    tag {
        key                 = "Name"
        value               = "ExampleAutoScalingGroup"
        propagate_at_launch = true
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
