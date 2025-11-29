# 🗄️ Terraform Backend Setup Guide

## Why You Need This

This pipeline uses a **two-job architecture** where the `plan` job and `apply` job run on **different virtual machines**. Without a remote backend, the Terraform state created during the `plan` job is **lost** when that runner terminates, causing the `apply` job to fail or try to recreate resources.

**Remote backend = State persistence across pipeline jobs** ✅

---

## ⚠️ CRITICAL: Complete This BEFORE Running the Pipeline

The backend storage account **must exist** before you run `terraform init`. If you skip this step, the pipeline will fail immediately.

---

## 📋 Prerequisites

- **Azure CLI** installed ([Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Active Azure subscription**
- **Contributor access** to create all necessary resources

---

## 🚀 Step-by-Step Setup

### Step 1: Login to Azure

```bash
az login
```

**Output:** Browser window opens for authentication. After login, you'll see your subscriptions listed.

### Step 2: Set Your Subscription (if you have multiple)

```bash
# List all subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME"

# Verify it's set correctly
az account show --output table
```

### Step 3: Define Variables

**Choose unique names for your resources:**

```bash
# Set variables (customize these!)
RESOURCE_GROUP_NAME="rg-terraform-state"
LOCATION="uksouth"  # Change to your preferred Azure region
STORAGE_ACCOUNT_NAME="sttfstatemyfirstpipe"  # MUST be globally unique (3-24 chars, lowercase/numbers only)
CONTAINER_NAME="tfstate"
```

**⚠️ Important Notes:**

- `STORAGE_ACCOUNT_NAME` must be **globally unique** across all of Azure
- Only lowercase letters and numbers (no hyphens, underscores, or special characters)
- Between 3-24 characters long
- Consider adding your initials or random numbers: `sttfstatejdoe123`

### Step 4: Create Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $LOCATION
```

**Expected Output:**

```json
{
  "id": "/subscriptions/.../resourceGroups/rg-terraform-state",
  "location": "uksouth",
  "name": "rg-terraform-state",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

### Step 5: Create Storage Account

```bash
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
```

**What these flags do:**

- `--sku Standard_LRS` - Locally redundant storage (cheapest option, good for dev/test)
- `--encryption-services blob` - Encrypts blob storage at rest
- `--https-only true` - Enforces HTTPS connections only
- `--min-tls-version TLS1_2` - Requires TLS 1.2 or higher
- `--allow-blob-public-access false` - Prevents public access to blobs

**Expected Output:**

```json
{
  "name": "sttfstatemyfirstpipe",
  "provisioningState": "Succeeded",
  "primaryEndpoints": {
    "blob": "https://sttfstatemyfirstpipe.blob.core.windows.net/"
  }
}
```

### Step 6: Create Blob Container

```bash
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login
```

**Expected Output:**

```json
{
  "created": true
}
```

### Step 7: Enable Versioning (Optional but Recommended)

Blob versioning allows you to recover previous versions of your state file if something goes wrong.

```bash
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-versioning true
```

**Expected Output:**

```json
{
  "isVersioningEnabled": true
}
```

### Step 8: Verify Setup

```bash
# Check resource group exists
az group show --name $RESOURCE_GROUP_NAME --output table

# Check storage account exists
az storage account show \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --output table

# Check container exists
az storage container show \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login \
  --output table
```

**All commands should return information** (not errors) ✅

---

## 🔧 Configure Terraform Backend

Now update `main.tf` in your repository with the values you just created:

```terraform
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"              # From Step 3
  storage_account_name = "sttfstatemyfirstpipe"            # From Step 3 (your unique name)
  container_name       = "tfstate"                         # From Step 3
  key                  = "myfirstpipeline.tfstate"         # Unique name for this project's state
}
```

**Commit and push your changes:**

```bash
git add main.tf
git commit -m "Configure remote backend for state storage"
git push origin main
```

---

## 🔐 Grant Pipeline Access to Backend (REQUIRED)

Your GitHub Actions pipeline needs permission to read/write to the backend storage account. **This step is MANDATORY** - without it, terraform init will fail.

### Get Your Service Principal's App ID

First, get the App ID (also called Client ID) of the Service Principal you created in the main README:

```bash
# Option 1: If you saved the JSON output, the clientId is your App ID
# Look for "clientId" in the JSON from Step 2 of the README

# Option 2: Look it up by display name
az ad sp list --display-name "github-terraform-deploy" --query "[].appId" --output tsv
```

**Save this App ID** - you'll use it in the next step.

### Grant Storage Blob Data Contributor Role

```bash
# Set variables (use the values from your backend setup)
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="sttfstatemyfirstpipe"  # Your storage account name
SP_APP_ID="<YOUR_SERVICE_PRINCIPAL_APP_ID>"  # From above

# Grant Storage Blob Data Contributor role
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $SP_APP_ID \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"
```

**Expected Output:**

```json
{
  "principalId": "...",
  "principalName": "...",
  "roleDefinitionName": "Storage Blob Data Contributor",
  "scope": "/subscriptions/.../storageAccounts/sttfstatemyfirstpipe"
}
```

**What this does:**

- Grants the Service Principal **Storage Blob Data Contributor** role
- Scoped specifically to your backend storage account
- Allows reading/writing state files in the blob container
- Does NOT grant access to other storage accounts

### Verify Permissions

```bash
# List all role assignments for the Service Principal on the storage account
az role assignment list \
  --assignee $SP_APP_ID \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME" \
  --output table
```

**You should see TWO roles:**

1. ✅ **Contributor** (from subscription-level assignment)
2. ✅ **Storage Blob Data Contributor** (from this step)

---

## ⚠️ Alternative: Access Keys (Not Recommended)

If you have issues with Entra ID authentication, you can use access keys as a fallback. **This is less secure** and not recommended for production. Your personal LAB is fine, but avoid in real projects.

### Configure Backend to Use Access Keys

Add these to your backend configuration in `main.tf`:

```terraform
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "sttfstatemyfirstpipe"
  container_name       = "tfstate"
  key                  = "myfirstpipeline.tfstate"
  use_azuread_auth     = true  # Use Azure AD authentication (recommended)
}
```

---

## 🧪 Test Locally (Optional)

Before running the pipeline, test that the backend works locally:

```bash
# Navigate to your project directory
cd My-First-Pipeline

# Initialize Terraform (should connect to remote backend)
terraform init

# You should see:
# "Successfully configured the backend "azurerm"!"
```

**Expected Output:**

```
Initializing the backend...

Successfully configured the backend "azurerm"!

Terraform has been successfully initialized!
```

**If you see errors:**

- Check your backend configuration values match what you created
- Verify you're logged in: `az account show`
- Verify permissions on the storage account

---

## 🔒 Security Best Practices

### 1. Enable Soft Delete

Protect against accidental deletion:

```bash
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-delete-retention true \
  --delete-retention-days 30
```

### 2. Restrict Network Access (Production)

For production workloads, Private Endpoint on Storage Accounts coupled with Private Runners:

**⚠️ Warning:** Overkill for today's labs but keep in mind for Production.

### 3. Enable Storage Account Logs

Monitor access to your state file:

```bash
az monitor diagnostic-settings create \
  --name "tfstate-logging" \
  --resource "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME" \
  --logs '[{"category": "StorageRead", "enabled": true}, {"category": "StorageWrite", "enabled": true}]' \
  --workspace "<LOG_ANALYTICS_WORKSPACE_ID>"
```

---

## 🧹 Cleanup (When Done with the Lab)

To remove the backend infrastructure:

```bash
# Delete the entire resource group (includes storage account and container)
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```

**⚠️ Warning:** This deletes your state file permanently! Only do this when you're completely done with the lab and have destroyed all deployed infrastructure.

---

## 🆘 Troubleshooting

### Error: "storage account name already exists"

**Cause:** Storage account names must be globally unique across all of Azure.

**Fix:** Choose a different name in Step 3:

```bash
STORAGE_ACCOUNT_NAME="sttfstate$(whoami)$(date +%s)"  # Adds username + timestamp
```

### Error: "authorisation permission mismatch"

**Cause:** Your Azure account doesn't have permission to create storage accounts.

**Fix:** Ask your Azure admin for Contributor role, or use a different subscription.

### Error: "backend initialization required"

**Cause:** You modified the backend configuration after already running `terraform init`.

**Fix:** Re-run terraform init:

```bash
terraform init -reconfigure
```

### Error: "Failed to get existing workspaces"

**Cause:** Service Principal doesn't have access to the storage account.

**Fix:** Grant Storage Blob Data Contributor role (see "Grant Pipeline Access" section above).

---

## 📚 Additional Resources

- [Terraform Azure Backend Documentation](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Account Security](https://learn.microsoft.com/en-us/azure/storage/common/storage-security-guide)
- [Terraform State Management Best Practices](https://www.terraform.io/docs/language/state/index.html)

---

**✅ Setup Complete!** You're now ready to run the pipeline with proper state persistence.

Return to [README.md](README.md#step-1-configure-terraform-remote-backend-) to continue with the main setup process.
