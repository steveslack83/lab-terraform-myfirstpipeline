# 🚀 My First Pipeline: Deploy Windows Server 2025 VM with Azure Bastion

Welcome to your first Infrastructure as Code pipeline! This lab teaches you how to deploy Azure infrastructure using **Terraform** and **GitHub Actions** YAML pipelines. By the end of this lab, you'll understand how to write, configure, and run CI/CD pipelines for infrastructure deployment.

## 🎯 What You'll Learn

- ✅ How to write and structure YAML pipelines for GitHub Actions
- ✅ How to deploy Azure infrastructure using Terraform
- ✅ How to configure secrets and authentication in GitHub
- ✅ How to create a Virtual Machine with secure Bastion access
- ✅ How pipeline steps work and flow together
- ✅ How to manually trigger pipelines and pass parameters
- ✅ Best practices for Infrastructure as Code (IaC)

## 🏗️ What Gets Deployed

This lab deploys a simple but complete Azure environment:

```
┌─────────────────────────────────────────────────────────┐
│                    Resource Group                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │           Virtual Network (10.0.0.0/16)           │  │
│  │  ┌─────────────────┐    ┌────────────────────┐    │  │
│  │  │  VM Subnet      │    │  Bastion Subnet    │    │  │
│  │  │  (10.0.1.0/24)  │    │  (10.0.2.0/26)     │    │  │
│  │  │  ┌───────────┐  │    │  ┌──────────────┐  │    │  │
│  │  │  │ Windows   │  │    │  │    Bastion   │  │    │  │
│  │  │  │ Server    │◄─┼────┼──┤     RDP      │  │    │  │
│  │  │  │  2025     │  │    │  │    Access    │  │    │  │
│  │  │  │ (Private) │  │    │  │              │  │    │  │
│  │  │  └───────────┘  │    │  └──────────────┘  │    │  │
│  │  └─────────────────┘    └────────────────────┘    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Resources Created:**

- 1× Resource Group
- 1× Virtual Network
- 2× Subnets (VM + Bastion)
- 1× Network Interface
- 1× Windows Virtual Machine (Windows Server 2025 Datacenter Azure Edition)
- 1× Azure Bastion Host
- 1× Public IP (for Bastion)

## 📋 Prerequisites

### 1. Azure Account

- Active Azure subscription
- Ability to create Service Principals

### 2. GitHub Account

- Repository to store your code
- Access to configure repository secrets

### 3. Tools

- [Terraform](https://www.terraform.io/downloads) 1.6 or later
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

## 🔐 Setup Instructions

### ✅ Pre-Flight Checklist

Before running the pipeline, you MUST complete ALL of these steps:

- [ ] **Step 0:** ⚠️ **CRITICAL** - Configure Terraform Remote Backend (state storage)
- [ ] **Step 1:** Clone/fork this repository
- [ ] **Step 2:** Create Azure Service Principal (Azure credentials)
- [ ] **Step 2b:** ⚠️ **CRITICAL** - Grant Service Principal access to backend storage
- [ ] **Step 3:** Generate strong admin password for Windows VM
- [ ] **Step 4:** Configure 6 GitHub Secrets (Azure credentials + password)
- [ ] **Step 5:** ⚠️ **CRITICAL** - Create `production` environment with reviewers
- [ ] **Step 6:** Push code to trigger pipeline

**⚠️ The pipeline WILL FAIL if Step 0, Step 2b, or Step 5 are skipped!**

---

### Step 0: Configure Terraform Remote Backend ⚠️ **REQUIRED**

**⚠️ DO THIS FIRST!** The pipeline uses a two-job architecture where state must persist between jobs.

This project requires an **Azure Storage account** to store Terraform state files. Without this, the pipeline will fail immediately when the `apply` job tries to run.

**📖 Follow the complete setup guide:** [BACKEND-SETUP.md](BACKEND-SETUP.md)

**Quick Summary:**

1. Create a resource group for state storage
2. Create a storage account (must be globally unique)
3. Create a blob container named `tfstate`
4. Update `main.tf` with your storage account details
5. Grant your Service Principal access to the storage account

**Why is this needed?**

- `plan` job runs on Runner A, creates state
- `apply` job runs on Runner B (fresh VM)
- Without remote backend, Runner B can't access Runner A's state
- Result: Pipeline fails or tries to recreate all resources

---

### Step 1: Fork or Clone this Repository

```bash
git clone https://github.com/YourUsername/MyFirstPipeline.git
cd MyFirstPipeline
```

### Step 2: Create Azure Service Principal

You need credentials for Terraform to create resources in Azure:

```bash
# Login to Azure
az login

