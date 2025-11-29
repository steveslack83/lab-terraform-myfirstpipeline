# 📖 Pipeline Deep Dive: Understanding Every Step

This document breaks down the GitHub Actions YAML pipeline line by line. This pipeline uses a **secure two-job architecture** with manual approval gates. By the end, you'll understand exactly how CI/CD pipelines work and be able to write your own 🙌

## 🎯 What is a YAML Pipeline?

A **YAML pipeline** is a text file that tells GitHub Actions:

- **When** to run (triggers)
- **Where** to run (runner environment)
- **What** to do (steps/commands)
- **How** to run (order, dependencies and approval gates)

Think of it as a recipe: ingredients (secrets/variables), steps (commands), and the final dish (deployed infrastructure).

---

## 🏗️ Two-Job Architecture Overview

This pipeline is split into two separate jobs with a **manual approval gate** between them. This implements a **secure pattern** that avoids storing sensitive plan files.

```text
┌─────────────────────────────────────────────────────────┐
│                     JOB 1: PLAN                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 1. Checkout Code                                  │  │
│  │ 2. Setup Terraform                                │  │
│  │ 3. Azure Login                                    │  │
│  │ 4. Terraform Init                                 │  │
│  │ 5. Terraform Validate                             │  │
│  │ 6. Terraform Format Check                         │  │
│  │ 7. Terraform Plan (logs only)                     │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                        ⏸️  APPROVAL GATE  ⏸️
                   (Review & Approve/Reject)
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────┐
│                     JOB 2: APPLY                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 1. Checkout Code (fresh runner)                   │  │
│  │ 2. Setup Terraform                                │  │
│  │ 3. Azure Login                                    │  │
│  │ 4. Terraform Init                                 │  │
│  │ 5. Terraform Apply (fresh apply, auto-approve)    │  │
│  │ 6. Terraform Output                               │  │
│  │ 7. Terraform Destroy (optional)                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Key Benefits:**

1. **🔒 No Stored Plan Files**: Plan output is logged for review but not saved, preventing potential secret leakage
2. **Clean Separation**: Planning logic and execution logic are completely separate
3. **Approval Between Jobs**: The environment gate triggers between complete jobs, not within a single job
4. **Fresh Runner**: Job 2 gets a clean runner environment
5. **Better UI**: GitHub Actions UI clearly shows: Plan (✓) → Waiting for approval → Apply (running)
6. **Security**: No sensitive data stored in artifacts
7. **Independent Authentication**: Each job authenticates separately

---

## 📋 Complete Pipeline Breakdown

### Section 1: Pipeline Metadata

```yaml
name: Deploy VM with Bastion
```

**What it does:** Names your pipeline  
**Why it matters:** This name appears in the GitHub Actions UI  
**Best practice:** Use descriptive names that explain what the pipeline does (Think Tech Debt/Handover here💭)

---

### Section 2: Triggers (`on`)

```yaml
on:
  push:
    branches:
      - main
    paths:
      - '**.tf'
      - '**.tfvars'
      - '.github/workflows/**'
