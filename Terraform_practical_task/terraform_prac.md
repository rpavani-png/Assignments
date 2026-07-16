# Terraform Logic & Code Architecture Explainer

This document explains the technical details, logic, and design decisions behind the High-Availability (HA) web infrastructure implemented in this codebase.

---

## 1. Directory Structure and Module Segregation

The code is split into a **root module** and two **child modules**: `network` and `compute`.

```
terraform-aws-infra/
├── main.tf                 # Root module: orchestrates and links compute & network
├── variables.tf            # Global variables
├── outputs.tf              # Root-level outputs (Load Balancer DNS)
├── providers.tf            # Provider configuration & S3 backend definition
└── modules/
    ├── network/            # Subnets, VPC, Internet Gateway, Routing, LB Security Group
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── compute/            # VMs, AMIs, Target Groups, Launch Templates, ASG, ALB
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Why segregate network and compute?
* **Blast Radius Minimization**: Network resources (VPC, Subnets) change rarely and are highly critical. Compute resources (VMs, Launch Templates) change frequently during deployments. Segregating them prevents accidental modification or deletion of network resources when scaling or updating compute nodes.
* **Reusability**: The network module can be reused by other application stacks (databases, cache layers, etc.) without copying networking code.

---

## 2. Deep-Dive: Code Logic by Module

### A. The Network Module (`/modules/network/main.tf`)
This module creates the secure foundation for the infrastructure.

1. **Multi-AZ Availability**:
   We define two subnets (`aws_subnet.public_1` and `aws_subnet.public_2`) in different Availability Zones (`us-east-1a` and `us-east-1b`). This is a prerequisite for AWS Application Load Balancers, which require at least two subnets in separate AZs for redundancy.
2. **IGW and Routing**:
   An Internet Gateway (`aws_internet_gateway.gw`) is created and attached to the VPC. A route table (`aws_route_table.public`) directs all outbound traffic (`0.0.0.0/0`) to this gateway. Both subnets are associated with this route table, making them public.
3. **Firewall / Security Group Chaining**:
   * We define `aws_security_group.lb_sg`. It acts as a firewall for the public Load Balancer. It allows inbound traffic **only** on port `80` from `var.allowed_ip_range`.
   * It exposes its ID as an output (`lb_security_group_id`), which is passed to the compute module.

---

### B. The Compute Module (`/modules/compute/main.tf`)
This module manages the temporary VM, AMI baking, the Application Load Balancer, and the Auto Scaling Group.

#### 1. Security Group Chaining (The VM Firewall)
The VMs inside the scale set use `aws_security_group.vm_sg`. Look at this ingress rule:
```hcl
ingress {
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_groups = [var.lb_security_group_id]
}
```
* **No Inbound Internet Access**: Notice that `cidr_blocks` is not used. Instead, we use `security_groups = [var.lb_security_group_id]`.
* This tells AWS: *"Only allow incoming traffic on port 80 if it originates from resources associated with the Load Balancer's security group."*
* This is a fundamental cloud security pattern. It prevents attackers from bypassing the Load Balancer's firewall to target the VMs directly.

#### 2. The Custom AMI Baking Pattern (The Race Condition Fix)
The goal is to create a custom machine image (AMI) with Apache pre-installed.
```hcl
resource "aws_instance" "temp_vm" {
  ...
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
}
```
* **How cloud-init works**: When an EC2 instance launches, AWS runs the `user_data` script in the background during the boot phase. The AWS EC2 API reports the instance as `running` and "Created" immediately as the hardware is allocated, **long before** the shell script finishes executing `dnf install httpd`.
* **The Problem**: Without the sleep provisioner, Terraform would instantly proceed to create `aws_ami_from_instance.golden_image` from the VM. The AMI snapshot would be taken before Apache finished installing, leaving the AMI empty.
* **The Solution**: The `provisioner "local-exec"` block runs a local shell command on your machine executing Terraform. By sleeping for 120 seconds, we pause the Terraform deployment execution after creating the VM. This guarantees the VM completes its installation script before Terraform takes the AMI snapshot.

#### 3. Dynamic Hostname Substitution Logic
In the Launch Template (`aws_launch_template.asg_template`):
```hcl
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "<h1>Hello from HA Web Server: $(hostname -f)</h1>" | sudo tee /var/www/html/index.html
              EOF
  )
```
* **Why not escape `$`: `$(hostname -f)` vs `$$(hostname -f)`?**
  * In Terraform HCL, string interpolation uses the `${...}` format.
  * HCL does not recognize `$(...)` as interpolation. Therefore, Terraform treats `$(hostname -f)` as a literal string. It does not evaluate it locally.
  * When base64 encoded, the exact string `$(hostname -f)` is sent to the EC2 instances.
  * When the instance boots, bash runs the script. In bash, `$(hostname -f)` is a command substitution block. Bash executes the command `hostname -f` on the virtual machine and substitutes the output (e.g. `ip-10-0-1-114.ec2.internal`) into the HTML string, writing it to `index.html`.
  * **Note**: If we had written `$$(hostname -f)`, Terraform would output `$$(hostname -f)` verbatim (because no `${}` existed to trigger HCL's `$$` unescaping). Bash would then interpret `$$` as its current shell PID, resulting in a broken output like `5834(hostname -f)`.

#### 4. Auto-Triggering Rolling Updates (`instance_refresh`)
How do we ensure that updating our configuration automatically replaces the 3 running instances in the scale set?
```hcl
resource "aws_autoscaling_group" "asg" {
  ...
  launch_template {
    id      = aws_launch_template.asg_template.id
    version = aws_launch_template.asg_template.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }
}
```
* **Dynamic Version Reference**: Instead of passing `version = "$Latest"`, we reference `aws_launch_template.asg_template.latest_version`. When the launch template configuration updates, Terraform detects that `version` is changing from, say, `3` to `4`. This triggers an in-place update of the ASG.
* **Instance Refresh Execution**: Because `instance_refresh` is declared and triggered by the `launch_template` change, AWS ASG initiates a rolling update:
  1. It launches a new instance running version 4 of the launch template.
  2. It registers it with the target group and waits for it to pass health checks.
  3. Once healthy, it terminates one of the old version 3 instances.
  4. It repeats this process until all 3 running instances are replaced.
  5. The `min_healthy_percentage = 50` ensures that at least 2 instances remain healthy and serve traffic during the update, achieving zero-downtime deployment.

---

## 3. Remote State Backend Logic (`providers.tf`)

```hcl
  backend "s3" {
    bucket         = "rpavani-terraform-prac"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
```
* **The `tfstate` file**: Terraform records mapping between your code resources and real-world AWS infrastructure IDs inside a state file.
* **S3 Remote Backend**: Storing this file in an S3 bucket instead of locally ensures:
  * **Team Collaboration**: Everyone shares the same state data.
  * **Durability & Security**: State is encrypted in transit and at rest (`encrypt = true`), protecting sensitive data (like security group IDs or system configurations).