# Create Service Principal with Contributor role
az ad sp create-for-rbac \
  --name "github-terraform-deploy" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

**This outputs JSON like:**

```json
{
  "clientId": "00000000-0000-0000-0000-000000000000",
  "clientSecret": "your-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

**Save this entire JSON output somewhere 📝** - you'll need it for GitHub secrets!

**⚠️ IMPORTANT:** The Contributor role allows creating Azure resources BUT does NOT grant access to storage blob data. You MUST also grant the Service Principal access to your backend storage account (see Step 0 backend setup - "Grant Pipeline Access" section).

### Step 3: Generate Strong Admin Password

The Windows VM needs a secure password for authentication. Create one that meets Azure's requirements:

**Password Requirements:**

- 12-123 characters long
- Must contain characters from 3 of the following: lowercase, uppercase, numbers, special characters
- Cannot contain the username

**Example:** `MySecure!Pass2025`

**Save this password securely** - you'll add it to GitHub secrets!

### Step 4: Configure GitHub Secrets

Navigate to your GitHub repository:

**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value | Where to Get It |
|------------|-------|-----------------|
| `AZURE_CREDENTIALS` | Full JSON from Service Principal creation | Step 2 output |
| `AZURE_CLIENT_ID` | `clientId` from JSON | Service Principal JSON |
| `AZURE_CLIENT_SECRET` | `clientSecret` from JSON | Service Principal JSON |
| `AZURE_SUBSCRIPTION_ID` | `subscriptionId` from JSON | Service Principal JSON |
| `AZURE_TENANT_ID` | `tenantId` from JSON | Service Principal JSON |
| `ADMIN_PASSWORD` | Your secure Windows admin password | Step 3 password |

**🔒 Security Note:** The `ADMIN_PASSWORD` secret is passed to Terraform using the `TF_VAR_admin_password` environment variable. This is more secure than command-line arguments because:

- Secrets don't appear in command-line logs
- Reduced exposure risk if Terraform errors occur
- Industry standard for secret management in CI/CD pipelines

### Step 5: Configure Approval Environment ⚠️ **REQUIRED**

**⚠️ IMPORTANT:** The pipeline will **fail** without this step! The approval gate is configured in code but requires environment setup.

Set up manual approval gate to prevent accidental deployments:

1. **Navigate to your repository on GitHub**
   - Go to: `https://github.com/YourUsername/lab-terraform-myfirstpipeline`

2. **Access Environment Settings**
   - Click **Settings** tab (top of repository)
   - In left sidebar, scroll down to **Environments** (under "Code and automation")
   - Click **Environments**

3. **Create Production Environment**
   - Click **New environment** button (green button, top right)
   - Enter environment name: `production` (⚠️ must be exactly this - lowercase, no spaces)
   - Click **Configure environment**

4. **Configure Protection Rules**
   - Under **Deployment protection rules**, check ✅ **Required reviewers**
   - Click **Add up to 6 reviewers**
   - Search and add:
     - Your GitHub username
     - Team members who should approve deployments (optional)
   - **Optionally configure:**
     - **Wait timer**: Minimum time before approval (0 minutes = no wait)
     - **Deployment branches**: Leave as "All branches" or specify `main` only for this lab

