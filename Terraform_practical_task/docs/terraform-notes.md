# Terraform Notes / Cheat Sheet

Quick-reference notes. For prose explanations, see
[terraform-for-beginners.md](terraform-for-beginners.md).

## CLI commands

| Command | Purpose |
|---|---|
| `terraform init` | Download providers/modules, set up backend. Run first, and after adding providers/modules or changing backend config. |
| `terraform validate` | Check config is syntactically valid and internally consistent (no cloud calls). |
| `terraform fmt` | Auto-format `.tf` files to canonical style. Add `-recursive` for subdirectories, `-check` for CI (no writes). |
| `terraform plan` | Show what would change. Always review before `apply`. Use `-out=plan.tfplan` to save it for `apply` to guarantee no drift between plan and apply. |
| `terraform apply` | Execute a plan. `-auto-approve` skips the confirmation prompt (use with care). |
| `terraform destroy` | Delete everything the current state manages. |
| `terraform state list` | List all resources tracked in state. |
| `terraform state show <addr>` | Show attributes of one resource, e.g. `aws_instance.temp_vm`. |
| `terraform state rm <addr>` | Stop tracking a resource without destroying it. |
| `terraform import <addr> <id>` | Bring an existing, manually-created resource under Terraform management. |
| `terraform output` | Print output values from the last apply. |
| `terraform taint <addr>` (or `terraform apply -replace=<addr>` in newer versions) | Force a resource to be destroyed and recreated on next apply. |
| `terraform workspace list/new/select` | Manage named state workspaces (separate state per environment using the same code). |
| `terraform console` | Interactive REPL to evaluate expressions against current state. |
| `terraform graph` | Emit a dependency graph (pipe to Graphviz `dot` to visualize). |

## File layout conventions

```
main.tf          # primary resources / module calls
variables.tf     # input variable declarations
outputs.tf       # output value declarations
providers.tf     # provider + backend + required_providers block
terraform.tfvars # actual values for variables (often gitignored if sensitive)
modules/         # reusable child modules, one subfolder per module
```
None of this is enforced by Terraform — it's just the community convention this
repo follows.

## HCL syntax basics

```hcl
# comment

resource "type" "name" {
  key = "value"
  nested_block {
    key = "value"
  }
}

variable "x" {
  type        = string        # string, number, bool, list(), map(), object({...})
  default     = "foo"          # optional; omitting it makes the variable required
  description = "..."
  sensitive   = true            # hides value from CLI output
}

output "y" {
  value = resource_type.name.attribute
}

locals {
  computed = "${var.x}-suffix"  # local values: named expressions, not inputs/outputs
}
```

Reference syntax:
* `var.name` — an input variable
* `local.name` — a local value
- `resource_type.local_name.attribute` — an attribute of a resource you declared
- `module.name.output_name` — an output from a child module
- `data.type.name.attribute` — an attribute from a data source

String interpolation: `"${expression}"`. A literal `$` before something that
isn't `{` is left alone (important when writing shell scripts inside
`user_data` — see the compute module's launch template in this repo, where
`$(hostname -f)` is passed through untouched because Terraform only expands
`${...}`, not `$(...)`).

## Provider / resource anatomy

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # registry.terraform.io/hashicorp/aws
      version = "~> 5.0"          # pessimistic constraint: >=5.0.0, <6.0.0
    }
  }
  backend "s3" {
    bucket  = "my-tf-state-bucket"
    key     = "prod/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
```

## State — key facts

* State maps your HCL resources to real cloud resource IDs; without it
  Terraform has no idea what it previously created.
* **Never commit `terraform.tfstate` to git** — it can contain sensitive data
  and will constantly conflict between collaborators. Add it to
  `.gitignore` and use a remote backend instead (S3, Azure Storage, GCS,
  Terraform Cloud, etc.).
* Remote backends also support **state locking** (e.g. via DynamoDB for S3) so
  two people can't `apply` concurrently and corrupt state.
* `terraform plan`/`apply` always **refresh** state first by default — they
  check the real cloud provider for drift before computing the diff.

## Modules — key facts

* Every directory of `.tf` files is a module; the one you run `terraform`
  commands from is the **root module**.
* A **child module** is called with a `module` block and a `source` (local
  path, git URL, or Terraform Registry address).
* Modules take inputs (their own `variable` blocks) and expose `output`
  blocks the caller can read as `module.<name>.<output>`.
* Group modules by **what changes together and how often** — e.g. this repo
  splits `network` (rarely changes) from `compute` (changes on every
  deploy), which limits blast radius and enables reuse.

## Dependency graph / ordering

* Terraform builds a dependency graph automatically from references between
  resources (e.g. a security group ID used inside an EC2 resource block
  means the SG must exist first).
* Use `depends_on = [resource.type.name]` only when a dependency isn't
  visible through an attribute reference (e.g. ordering based on a side
  effect, not a value).
* Resources with no dependency relationship are created/destroyed in
  parallel by default.

## Common gotchas

* **Changing an argument that forces replacement** (marked
  `# forces replacement` in `plan` output) destroys and recreates the
  resource — check `plan` carefully before applying such changes in
  production.
* **`count` vs `for_each`**: `count` indexes resources by position (0,1,2 —
  removing a middle item shifts everything after it); `for_each` indexes by a
  stable key (map/set), which is usually safer for anything you'll modify
  later.
* **Provider version drift**: pin `required_providers` versions
  (`.terraform.lock.hcl` records exact resolved versions — commit this file).
* **Secrets in `.tf`/`.tfvars`**: don't hardcode credentials; use environment
  variables, a secrets manager, or `sensitive = true` variables, and keep
  `*.tfvars` files with real secrets out of git.
* **`terraform destroy` is irreversible** — it deletes real infrastructure.
  Always double check you're pointed at the right state/workspace first.

## This repo's example, mapped to the notes above

* Root module: [terraform-aws-infra/main.tf](../terraform-aws-infra/main.tf)
  wires together two child modules.
* Backend: S3, configured in
  [terraform-aws-infra/providers.tf](../terraform-aws-infra/providers.tf);
  bucket itself provisioned separately in
  [terraform-aws-infra/bootstrap-backend/](../terraform-aws-infra/bootstrap-backend)
  (has to exist *before* the main config's `init`, since you can't store state
  for a bucket inside the bucket it's creating).
* Dependency graph in action: the Auto Scaling Group's launch template
  references `aws_ami_from_instance.golden_image.id`, which references
  `aws_instance.temp_vm.id` — Terraform infers it must build the temp VM,
  then the AMI, then the launch template/ASG, in that order, with no manual
  `depends_on` needed for that chain.
