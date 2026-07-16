# Terraform for Beginners

A plain-language introduction to Terraform, using the AWS infrastructure in this
repo (`terraform-aws-infra/`) as the running example.

---

## 1. What problem does Terraform solve?

Before tools like Terraform, infrastructure (servers, networks, load balancers)
was usually created by:
* Clicking through a cloud console (AWS/Azure/GCP web UI), or
* Running one-off CLI commands / scripts.

Both approaches have the same problems:
* **Not repeatable** — nobody can reliably rebuild the exact same environment.
* **Not documented** — the only record of "what exists" is the cloud console itself.
* **Not reviewable** — you can't `diff` a UI click or approve it in a pull request.
* **Drift** — someone manually tweaks a setting, and now the real world no longer
  matches whatever documentation exists.

**Infrastructure as Code (IaC)** fixes this by describing your infrastructure in
text files that live in version control (git), the same way you manage
application code. Terraform is the most widely used general-purpose IaC tool.

---

## 2. What is Terraform, concretely?

Terraform is a command-line tool made by HashiCorp that:
1. Reads configuration files written in **HCL** (HashiCorp Configuration
   Language) — files ending in `.tf`.
2. Talks to a cloud **provider's API** (AWS, Azure, GCP, Cloudflare, etc.) via a
   plugin called a **provider**.
3. Figures out what needs to be created, changed, or destroyed to make the real
   world match your `.tf` files.
4. Keeps a record of what it created in a **state file** (`terraform.tfstate`).

It is **declarative**: you describe the *desired end state* ("I want a VPC, two
subnets, and 3 web servers behind a load balancer"), not the *steps* to get
there. Terraform figures out the steps (create this before that, update this
in place, replace that) for you.

---

## 3. Core building blocks

### Provider
A plugin that lets Terraform talk to a specific platform's API.

```hcl
provider "aws" {
  region = "us-east-1"
}
```
See it in this repo: [terraform-aws-infra/providers.tf](../terraform-aws-infra/providers.tf).

### Resource
A single piece of infrastructure Terraform manages — a VM, a VPC, a security
group, a load balancer, etc. The syntax is always:

```hcl
resource "<provider_type>" "<local_name>" {
  argument = value
}
```

Example from this repo — an EC2 instance:
```hcl
resource "aws_instance" "temp_vm" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
}
```
The `local_name` (`temp_vm`) is just a name *inside your Terraform code* — it's
how other parts of your config refer to this resource (e.g.
`aws_instance.temp_vm.id`). It is not the AWS resource name.

### Data source
Read-only lookup of information that already exists (but that Terraform
doesn't manage), e.g. "find the latest Amazon Linux AMI":
```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}
```

### Variables (input)
Parameters that let you reuse the same configuration with different values,
instead of hardcoding them:
```hcl
variable "allowed_ip_range" {
  type    = string
  default = "0.0.0.0/0"
}
```
Used elsewhere as `var.allowed_ip_range`. See
[terraform-aws-infra/variables.tf](../terraform-aws-infra/variables.tf).

### Outputs
Values Terraform prints after `apply`, and that other modules/configs can
consume:
```hcl
output "load_balancer_dns" {
  value = module.compute.lb_dns_name
}
```

### Modules
A module is just a folder of `.tf` files. Every Terraform config is technically
a module (the "root module"); you can also call other folders as **child
modules** to reuse and organize code:
```hcl
module "network" {
  source     = "./modules/network"
  aws_region = var.aws_region
}
```
This repo splits infrastructure into `modules/network` (VPC, subnets, routing,
firewall) and `modules/compute` (VMs, AMI, load balancer, autoscaling) — see
[terraform-aws-infra/main.tf](../terraform-aws-infra/main.tf). Splitting by
"type of resource" keeps networking (which changes rarely) separate from
compute (which changes often), and makes each module independently reusable.

### State
Terraform stores a JSON file (`terraform.tfstate`) mapping your `.tf` resources
to real-world resource IDs (e.g. `aws_vpc.main` → `vpc-011ea...`). This is how
Terraform knows what it already created, and what has drifted.

By default state is a local file. In a team setting you store it remotely (a
**backend**) so everyone shares the same source of truth and it's encrypted at
rest. This repo uses an S3 backend — see
[terraform-aws-infra/providers.tf](../terraform-aws-infra/providers.tf) and
the bucket-provisioning code in
[terraform-aws-infra/bootstrap-backend/main.tf](../terraform-aws-infra/bootstrap-backend/main.tf).

> The state file can contain sensitive data (IDs, sometimes secrets). Never
> commit `terraform.tfstate` to git — that's exactly why a remote backend
> exists.

---

## 4. The core workflow

```
terraform init      # download providers/modules, configure the backend
terraform plan       # preview: what would change, without touching anything
terraform apply      # actually create/update/destroy resources to match config
terraform destroy    # tear everything down
```

* `init` — run once per repo/config (and again if you add providers/modules or
  change the backend).
* `plan` — always read this before applying. It shows a diff:
  `+` create, `-` destroy, `~` update in place, `-/+` destroy-and-recreate.
* `apply` — asks for confirmation (`yes`), then executes the plan.
* `destroy` — the reverse of apply; deletes everything Terraform manages in
  that state.

---

## 5. How this repo's example ties together

1. `terraform init` downloads the AWS provider and configures the S3 backend.
2. `network` module builds a VPC, two public subnets (different AZs, required
   for a highly-available Application Load Balancer), an internet gateway, and
   a security group that only allows port 80 from an approved IP range (the
   "firewall").
3. `compute` module:
   * Launches one **temporary VM**, installs Apache via a startup script
     (`user_data`), then bakes an **AMI (machine image)** from it.
   * Creates a **Launch Template** that uses that AMI.
   * Creates an **Auto Scaling Group** of 3 instances from the template.
   * Creates an **Application Load Balancer** with a **target group** and
     **health checks** in front of those 3 instances.
4. Each instance's startup script writes its own hostname into the served
   webpage, so hitting the load balancer repeatedly proves requests are being
   distributed across different servers (high availability).
5. `terraform apply` builds all of this in the right order automatically,
   because Terraform reads the *references* between resources (e.g. the ASG
   references the AMI ID, the load balancer references the subnet IDs) to
   build a dependency graph.

For a much deeper line-by-line walkthrough of *this specific* codebase, see
[terraform_prac.md](../terraform_prac.md) and the deployed resource inventory
in [resource.md](../resource.md). For a Terraform concepts cheat sheet, see
[terraform-notes.md](terraform-notes.md).