```

**What it does:** Defines when the pipeline runs automatically  
**Breaking it down:**

- `push:` - Runs when code is pushed to the repository
- `branches: [main]` - Only for pushes to the `main` branch
- `paths:` - Only if these file types changed (filters unnecessary runs)
  - `**.tf` - Any Terraform file anywhere in the repo
  - `**.tfvars` - Any Terraform variables file
  - `.github/workflows/**` - Pipeline file itself

**Why it matters:** Saves compute time by only running when infrastructure code changes

---

```yaml
  workflow_dispatch:
    inputs:
      destroy:
        description: 'Destroy infrastructure? (true/false)'
        required: false
        default: 'false'
```

**What it does:** Allows manual triggering from GitHub UI  
**Breaking it down:**

- `workflow_dispatch:` - Enables manual run button
- `inputs:` - Parameters you can pass when triggering manually
- `destroy:` - A boolean input to optionally destroy infrastructure

**Why it matters:** Gives you control - run pipeline anytime, pass parameters

**How to use:**

1. Go to Actions tab in GitHub
2. Select your workflow
3. Click "Run workflow"
4. Choose `main` branch
5. Set destroy to `true` or `false`
6. Click "Run workflow" button

---

### Section 3: Environment Variables (`env`)

```yaml
env:
  TF_VERSION: '1.6.0'
  WORKING_DIR: '.'
```

**What it does:** Sets variables available to all jobs/steps  
**Breaking it down:**

- `TF_VERSION` - Which Terraform version to use
- `WORKING_DIR` - Directory containing Terraform files (`.` = root)

**Why it matters:** Centralised configuration (change version in one place)  

---

### Section 4: Jobs

#### Job 1: Plan

```yaml
jobs:
  plan:
    name: 'Plan Infrastructure'
    runs-on: ubuntu-latest
    
    defaults:
      run:
        shell: bash
        working-directory: ${{ env.WORKING_DIR }}
```

**What it does:** Defines the first job - validates code and creates deployment plan  
**Breaking it down:**

- `jobs:` - Container for all jobs (we have two jobs in this pipeline)
- `plan:` - Job ID (unique identifier for this job)
- `name:` - Human-readable job name shown in GitHub UI
- `runs-on: ubuntu-latest` - VM environment to run on
- `defaults` - Settings applied to all steps in this job

**Runner options:**

- `ubuntu-latest` - Linux (most common, fastest, free)
- `windows-latest` - Windows
- `macos-latest` - macOS

**Why Ubuntu?** Free, fast, has most tools pre-installed

**Note:** No `environment:` configuration on this job - the Plan job runs immediately

---

#### Plan Job - Step 1: Checkout Repository

```yaml
      - name: '📥 Checkout Repository'
        uses: actions/checkout@v4
```

**What it does:** Downloads your repository code to the runner  
**Why it's first:** Nothing else works without your code! (sarcasm here, sorry😄)

---

#### Plan Job - Step 2: Setup Terraform

```yaml
      - name: '🔧 Setup Terraform'
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
```

**What it does:** Installs Terraform CLI on the runner  
**Why needed:** Runners don't have Terraform pre-installed

---

#### Plan Job - Step 3: Azure Login

```yaml
      - name: '🔐 Azure Login'
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**What it does:** Authenticates with Azure using Service Principal  
**Secret format:** JSON containing clientId, clientSecret, subscriptionId, tenantId

---

#### Plan Job - Step 4: Terraform Init

```yaml
      - name: '🏗️ Terraform Init'
        run: terraform init
```

**What it does:** Initializes Terraform workspace  
**What happens:**

1. Downloads provider plugins (e.g., azurerm)
2. Connects to remote backend (Azure Storage) for state management
3. Prepares `.terraform/` directory
4. Locks provider versions

**⚠️ Backend Requirement:** This pipeline uses a remote backend configured in `main.tf`. The backend must exist before running the pipeline. See [BACKEND-SETUP.md](BACKEND-SETUP.md) for setup instructions.

**Why remote backend?** The plan and apply jobs run on separate virtual machines. Without a remote backend, the state created during the plan job would be lost, causing the apply job to fail.

---

#### Plan Job - Step 5: Terraform Validate

```yaml
      - name: '✅ Terraform Validate'
        run: terraform validate
```

**What it does:** Checks syntax and configuration validity  
**What it checks:** Syntax errors, invalid resource types, missing required arguments, type mismatches

---

#### Plan Job - Step 6: Terraform Format Check

```yaml
      - name: '📝 Terraform Format Check'
        run: terraform fmt -check -recursive
```

**What it does:** Ensures consistent code formatting  
**Why it matters:** Code review quality, team consistency

**To fix formatting locally:**

```bash
terraform fmt -recursive
```

---

#### Plan Job - Step 7: Terraform Plan (For Review Only)

```yaml
      - name: '📋 Terraform Plan (Review Only)'
        env:
          TF_VAR_admin_password: ${{ secrets.ADMIN_PASSWORD }}
        run: terraform plan
```

**What it does:** Creates execution plan for human review (output logged only)  
**Breaking it down:**

- `terraform plan` - Preview changes without saving to file
- `env: TF_VAR_admin_password` - **SECURITY BEST PRACTICE**: Pass secrets via environment variables

**Why TF_VAR_ instead of -var flag?**

1. **Security**: Secrets don't appear in command-line logs
2. **Error Safety**: Reduced exposure if Terraform errors and logs full command
3. **Industry Standard**: How HashiCorp recommends passing sensitive data
4. **Automatic Detection**: Terraform automatically maps `TF_VAR_admin_password` → `var.admin_password`

**Why NO -out flag?**

- **Security**: Plan files can contain sensitive data in plaintext
- **Prevents Leakage**: No risk of secrets being exposed through stored artifacts
- **Secure Pattern**: Output is logged for review but not persisted
- **Fresh Apply**: Apply job will run a fresh terraform apply after approval

**What happens:**

1. Terraform reads current state
2. Compares desired state (your code) vs actual state (Azure)
3. Determines what needs to change
4. Shows resources to create (+), modify (~), or delete (-)
5. Logs output for human review (NOT saved to file)

**Example output:**

```text
Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "uksouth"
      + name     = "rg-myfirstpipeline"
    }

Plan: 8 to add, 0 to change, 0 to destroy.
```

---

### Approval Gate: Manual Review Between Jobs

**After Job 1 (Plan) completes, the pipeline pauses before starting Job 2 (Apply).**

**What triggers the approval gate:**

- The `environment: production` configuration on Job 2
- Required reviewers configured in repository Settings → Environments → production

**What happens:**

1. Job 1 completes successfully - plan output is logged for review
2. Job 2 encounters the `environment: production` configuration
3. GitHub checks for required reviewers on the production environment
4. Pipeline displays a **"Review deployments"** button
5. Designated reviewers receive a notification
6. Pipeline waits indefinitely until approved or rejected
7. If approved, Job 2 starts on a fresh runner
8. If rejected, Job 2 never runs and the workflow fails gracefully

**How to review and approve:**

1. Go to the **Actions** tab in your GitHub repository
2. Click on the waiting workflow run
3. You'll see: Job 1 "Plan Infrastructure" ✓ complete, Job 2 "Apply Infrastructure" ⏸️ waiting
4. **Review the Terraform Plan output from Job 1 logs** - this is critical!
5. Look for the **"Review deployments"** button (yellow banner at top)
6. Click **"Review deployments"**
7. You'll see:
   - Environment: **production**
   - Job: **apply**
   - Approval required before job can run
8. Choose action:
   - ✅ **Approve** - Job 2 starts immediately
   - ❌ **Reject** - Workflow ends, no resources created
9. Optionally add a comment (e.g., "Reviewed plan, approved for deployment")
10. Click **"Approve deployments"** or **"Reject deployments"**

**If approved:** Job 2 starts immediately with a fresh terraform apply

**If rejected:** Pipeline fails gracefully, no resources are created

**Security benefits:**

- Prevents accidental deployments
- Allows team review before changes
- Creates audit trail of who approved what
- Catches unexpected changes in the plan
- No sensitive plan files stored as artifacts

**Setting up the production environment in GitHub Environments:**

1. Go to repository **Settings**
2. Click **Environments** (left sidebar)
3. Click **New environment**
4. Name: `production` (must match pipeline exactly)
5. Check **Required reviewers**
6. Add GitHub usernames who can approve (yourself, team members)
7. Optionally set **Wait timer** (e.g., 5 minutes minimum wait before approval possible)
8. Click **Save protection rules**

**Pro tip:** You can add multiple reviewers and require X number of approvals (e.g., 2 out of 3 must approve).

---

#### Job 2: Apply

```yaml
  apply:
    name: 'Apply Infrastructure to Azure'
    runs-on: ubuntu-latest
    
    needs: plan
    
    environment:
      name: production
      url: https://portal.azure.com
    
    defaults:
      run:
        shell: bash
        working-directory: ${{ env.WORKING_DIR }}
```

**What it does:** Defines the second job - applies changes after approval  
**Breaking it down:**

- `apply:` - Job ID
- `needs: plan` - **Critical**: This job waits for the `plan` job to complete successfully
- `environment:` - **The approval gate configuration**
  - `name: production` - Links to the production environment (must be configured in repo settings)
  - `url:` - Optional URL shown in the approval UI

**About `needs: plan`:**

- Job 2 will NOT start until Job 1 completes
- If Job 1 fails, Job 2 never runs
- This creates a dependency chain

**About the environment setting:**

The `environment: production` configuration is what triggers the approval gate. When GitHub Actions encounters this:

1. It checks if Job 1 (`plan`) completed successfully ✓
2. It checks if the `production` environment exists in repository settings
3. If required reviewers are configured, it pauses the workflow
4. A "Review deployments" button appears in the Actions UI
5. Designated reviewers must approve before Job 2 starts
6. All steps in Job 2 wait for approval

**Without `needs: plan`:** Jobs would run in parallel (both starting at the same time) 🤕

**Without `environment: production`:** Job 2 would run immediately after Job 1 with no approval 🤢

---

#### Apply Job - Step 1: Checkout Repository

```yaml
      - name: '📥 Checkout Repository'
        uses: actions/checkout@v4
```

**What it does:** Downloads your repository code to the fresh runner  
**Why needed:** Job 2 runs on a new VM that doesn't have your code yet

---

#### Apply Job - Step 2: Setup Terraform

```yaml
      - name: '🔧 Setup Terraform'
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
```

**What it does:** Installs Terraform CLI on the fresh runner  
**Why needed:** Each job runs on a new VM without Terraform pre-installed

---

#### Apply Job - Step 3: Azure Login

```yaml
      - name: '🔐 Azure Login'
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**What it does:** Authenticates with Azure for deployment  
**Why needed:** Must re-authenticate on the new runner (Job 2 has a fresh VM)

---

#### Apply Job - Step 4: Terraform Init

```yaml
      - name: '🏗️ Terraform Init'
        run: terraform init
```

**What it does:** Initializes Terraform on the fresh runner  
**Why re-init?** Job 2 runs on a new VM that needs:

- Provider plugins downloaded
- Connection to remote backend re-established
- Workspace prepared for apply operations

**Backend Connection:** This step reconnects to the same Azure Storage backend configured in Job 1, retrieving the existing state. The state persists across jobs because it's stored remotely, not locally on the runner.

---

#### Apply Job - Step 5: Terraform Apply

```yaml
      - name: '🚀 Terraform Apply'
        if: github.event.inputs.destroy != 'true'
        env:
          TF_VAR_admin_password: ${{ secrets.ADMIN_PASSWORD }}
        run: terraform apply -auto-approve
```

**What it does:** Applies changes and creates resources in Azure (fresh apply)  
**Breaking it down:**

- `if:` - Conditional execution (only if not destroying)
- `terraform apply` - Apply changes
- `-auto-approve` - Skip manual confirmation prompt (approval already happened between jobs)
- `env: TF_VAR_admin_password` - Securely pass admin password via environment variable

**What happens:**

1. Terraform reads current state
2. Calculates what needs to change (same logic as the plan reviewed earlier)
3. Creates resources in order (handles dependencies automatically)
4. Updates state file with resource IDs
5. Shows progress for each resource

**Example output:**

```text
azurerm_resource_group.main: Creating...
azurerm_resource_group.main: Creation complete after 2s
azurerm_virtual_network.main: Creating...
azurerm_virtual_network.main: Creation complete after 5s
...
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
```

**Time:** ~5-10 minutes for complete deployment

**Security note:** This runs a fresh apply based on:

1. Current code from repository (checked out in Step 1)
2. Current Azure state
3. Admin password securely passed via environment variable
4. After explicit human approval

---

#### Apply Job - Step 6: Terraform Output

```yaml
      - name: '📊 Terraform Output'
        if: github.event.inputs.destroy != 'true'
        run: terraform output
```

**What it does:** Displays outputs defined in `outputs.tf`  
**Why it's useful:** Shows connection info, IPs, resource IDs

**Example output:**

```text
admin_username = "azureadmin"
bastion_name = "bas-myfirstpipeline"
bastion_public_ip = "20.90.142.15"
vm_name = "vm-myfirstpipeline"
vm_private_ip = "10.0.1.4"

connection_instructions = <<EOT
To connect to your Windows Server 2025 VM:
1. Go to the Azure Portal (https://portal.azure.com)
2. Navigate to your VM: vm-myfirstpipeline
3. Click 'Connect' → 'Bastion'
4. Enter username: azureadmin
5. Enter the admin password you configured
6. Click 'Connect' to open Remote Desktop session

VM Private IP: 10.0.1.4
OS: Windows Server 2025 Datacenter (Azure Edition)
EOT
```

---

#### Apply Job - Step 7: Terraform Destroy (Optional)

```yaml
      - name: '💣 Terraform Destroy'
        if: github.event.inputs.destroy == 'true'
        env:
          TF_VAR_admin_password: ${{ secrets.ADMIN_PASSWORD }}
        run: terraform destroy -auto-approve
```

**What it does:** Destroys all Terraform-managed resources  
**Breaking it down:**

- `if: github.event.inputs.destroy == 'true'` - Only when manually triggered with destroy=true
- `env: TF_VAR_admin_password` - Securely pass admin password (same pattern as plan step)
- `terraform destroy` - Delete all resources
- `-auto-approve` - Skip confirmation (approval already required at job level)

**What happens:**

1. Terraform identifies all managed resources from state
2. Deletes them in reverse dependency order (subnets before VNets, etc.)
3. Updates state to empty

**⚠️ WARNING:** This deletes everything! No undo!

**When to use:** Cleaning up lab environments to avoid ongoing Azure costs

**Note:** Destroy operations ALSO require approval - the production environment gate still applies to Job 2, even when destroying. This prevents accidental deletion.

---

## 🔐 Secrets Management

### What are GitHub Secrets?

Encrypted environment variables stored in GitHub. They:

- ✅ Are encrypted at rest
- ✅ Are redacted in logs
- ✅ Can't be read after creation (write-only)
- ✅ Are injected at runtime

### How to Reference Secrets

```yaml
${{ secrets.SECRET_NAME }}
```

**Available scopes:**

- Repository secrets (this repo only)
- Organisation secrets (all repos in org)
- Environment secrets (specific environment)

### Best Practices

1. **Never commit secrets** to Git
2. **Rotate regularly** (30-90 days)
3. **Use least privilege** (minimal permissions)
4. **Audit access** (who has secrets access?)
5. **Use separate credentials** per environment

---

## 🎯 Pipeline Flow Summary

```text
TRIGGER (Push to main OR Manual)
    ↓
┌─────────────────────────────────────────────┐
│          JOB 1: PLAN                        │
│  ┌───────────────────────────────────────┐  │
│  │ CHECKOUT CODE                         │  │
│  │         ↓                             │  │
│  │ SETUP TOOLS (Terraform)               │  │
│  │         ↓                             │  │
│  │ AUTHENTICATE (Azure Login)            │  │
│  │         ↓                             │  │
│  │ VALIDATE CODE (Init, Validate, Format)│  │
│  │         ↓                             │  │
│  │ PLAN CHANGES (Logs output for review) │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
                   │
                   ▼
        ⏸️  MANUAL APPROVAL GATE
     (Review Plan & Approve/Reject)
                   │
                   ▼
┌─────────────────────────────────────────────┐
│    JOB 2: APPLY (After Approval)            │
│  ┌───────────────────────────────────────┐  │
│  │ CHECKOUT CODE (Fresh Runner)          │  │
│  │         ↓                             │  │
│  │ SETUP TOOLS                           │  │
│  │         ↓                             │  │
│  │ AUTHENTICATE                          │  │
│  │         ↓                             │  │
│  │ INIT TERRAFORM                        │  │
│  │         ↓                             │  │
│  ├─→ APPLY (Create resources)            │  │
│  │         ↓                             │  │
│  │   OUTPUT (Show connection info)       │  │
│  │                                       │  │
│  └─→ DESTROY (If manually triggered)     │  │
│      (with destroy=true)                 │  │
└─────────────────────────────────────────────┘
```

**Key Points:**

- **Two separate jobs** run on different runners
- **Approval gate** triggers BETWEEN jobs, not within a job
- **No plan files stored** - plan output is logged for review only
- **Fresh runner** for Job 2 ensures clean execution environment
- **Fresh apply** after approval based on current code and state
- **Independent authentication** - each job authenticates separately
- **Secure pattern** - no sensitive data stored in artifacts

---

## 💡 Key Concepts Explained

### Two-Job Architecture Benefits

**Why split Plan and Apply into separate jobs?**

1. **Clean Separation of Concerns**
   - Job 1: Validation and planning (read-only operations)
   - Job 2: Execution (write operations)
   - Each job has a clear, single purpose

2. **Better Approval Flow**
   - Approval happens BETWEEN complete jobs
   - Not buried within a single long-running job
   - GitHub UI clearly shows: Plan ✓ → Waiting → Apply (pending)

3. **Fresh Execution Environment**
   - Job 2 runs on a brand new virtual machine
   - No leftover state from Job 1
   - Clean filesystem, processes, environment
   - Eliminates potential for contamination

4. **Better Error Handling**
   - If planning fails, you don't waste time on apply steps
   - Each job can be re-run independently
   - Failed jobs don't leave the runner in a weird state

5. **Audit Trail**
   - Clear separation in logs: "What was planned" vs "What was applied"
   - Approval events are tied to specific jobs
   - Complete traceability for compliance

6. **Resource Efficiency**
   - Job 1 completes and releases its runner quickly
   - No runner sitting idle during approval wait time
   - GitHub doesn't charge for wait time between jobs

### Idempotency

Running the pipeline multiple times with the same code produces the same result.

**Example:**

- First run: Creates 8 resources
- Second run: 0 changes (resources already exist)
- Third run: Still 0 changes

### State File

Terraform tracks what it created in a **state file**.

**What it contains:**

- Resource IDs
- Attributes
- Dependencies

**Why it matters:** Terraform knows what exists and what needs to change

### Dependencies

Terraform automatically understands resource dependencies:

```hcl
resource "azurerm_virtual_network" "main" { ... }

resource "azurerm_subnet" "vm" {
  virtual_network_name = azurerm_virtual_network.main.name  # Dependency!
}
```

**Result:** VNet created before Subnet

---

## 🚨 Common Errors and Fixes

### Error: "AZURE_CREDENTIALS not found"

**Cause:** Secret not configured in GitHub  
**Fix:** Add secret in Settings → Secrets → Actions

### Error: "Error acquiring state lock"

**Cause:** Another pipeline run is in progress or approval is pending  
**Fix:** Wait for other run to complete/be approved or cancel it

### Error: "Environment protection rules not met"

**Cause:** Production environment not configured with reviewers  
**Fix:** Go to Settings → Environments → production → Add required reviewers

**Cause:** Azure subscription limits  
**Fix:** Choose smaller VM size or request quota increase

---

## 🎓 Learning Exercises

### Exercise 1: Review a Plan

Run the pipeline and practice reviewing the Terraform plan before approving.

### Exercise 2: Reject a Deployment

Intentionally reject a deployment and observe what happens.

### Exercise 3: Add Multiple Reviewers

Configure the production environment to require 2 approvals before deployment.

### Exercise 4: Add a Step

Add a step that runs `terraform show` after apply.

### Exercise 5: Add Validation

Add a step that checks if VM name is < 15 characters.

### Exercise 6: Multi-Environment

Modify to deploy to dev/staging/prod with different tfvars and different approvers.

### Exercise 7: Wait Timer

Add a wait timer to the production environment to enforce a minimum review period.

### Exercise 8: Notifications

Add a step that sends a notification when deployment completes.

---

## 📚 Further Reading

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [YAML Syntax](https://yaml.org/spec/1.2.2/)
- [GitHub Actions Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)

---

**Congratulations!** You now understand how YAML pipelines work! 🎉

Ready to build your own? Start experimenting and learning by doing!