5. **Save Configuration**
   - Click **Save protection rules** button at bottom

**Verification Steps:**

After configuration, you should see:

- Environment name: `production`
- Required reviewers: ✅ (with your username listed)
- Protection rules: Active

**What happens without this:**

- ❌ Pipeline fails with: "Environment protection rules not satisfied"
- ❌ No approval button appears
- ❌ Infrastructure cannot be deployed

**What this enables:**

- ✅ Pipeline pauses after Plan step
- ✅ "Review deployments" button appears in Actions
- ✅ Only designated reviewers can approve
- ✅ Audit trail of who approved what and when

**Troubleshooting:**

- **Can't find Environments?** → You need repository admin permissions
- **Environment name mismatch?** → Must be exactly `production` (lowercase)
- **No reviewers available?** → Check collaborator access on repository

### Step 6: Push and Deploy

```bash
# Make sure you're on main branch
git checkout main

# Push your code
git add .
git commit -m "Initial commit: My first pipeline"
git push origin main
```

The pipeline will automatically trigger! 🎉

## 📊 Understanding the Pipeline

The pipeline is split into **two separate jobs** with a **manual approval gate** between them:

### 📋 Job 1: Plan Infrastructure

This job validates your code and creates a deployment plan for review:

1. **Checkout Repository** - Downloads your code
2. **Setup Terraform** - Installs Terraform CLI
3. **Azure Login** - Authenticates with Azure
4. **Terraform Init** - Prepares Terraform workspace
5. **Terraform Validate** - Checks configuration syntax
6. **Terraform Format Check** - Ensures consistent code style
7. **Terraform Plan** - Creates execution plan for review (logs output only)

**⏸️ PIPELINE PAUSES HERE** - Awaiting manual approval

- Review the plan output in the GitHub Actions logs
- Check what resources will be created/changed/destroyed
- Approve to continue or reject to cancel

### 🚀 Job 2: Apply Infrastructure (After Approval)

This job only runs after Job 1 succeeds AND you manually approve:

1. **Checkout Repository** - Downloads your code (fresh runner)
2. **Setup Terraform** - Installs Terraform CLI
3. **Azure Login** - Authenticates with Azure
4. **Terraform Init** - Initializes Terraform
5. **Terraform Apply** - Runs fresh apply to create resources in Azure
6. **Terraform Output** - Shows connection information
7. **Terraform Destroy** - (Optional) Removes all resources (manual trigger only)

### 🎯 Secure Pattern for GitHub Actions

**This workflow implements a secure review pattern:**

- ✅ **No Stored Plans**: Plan output is logged for review but NOT saved to files
- ✅ **Prevents Secret Leakage**: Avoids storing sensitive data in plan artifacts
- ✅ **Manual Review Gate**: Human approval required before any changes
- ✅ **Clear Separation**: Planning and execution are distinct phases
- ✅ **Better Visibility**: GitHub Actions UI clearly shows which phase is running/waiting
- ✅ **Independent Authentication**: Each job authenticates separately on fresh runners
- ✅ **Audit Trail**: Complete logs show what was planned and what was applied

**Want detailed explanations?** Check out [PIPELINE-README.md](PIPELINE-README.md) for line-by-line breakdowns!

## 🎮 How to Use

### Reviewing and Approving Deployments

When the pipeline runs, it will pause after the Plan step:

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Review the Terraform Plan output in the logs
4. Click **Review deployments** button
5. Select **production** environment
6. **Approve** (to proceed with deployment) or **Reject** (to cancel)
7. Add optional comment explaining your decision
8. Click **Approve deployments** or **Reject deployments**

**✅ If Approved:** Pipeline continues and applies the infrastructure changes

**❌ If Rejected:** Pipeline stops immediately, no resources are created/modified

### Automatic Deployment

Push any changes to `main` branch:

```bash
git add .
git commit -m "Update infrastructure"
git push origin main
```

