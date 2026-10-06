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
| `environments/production.tfvars` | Production values (project ID, region, zone) |
| `terraform.tfvars.example` | Template for a local `terraform.tfvars` |
| `.gitignore` | Keeps state, cache and tfvars out of Git |

---

## Branching model

| Branch | Purpose |
|--------|---------|
| `production` | Default branch. Only reviewed, working config. Deploy from here. |
| `develop` | Integration branch. Features merge here first. |
| `feature/*` | One branch per change, cut from `develop`. |

Flow: `feature/*` -> `develop` -> `production`.

---

## Part A: Git, step by step (your own login)

### 1. One-time identity
```bash
git config --global user.name  "Prajot Patil"
git config --global user.email "patilprajot7@gmail.com"
git config --global init.defaultBranch production
```

### 2. Create an empty repo on GitHub
On github.com click **New repository**, name it `vpc-peering-lab`, leave
README/.gitignore/license **unchecked**, then create it.

### 3. Authenticate with your GitHub login
Easiest: GitHub CLI.
```bash
gh auth login        # choose GitHub.com > HTTPS > Login with a web browser
```
(Or use HTTPS with a Personal Access Token as the password.)

### 4. Connect and push all branches
```bash
cd vpc-peering-lab
git remote add origin https://github.com/<your-github-username>/vpc-peering-lab.git
git push -u origin production develop
```
In GitHub: **Settings > Branches**, set `production` as default and add a
branch protection rule (require pull request before merging).

### 5. Everyday workflow
```bash
git checkout develop && git pull
git checkout -b feature/my-change
# ...edit...
terraform fmt && terraform validate
git add -A
git commit -m "Describe the change"
git push -u origin feature/my-change
# open PR: feature/my-change -> develop, merge
# then PR: develop -> production, merge
```

---

## Part B: Run the lab (Qwiklabs project `qwiklabs-gcp-03-14c91c25fc1`)

Run these in **Cloud Shell** (Terraform is preinstalled), logged in with the
lab Username/Password from the lab panel. Never commit that password.

```bash
gcloud config set project qwiklabs-gcp-03-14c91c25fc1
gcloud services enable compute.googleapis.com iap.googleapis.com

git clone https://github.com/<your-github-username>/vpc-peering-lab.git
cd vpc-peering-lab
git checkout production

terraform init
terraform fmt -check
terraform validate
terraform plan  -var-file=environments/production.tfvars
terraform apply -var-file=environments/production.tfvars
```

### Verify peering
```bash
gcloud compute networks peerings list --network=vpc-shared
```
All should show `ACTIVE`.

### Test connectivity (VMs have no public IP, use IAP)
```bash
terraform output vm_internal_ips
gcloud compute ssh vm-shared --zone us-central1-a --tunnel-through-iap
ping -c 3 <internal IP of vm-b3>
```
From `vm-b3`, `vm-shared` is reachable but `vm-b4` is not (peering is not
transitive).

### Clean up
```bash
terraform destroy -var-file=environments/production.tfvars
```

> The lab region may differ from `us-central1`. If the lab panel shows a
> different region/zone, edit `environments/production.tfvars`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Peering stuck / "operation in progress" | Peerings are chained with `depends_on`; re-run `terraform apply`. |
| Peering `INACTIVE` | Both halves must exist; check the reverse peering. |
| Overlapping CIDR error | Every range in `vpcs` must be unique. |
| IAP SSH fails | Enable `iap.googleapis.com`; check `allow-iap-ssh-*` rules. |
| Permission denied on apply | Make sure you are logged in as the lab student account. |
