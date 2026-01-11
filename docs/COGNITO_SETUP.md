# AWS Cognito Setup for Production

## Overview

Your Terraform infrastructure now includes an **automated AWS Cognito User Pool** that will be created specifically for your production environment. This replaces the local development Cognito configuration with a production-ready setup.

## What Changed

### Before (Local Development)
- Used hardcoded Cognito values from local environment
- Callback URLs pointed to `localhost:5173`
- Manual configuration required in `terraform.tfvars`

### After (Production)
- Terraform automatically creates a new Cognito User Pool
- Callback URLs automatically configured with your ALB DNS
- Zero manual configuration needed
- Completely separate from your local development Cognito

## How It Works

When you run `terraform apply`, the infrastructure will:

1. **Create Application Load Balancer** with DNS name
2. **Create Cognito User Pool** with production settings
3. **Configure OAuth callbacks** using the ALB DNS:
   - Login redirect: `http://<alb-dns>/api/auth/sign-in`
   - Logout redirect: `http://<alb-dns>/api/auth/sign-out`
   - Frontend callback: `http://<alb-dns>/auth/callback`
4. **Inject Cognito values** into ECS environment variables automatically

## Cognito Configuration

### User Pool Settings
- **Authentication**: Email-based (username = email)
- **Auto-verification**: Email addresses verified automatically
- **Password Policy**: 8+ characters with uppercase, lowercase, numbers, symbols
- **Security Mode**: AUDIT (tracks suspicious activity)
- **Token Validity**:
  - Access Token: 60 minutes
  - ID Token: 60 minutes
  - Refresh Token: 30 days

### OAuth 2.0 Configuration
- **Flows**: Authorization code, Implicit
- **Scopes**: email, openid, phone, profile
- **Callback URLs**: Automatically configured with ALB DNS
- **Logout URLs**: Automatically configured with ALB DNS

## Deployment Steps

### 1. Deploy Infrastructure

```bash
cd /Users/pavloprovectus/Documents/my-projects/lexiclab-aws

# Initialize Terraform (if not already done)
terraform init

# Review what will be created (including Cognito)
terraform plan

# Deploy everything (this creates Cognito User Pool)
terraform apply
```

### 2. Get Cognito Information

After deployment, get the Cognito configuration:

```bash
# Get all Cognito outputs
terraform output cognito_user_pool_id
terraform output cognito_client_id
terraform output cognito_url
terraform output cognito_domain
```

Example output:
```
cognito_user_pool_id = "eu-central-1_AbCdEfGhI"
cognito_client_id = "1a2b3c4d5e6f7g8h9i0j1k2l3m"
cognito_url = "https://lexiclab-prod-123456789012.auth.eu-central-1.amazoncognito.com"
cognito_domain = "lexiclab-prod-123456789012"
```

### 3. Verify Cognito in AWS Console

