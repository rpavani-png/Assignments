# Security Group for VMs (Allows traffic from the Load Balancer)
resource "aws_security_group" "vm_sg" {
  name   = "tf-vm-security-group"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Base image lookup for the temporary VM (Amazon Linux 2023)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# Step 1: Create the Temporary VM (Installs Apache baseline)
resource "aws_instance" "temp_vm" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.vm_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo dnf update -y
              sudo dnf install httpd -y
              echo "<h1>Hello from the Temporary VM Baseline</h1>" | sudo tee /var/www/html/index.html
              sudo systemctl enable httpd
              sudo systemctl start httpd
              EOF

  provisioner "local-exec" {
    command = "sleep 120"
  }

  tags = { Name = "tf-temporary-source-vm" }
}

# Step 2: Create a Custom Predefined Image from the Temporary VM
resource "aws_ami_from_instance" "golden_image" {
  name               = "tf-custom-apache-image-${aws_instance.temp_vm.id}"
  source_instance_id = aws_instance.temp_vm.id

  # Ensures the VM finishes booting and running the baseline user_data before baking the image
  depends_on = [aws_instance.temp_vm]
}

# Step 3: Application Load Balancer (External)
resource "aws_lb" "external_lb" {
  name               = "tf-external-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.lb_security_group_id]
  subnets            = var.public_subnets
}

# Target Group with Health Checks
resource "aws_lb_target_group" "tg" {
  name     = "tf-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "80"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# LB Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.external_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Step 4: Scale Set (Auto Scaling Group) of 3 instances
resource "aws_launch_template" "asg_template" {
  name_prefix   = "tf-web-template-"
  image_id      = aws_ami_from_instance.golden_image.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.vm_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "<h1>Hello from HA Web Server: $(hostname -f)</h1>" | sudo tee /var/www/html/index.html
              EOF
  )
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 3
  max_size            = 3
  min_size            = 3
  vpc_zone_identifier = var.public_subnets
  target_group_arns   = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.asg_template.id
    version = aws_launch_template.asg_template.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "tf-scale-set-instance"
    propagate_at_launch = true
  }
}