Pipeline runs automatically and pauses at the approval gate! Review the plan and approve to continue.

### Manual Deployment

1. Go to **Actions** tab in GitHub
2. Select **Deploy VM with Bastion** workflow
3. Click **Run workflow**
4. Choose branch: `main`
5. Set destroy to `false`
6. Click **Run workflow**
7. Wait for plan to complete, then approve the deployment

### Destroying Resources

**⚠️ This removes everything!**

1. Go to **Actions** tab
2. Select **Deploy VM with Bastion** workflow
3. Click **Run workflow**
4. Choose branch: `main`
5. Set destroy to `true`
6. Click **Run workflow**
7. Review the destruction plan and approve

**Note:** Destroy operations also require approval to prevent accidental deletion.

## 🔌 Connecting to Your VM

After deployment, you can connect to your Windows Server 2025 VM via Azure Bastion:

1. Go to the [Azure Portal](https://portal.azure.com)
2. Navigate to **Virtual machines** → `vm-myfirstpipeline`
3. Click **Connect** → **Bastion**
4. Enter username: `azureadmin`
5. Enter the admin password you configured
6. Click **Connect**

A Remote Desktop session will open in your browser - no RDP client needed! 🔐

## 📁 Project Structure

```
My-First-Pipeline/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions pipeline (heavily commented!)
├── main.tf                     # Main Terraform configuration (with backend config)
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example variable values
├── .gitignore                  # Git ignore rules
├── README.md                   # This file (main setup guide)
├── BACKEND-SETUP.md            # Backend state storage setup guide
└── PIPELINE-README.md          # Detailed pipeline explanation
```

## 🎓 Learning Resources

### Understanding the YAML Pipeline

The pipeline uses a **secure two-job architecture** with manual approval gates. Every line is documented with comments. Open [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) to see:

- Why each job and step exists
- What each command does
- How jobs and steps connect together
- When and why approval gates trigger
- How the secure pattern prevents secret leakage

### Key Concepts Covered

**YAML Pipelines:**

- Triggers (`on`)
- Jobs and steps
- Environment variables
- Secrets management
- Conditional execution (`if`)
- Manual triggers (`workflow_dispatch`)
- Approval gates between jobs

**Terraform:**

- Provider configuration
- Resource blocks
- Variables and outputs
- State management
- Plan and apply workflow

**Azure:**

- Virtual Networks and Subnets
- Virtual Machines
- Azure Bastion (secure access)
- Service Principals
- Resource naming conventions

## 🔧 Customisation

### Change VM Size

Edit `variables.tf`:

```hcl
variable "vm_size" {
  default     = "Standard_B2s"  # Change to Standard_D2s_v3, etc.
}
```

### Change Location

Edit `variables.tf`:

```hcl
variable "location" {
  default     = "uksouth"  # Change to eastus, westeurope, etc.
}
```

### Use Different OS

Edit `main.tf` in the `source_image_reference` block to change Windows versions:

```hcl
# Windows Server 2025 (default)
source_image_reference {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2025-datacenter-azure-edition"
  version   = "latest"
}

# Or use Windows Server 2022
source_image_reference {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2022-datacenter-azure-edition"
  version   = "latest"
}
```

## 🚨 Troubleshooting

### Pipeline Fails at Azure Login

**Problem:** `AZURE_CREDENTIALS` secret is invalid

**Solution:**

- Verify JSON format is correct
- Ensure Service Principal has Contributor role
- Check subscription ID is correct

### Pipeline Stuck at "Waiting for Approval"

**Problem:** No one is designated as a reviewer

**Solution:**

- Go to Settings → Environments → Production
- Add required reviewers
- Ensure you have permission to approve (repository admin or designated reviewer)

### Can't Connect to VM

**Problem:** Bastion not deployed or wrong password

**Solution:**

- Wait 5-10 minutes after deployment for Bastion to be ready
- Verify you're using the correct password from GitHub secrets
- Check outputs in pipeline logs for connection info
- Ensure password meets Azure complexity requirements

### "Context access might be invalid" Warnings

**Problem:** Linter warnings about secrets

**Solution:**

- These are just warnings, not errors
- Secrets must be configured in GitHub first
- Pipeline will work once secrets are added

**💡 Tips:**

- Run the destroy workflow when not using the lab to avoid costs💹🤑
- GitHub Actions runners are **free for public repositories**
- The pipeline's two-job architecture uses ~2-3 minutes of runner time (Plan job) before pausing for approval

## 📸 Visual Setup Guide

### Setting Up GitHub Environment (Screenshots Reference)

**Step-by-Step Visual Guide:**

1. **Repository Settings Page**

   ```
   Your Repo → Settings (tab) → Environments (sidebar)
   URL: https://github.com/YourUsername/lab-terraform-myfirstpipeline/settings/environments
   ```

2. **Create New Environment**
   - Look for green "New environment" button
   - Enter: `production`
   - Click "Configure environment"

3. **Protection Rules Section**
   - Scroll to "Environment protection rules"
   - Check box: ☑️ Required reviewers
   - Click "Add up to 6 reviewers" dropdown
   - Select your username

4. **Confirmation**
   - You should see: "✅ 1 reviewer(s) required"
   - Your username listed
   - Click "Save protection rules"

5. **Verify Setup**
   - Navigate to: Settings → Environments
   - You should see: `production` environment listed
   - Status: Protected (with shield icon)
   - Reviewers: Your username shown

### Approval Workflow Visual Guide

**When Pipeline Runs:**

1. **Actions Tab View**

   ```
   Running → Plan (✓ completed) → Apply (⏸️ waiting)
   Yellow banner: "This workflow is waiting for approval"
   Button: "Review deployments"
   ```

2. **Review Dialog**

   ```
   Environment: production
   Reviewers required: 1
   [Comment box: "Reviewed plan, approving deployment"]
   Buttons: [Approve and deploy] [Reject]
   ```

3. **After Approval**

   ```
   Apply (⚡ running) → Output (pending)
   Green checkmark when complete
   ```

**Quick Reference URLs:**

- Environment setup: `https://github.com/YourUsername/YourRepo/settings/environments`
- Secrets setup: `https://github.com/YourUsername/YourRepo/settings/secrets/actions`
- Actions view: `https://github.com/YourUsername/YourRepo/actions`

## ⚠️ Important Notice: Lab Environment Only

This is an educational lab designed for learning YAML pipelines and Terraform basics. The workflow implements a secure pattern for GitHub Actions that prevents storing sensitive plan files. Before using similar patterns in production:

- Implement proper state locking mechanisms
- Configure network security groups and firewall rules
- Implement Azure Policy for governance
- Add comprehensive monitoring and alerts
- Use managed identities instead of Service Principals
- Implement proper secret rotation policies
- Review and harden backend storage security
- Consider additional security controls based on your requirements

**State Storage:** This lab uses Azure Storage for remote state. Ensure proper access controls and encryption are configured. See [BACKEND-SETUP.md](BACKEND-SETUP.md) for security best practices if using in Production environments.

## 📚 Next Steps

After completing this lab:

1. ✅ Modify the pipeline to add approval gates
2. ✅ Add multiple environments (dev/staging/prod)
3. ✅ Implement Terraform workspaces
4. ✅ Add automated testing steps
5. ✅ Create reusable Terraform modules... Maybe even some AVM's 👀
6. ✅ Explore [lab-terraform-workspace](https://github.com/TheAzureCorner/lab-terraform-workspace) for advanced patterns

## 📄 Licence

This project is licenced under the MIT Licence.

---

**Ready to learn?** Follow the setup steps and run your first pipeline! 🚀

**Questions?** Check [PIPELINE-README.md](PIPELINE-README.md) for detailed pipeline explanations.
