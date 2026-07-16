# AWS Infrastructure Components & Terraform Resources

This document lists all the AWS services, specific resources, their Terraform identifiers, and the **exact resource IDs / Names** currently active in the AWS Console.

> [!IMPORTANT]
> **AWS Region Context**: 
> * The **infrastructure resources** (VPC, EC2, Load Balancer, etc.) are deployed in the **N. Virginia (`us-east-1`)** region. You must switch your AWS Console region to `us-east-1` to view them.
> * The **Terraform Remote State S3 Bucket** is located in the **Mumbai (`ap-south-1`)** region.

---

## 1. Core Services Summary
The infrastructure leverages the following native AWS Services:
* **Amazon VPC (Virtual Private Cloud):** Networking isolation, subnets, and routing.
* **Amazon EC2 (Elastic Compute Cloud):** Virtual servers, custom AMIs, and Launch Templates.
* **Amazon EC2 Auto Scaling:** Scale set orchestration maintaining exactly 3 instances.
* **Elastic Load Balancing (ALB):** Application Load Balancer, listeners, and target groups.
* **Amazon S3 (Simple Storage Service):** Remote state storage backend for Terraform.

---

## 2. Detailed Resource Inventory

### A. Network Layer (VPC Service - Network Module: `modules/network`)
| AWS Component | Console Name / Tag | Exact Resource ID | Terraform Identifier |
| :--- | :--- | :--- | :--- |
| **VPC** | `tf-vpc` (CIDR: `10.0.0.0/16`) | `vpc-011ea1edd4ce78747` | `aws_vpc.main` |
| **Public Subnet 1** | `tf-public-1` (AZ: `us-east-1a`) | `subnet-04a3190905e77c60e` | `aws_subnet.public_1` |
| **Public Subnet 2** | `tf-public-2` (AZ: `us-east-1b`) | `subnet-0c8413e8d0617153c` | `aws_subnet.public_2` |
| **Internet Gateway** | `tf-igw` | `igw-01e5c6e6810d6d9b3` | `aws_internet_gateway.gw` |
| **Route Table** | `tf-public-rt` | `rtb-057ad1c8a0c40010d` | `aws_route_table.public` |
| **Route Table Assoc 1** | Links Subnet 1 to Route Table | `rtbassoc-0e2cd47a1ac4a5715` | `aws_route_table_association.a` |
| **Route Table Assoc 2** | Links Subnet 2 to Route Table | `rtbassoc-024dfa0e199fa7485` | `aws_route_table_association.b` |

### B. Security & Firewalls (VPC Feature - Network & Compute Modules)
| AWS Component | Console Name / Tag | Exact Resource ID | Terraform Identifier | Location |
| :--- | :--- | :--- | :--- | :--- |
| **Load Balancer SG** | `tf-lb-security-group` | `sg-0759fdeb7d2edc4d7` | `aws_security_group.lb_sg` | `modules/network` |
| **EC2 Instances SG** | `tf-vm-security-group` | `sg-0ceb9f0cb63b1451e` | `aws_security_group.vm_sg` | `modules/compute` |

### C. Source Image Creation (EC2 Service - Compute Module: `modules/compute`)
| AWS Component | Console Name / Tag | Exact Resource ID / Name | Terraform Identifier |
| :--- | :--- | :--- | :--- |
| **Temporary VM** | `tf-temporary-source-vm` | `i-0d2d0071b8e8a2c8a` | `aws_instance.temp_vm` |
| **Custom AMI** | `tf-custom-apache-image-i-0d2d0071b8e8a2c8a` | `ami-00a1a191f5c10bbcd` | `aws_ami_from_instance.golden_image` |

### D. Load Balancing Layer (ELB Service - Compute Module: `modules/compute`)
| AWS Component | Console Name / Tag | Exact Resource ID / DNS Name | Terraform Identifier |
| :--- | :--- | :--- | :--- |
| **Application Load Balancer** | `tf-external-lb` | DNS: `tf-external-lb-1617367488.us-east-1.elb.amazonaws.com` | `aws_lb.external_lb` |
| **Target Group** | `tf-lb-target-group` | `arn:aws:elasticloadbalancing:us-east-1:136889124971:targetgroup/tf-lb-target-group/80326aadc621f751` | `aws_lb_target_group.tg` |
| **HTTP Listener** | Listens on Port 80 of ALB | `arn:aws:elasticloadbalancing:us-east-1:136889124971:listener/app/tf-external-lb/b287f15a93f5e850/6ff1d653ded7f808` | `aws_lb_listener.listener` |

### E. Scale Set Layer (Auto Scaling Service - Compute Module: `modules/compute`)
| AWS Component | Console Name / Tag | Exact Resource ID / Name | Terraform Identifier |
| :--- | :--- | :--- | :--- |
| **Launch Template** | `tf-web-template-20260616064215862300000003` | `lt-06bb55be2ff9ff91c` | `aws_launch_template.asg_template` |
| **Auto Scaling Group** | `terraform-20260616064223948700000005` | Name: `terraform-20260616064223948700000005` | `aws_autoscaling_group.asg` |
| **ASG VM Instance 1** | `tf-scale-set-instance` | `i-07a032f0bccbbfd2b` | Launched by ASG |
| **ASG VM Instance 2** | `tf-scale-set-instance` | `i-0c9f166ec3b8d5e10` | Launched by ASG |
| **ASG VM Instance 3** | `tf-scale-set-instance` | `i-061fc52df278568f0` | Launched by ASG |

### F. State Management (S3 Service - Root Module Configuration)
| AWS Component | Purpose | Key / Bucket Configuration Details | Terraform Identifier |
| :--- | :--- | :--- | :--- |
| **S3 State Object** | Remote state storage tracking live infrastructure | Bucket: `rpavani-terraform-prac`<br>Key: `prod/terraform.tfstate`<br>Region: `ap-south-1` | `backend "s3"` |

---

## 3. High Availability (HA) Traffic Flow Mapping
1. **User Client Access** $\rightarrow$ Hits External Load Balancer DNS name: `tf-external-lb-1617367488.us-east-1.elb.amazonaws.com`.
2. **Firewall Filter** $\rightarrow$ Inbound rules validate client IP matches `allowed_ip_range` (`aws_security_group.lb_sg`).
3. **Listener Routing** $\rightarrow$ Traffic is received on Port 80 and forwarded (`aws_lb_listener.listener`).
4. **Target Distribution** $\rightarrow$ Traffic routed in round-robin fashion to one of the 3 scale-set compute instances (`aws_autoscaling_group.asg`) registered inside target group `tf-lb-target-group`.
5. **Dynamic Host Execution** $\rightarrow$ Selected instance serves custom `/var/www/html/index.html` displaying its own dynamic EC2 private hostname (resolved at instance boot via `$(hostname -f)`).