1. Go to [AWS Cognito Console](https://console.aws.amazon.com/cognito/)
2. Select **User Pools**
3. Find **lexiclab-prod-user-pool**
4. Verify settings:
   - **App Integration** → Check callback URLs match your ALB
   - **Sign-in experience** → Should be Email
   - **Password policies** → Should match configuration

### 4. Create Your First User

#### Option A: AWS Console (Recommended for first user)
1. In Cognito User Pool → **Users** tab
2. Click **Create user**
3. Enter:
   - **Email**: your-email@example.com
   - **Temporary password**: TempPass123!
   - Check "Mark email as verified"
4. Click **Create user**
5. User will be prompted to change password on first login

#### Option B: AWS CLI
```bash
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS
```

### 5. Test Authentication Flow

1. Get your application URL:
   ```bash
   terraform output application_url
   ```

2. Visit the URL in your browser: `http://<alb-dns>/`

3. Try to access a protected route (should redirect to Cognito login)

4. Login with the user you created:
   - Enter email and temporary password
   - You'll be prompted to set a new password
   - After changing password, you'll be redirected back to your app

## Environment Variables

The Cognito module automatically configures these environment variables for both API and UI:

### API Environment Variables
```bash
COGNITO_URL=https://lexiclab-prod-123456789012.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=1a2b3c4d5e6f7g8h9i0j1k2l3m
COGNITO_USER_POOL_ID=eu-central-1_AbCdEfGhI
COGNITO_SCOPE=email+openid+phone
COGNITO_LOGIN_REDIRECT_URL=http://<alb-dns>/api/auth/sign-in
GOGNITO_LOGIN_SUCCESS_URL=http://<alb-dns>/
```

### UI Environment Variables
```bash
COGNITO_URL=https://lexiclab-prod-123456789012.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=1a2b3c4d5e6f7g8h9i0j1k2l3m
COGNITO_USER_POOL_ID=eu-central-1_AbCdEfGhI
COGNITO_SCOPE=email+openid+phone
COGNITO_LOGIN_REDIRECT_URL=http://<alb-dns>/api/auth/sign-in
COGNITO_LOGOUT_REDIRECT_URL=http://<alb-dns>/api/auth/sign-out
GOGNITO_LOGIN_SUCCESS_URL=http://<alb-dns>/
```

**You don't need to configure these manually** - Terraform injects them automatically into your ECS tasks.

## Local Development vs Production

### Local Development (.env)
Keep your existing local Cognito configuration:
```bash
# lexiclab-nest-api/.env
COGNITO_URL=https://eu-central-1fack0ybkw.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=1nfu9sp6m2n47dv7i03t57957i
COGNITO_USER_POOL_ID=eu-central-1_fAck0yBkw
COGNITO_LOGIN_REDIRECT_URL=http://localhost:5173/api/auth/sign-in
GOGNITO_LOGIN_SUCCESS_URL=http://localhost:5173/
```

### Production (Terraform-managed)
Production uses completely separate Cognito User Pool with ALB URLs:
```bash
# Automatically configured by Terraform
COGNITO_URL=https://lexiclab-prod-123456789012.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=<auto-generated>
COGNITO_USER_POOL_ID=<auto-generated>
COGNITO_LOGIN_REDIRECT_URL=http://<alb-dns>/api/auth/sign-in
GOGNITO_LOGIN_SUCCESS_URL=http://<alb-dns>/
```

## Managing Users

### Adding New Users

**Via AWS Console:**
1. Cognito User Pools → lexiclab-prod-user-pool → Users
2. Create user → Enter email and temporary password
3. User receives temporary password (or you share it)
4. User logs in and changes password

**Via AWS CLI:**
```bash
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username new-user@example.com \
  --user-attributes Name=email,Value=new-user@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!"
```

### Deleting Users

**Via AWS Console:**
1. Cognito User Pools → lexiclab-prod-user-pool → Users
2. Select user → Actions → Delete user

**Via AWS CLI:**
```bash
aws cognito-idp admin-delete-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username user@example.com
```

### Resetting User Password

**Via AWS Console:**
1. Cognito User Pools → lexiclab-prod-user-pool → Users
2. Select user → Actions → Reset password
3. New temporary password is sent to user's email

**Via AWS CLI:**
```bash
aws cognito-idp admin-reset-user-password \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username user@example.com
```

## Updating Callback URLs

If you add a custom domain or change your application URL, you'll need to update the Cognito module:

1. Edit `main.tf`:
   ```hcl
   module "cognito" {
     source = "./modules/cognito"

     project_name    = local.project_name
     environment     = local.environment
     application_url = "https://your-custom-domain.com"  # Update this

     # ...
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

3. Force ECS redeployment to pick up new environment variables:
   ```bash
   ./scripts/update-task.sh
   ```

## Security Considerations

### Deletion Protection
By default, the Cognito User Pool has **deletion protection enabled**. This prevents accidental deletion of your user directory.

To disable (not recommended for production):
```hcl
module "cognito" {
  source = "./modules/cognito"

  deletion_protection = false  # Allow deletion

  # ...
}
```

### Password Policy
The default password policy requires:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one symbol

This is configurable in `modules/cognito/main.tf`.

### Multi-Factor Authentication (MFA)
To enable MFA, edit `modules/cognito/main.tf`:

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # Add MFA configuration
  mfa_configuration = "OPTIONAL"  # or "ON" to require MFA

  software_token_mfa_configuration {
    enabled = true
  }

  # ... rest of configuration
}
```

## Cost

AWS Cognito pricing:
- **First 50,000 MAUs**: FREE
- **50,001 - 100,000 MAUs**: $0.0055 per MAU
- **100,001+ MAUs**: Volume discounts

**For 10-50 users: FREE** (well within free tier)

MAU = Monthly Active Users (users who authenticate within a calendar month)

## Troubleshooting

### Error: "redirect_uri_mismatch"
**Cause**: Application callback URL doesn't match Cognito configuration
**Solution**:
1. Check callback URLs in Cognito console match your ALB DNS
2. Run `terraform apply` to update Cognito configuration
3. Force ECS redeployment: `./scripts/update-task.sh`

### Error: "User pool domain already exists"
**Cause**: Domain name collision
**Solution**: The domain is unique per AWS account. If you get this error, edit `modules/cognito/main.tf` and change the domain suffix.

### Users Can't Log In
**Checklist**:
1. Verify user exists in Cognito console
2. Check user's email is verified
3. Ensure user has confirmed their account (changed temporary password)
4. Check application logs for specific authentication errors:
   ```bash
   aws logs tail /ecs/lexiclab-prod-api --follow
   ```

### Environment Variables Not Updated
**Solution**: After changing Cognito configuration, force ECS redeployment:
```bash
./scripts/update-task.sh
```

## Migration from Local Cognito

If you have test users in your local Cognito that you want to migrate:

### Option 1: Manual Recreation (Recommended for small numbers)
1. Export user list from local Cognito
2. Manually create users in production Cognito
3. Users will need to set new passwords

### Option 2: Cognito User Import
For larger user bases, use [AWS Cognito User Import](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-using-import-tool.html):
1. Export users from local Cognito
2. Format as CSV
3. Use Cognito import tool to bulk import

**Note**: Password migration is not possible - users must reset passwords.

## Additional Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OpenID Connect](https://openid.net/connect/)
- [Cognito User Pool Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings.html)

## Summary

Your production Cognito setup is now:
- ✅ Automatically created by Terraform
- ✅ Configured with correct production URLs
- ✅ Separate from local development
- ✅ Ready to use (just create users)
- ✅ Free for 10-50 users
- ✅ Production-grade security settings

No manual Cognito configuration needed in `terraform.tfvars`!
