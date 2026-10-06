# GCP Hub-and-Spoke VPC Peering Lab (Terraform + Git)

Four VPCs (`shared` hub; `b3`, `b4`, `bsys` spokes), one subnet and one
`e2-micro` VM in each, firewall rules, and VPC peering between the hub and
each spoke. All managed with Terraform and tracked in Git.

```
        b3 (10.1.0.0/24)
            |
shared (10.0.0.0/24) --- b4 (10.2.0.0/24)
            |
        bsys (10.3.0.0/24)
```

> Note: VPC peering is **not transitive**. Spokes can reach the hub, but
> b3 cannot reach b4 through shared.

## Files

| File | Purpose |
|------|---------|
| `main.tf` | VPCs, subnets, firewalls, VMs, peerings |
| `variables.tf` | Project, region, zone, VPC => CIDR map |
| `outputs.tf` | VM internal IPs and VPC names |
| `terraform.tfvars.example` | Template for your own `terraform.tfvars` |
| `.gitignore` | Keeps state, cache and tfvars out of Git |

---

## Part A: Git, from repo creation to first commit

### 1. One-time Git identity
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

### 2. Create the repo
```bash
mkdir vpc-peering-lab && cd vpc-peering-lab   # or cd into this folder
git init
```

### 3. Add the files
Place `main.tf`, `variables.tf`, `outputs.tf`, `.gitignore` and
`terraform.tfvars.example` in the folder.

### 4. Check what Git sees
```bash
git status
```
You should NOT see `terraform.tfvars`, `.terraform/` or `*.tfstate`.
They are covered by `.gitignore`.

### 5. Stage and commit
```bash
git add .
git commit -m "Add GCP hub-and-spoke VPC peering lab (Terraform)"
```

### 6. Verify the commit
```bash
git log --oneline
git show --stat HEAD
git status        # should say: nothing to commit, working tree clean
```

### 7. (Optional) Push to a remote
Create an empty repo on GitHub or GitLab (no README), then:
```bash
git remote add origin https://github.com/<you>/vpc-peering-lab.git
git push -u origin main
```

---

## Part B: Run the lab

### 1. Authenticate and set the project
```bash
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
gcloud services enable compute.googleapis.com iap.googleapis.com
```

### 2. Provide your project ID
```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set project_id
```

### 3. Deploy
```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```
Commit the generated lock file after the first init:
```bash
git add .terraform.lock.hcl
git commit -m "Add provider lock file"
```

### 4. Verify peering
```bash
gcloud compute networks peerings list --network=vpc-shared
gcloud compute networks peerings list --network=vpc-b3
```
All peerings should show `ACTIVE`.

### 5. Test connectivity (via IAP, VMs have no public IP)
```bash
terraform output vm_internal_ips

gcloud compute ssh vm-shared --zone us-central1-a --tunnel-through-iap
# inside the VM:
ping -c 3 <internal IP of vm-b3>
ping -c 3 <internal IP of vm-b4>
ping -c 3 <internal IP of vm-bsys>
```
From `vm-b3`, pinging `vm-shared` works; pinging `vm-b4` does **not**
(no transitive peering).

### 6. Clean up (avoid charges)
```bash
terraform destroy
```

---

## Part C: Making and committing changes (daily workflow)

```bash
git checkout -b feature/add-new-vpc
# edit variables.tf, e.g. add:  b5 = "10.4.0.0/24"
terraform fmt && terraform validate && terraform plan
git add -A
git commit -m "Add b5 VPC to the vpcs map"
git push -u origin feature/add-new-vpc     # then open a pull/merge request
```
Adding a spoke also needs a new peering pair in `main.tf`, chained with
`depends_on` to the previous peering.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Peering stuck / "operation in progress" | Peerings on the same VPC must be sequential; the `depends_on` chain handles this. Re-run `terraform apply`. |
| Peering `INACTIVE` | Both halves must exist; check the reverse peering. |
| Overlapping CIDR error | Make sure every range in `vpcs` is unique. |
| IAP SSH fails | Enable `iap.googleapis.com` and ensure the `allow-iap-ssh-*` rule exists. |
| `terraform.tfvars` shows in `git status` | Check `.gitignore` is in the repo root. |
