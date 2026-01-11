# Cognito Module

This module creates an AWS Cognito User Pool with OAuth 2.0 configuration for user authentication.

## Features

- User Pool with email-based authentication
- Password policy enforcement
- OAuth 2.0 with authorization code and implicit flows
- Automatic email verification
- User attributes (email, name, phone)
- Token management (access, ID, refresh tokens)
- Account recovery via email

## Resources Created

- **Cognito User Pool**: Main user directory
- **Cognito User Pool Domain**: Hosted UI domain
- **Cognito User Pool Client**: OAuth client configuration

## Usage

```hcl
module "cognito" {
  source = "./modules/cognito"

  project_name    = "lexiclab"
  environment     = "prod"
  application_url = "http://${module.alb.alb_dns_name}"

  deletion_protection = true

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## OAuth Flow

1. **User initiates login**: Application redirects to Cognito hosted UI
2. **User authenticates**: Enters credentials on Cognito page
3. **Cognito redirects**: Sends authorization code to callback URL
4. **Application exchanges code**: Trades code for tokens
5. **User authenticated**: Application uses tokens for API calls

## Callback URLs

The module automatically configures these callback URLs:
- `${application_url}/api/auth/sign-in` - Backend authentication endpoint
- `${application_url}/auth/callback` - Frontend callback

## Logout URLs

- `${application_url}/api/auth/sign-out` - Backend logout endpoint
- `${application_url}/` - Redirect to home page after logout

## OAuth Scopes

Enabled scopes:
- `email` - Access to user's email address
- `openid` - OpenID Connect support
- `phone` - Access to user's phone number
- `profile` - Access to user's profile information

## Token Validity

- **Access Token**: 60 minutes
- **ID Token**: 60 minutes
- **Refresh Token**: 30 days

## Security Features

- Advanced security mode: AUDIT (tracks suspicious activity)
- Token revocation enabled
- User existence errors prevented (security best practice)
- Password policy: 8+ chars with uppercase, lowercase, numbers, symbols

## Outputs

- `user_pool_id` - Use in application configuration
- `client_id` - Use in application configuration
- `cognito_url` - Hosted UI URL for login
- `domain` - Cognito domain name

## Creating Users

### Via AWS Console
1. Go to Cognito User Pools
2. Select your user pool
3. Click "Create user"
4. Enter email and temporary password
5. User will be prompted to change password on first login

### Via AWS CLI
```bash
aws cognito-idp admin-create-user \
  --user-pool-id <user-pool-id> \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password TempPass123! \
  --message-action SUPPRESS
```

### Via Terraform (not recommended for production)
Use `aws_cognito_user` resource for test users only.

## Integration with Applications

### NestJS API Configuration
```typescript
// Use these environment variables
COGNITO_URL=<cognito_url output>
COGNITO_CLIENT_ID=<client_id output>
COGNITO_USER_POOL_ID=<user_pool_id output>
COGNITO_SCOPE=email+openid+phone
COGNITO_LOGIN_REDIRECT_URL=http://<alb-dns>/api/auth/sign-in
GOGNITO_LOGIN_SUCCESS_URL=http://<alb-dns>/
```

### React UI Configuration
```typescript
// Use these environment variables
COGNITO_URL=<cognito_url output>
COGNITO_CLIENT_ID=<client_id output>
COGNITO_USER_POOL_ID=<user_pool_id output>
COGNITO_SCOPE=email+openid+phone
COGNITO_LOGIN_REDIRECT_URL=http://<alb-dns>/api/auth/sign-in
COGNITO_LOGOUT_REDIRECT_URL=http://<alb-dns>/api/auth/sign-out
GOGNITO_LOGIN_SUCCESS_URL=http://<alb-dns>/
```

## Deletion Protection

By default, deletion protection is enabled to prevent accidental user pool deletion. To allow deletion:

```hcl
module "cognito" {
  source = "./modules/cognito"

  deletion_protection = false
  # ...
}
```

## Cost

AWS Cognito pricing (as of 2024):
- **First 50,000 MAUs**: Free
- **50,001 - 100,000 MAUs**: $0.0055 per MAU
- **100,001+ MAUs**: Volume discounts apply

For 10-50 users: **FREE** (well within free tier)

MAU = Monthly Active Users (users who authenticate within a calendar month)

## Common Issues

### Callback URL Mismatch
**Error**: `redirect_uri_mismatch`
**Solution**: Ensure application callback URLs match exactly (including protocol and trailing slashes)

### CORS Errors
**Solution**: Configure CORS in your API to allow Cognito domain:
```typescript
cors: {
  origin: ['https://<cognito-domain>.auth.eu-central-1.amazoncognito.com'],
  credentials: true
}
```

### Token Expired
**Solution**: Implement automatic token refresh using the refresh token before access token expires

## Migration from Local Development

If you have users in your local Cognito:

1. **Export users** (if needed):
   ```bash
   aws cognito-idp list-users --user-pool-id <old-pool-id>
   ```

2. **Deploy new production Cognito** with Terraform

3. **Recreate users** in production pool (users will need to reset passwords)

4. **Update application configs** with new Cognito values

5. **Test authentication flow** before going live

## Additional Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [OAuth 2.0 Flow](https://oauth.net/2/)
- [OpenID Connect](https://openid.net/connect/)
