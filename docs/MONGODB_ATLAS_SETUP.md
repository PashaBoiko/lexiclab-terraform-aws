# MongoDB Atlas Setup for Cost-Optimized Configuration

Since your infrastructure does **not use NAT Gateway** for maximum cost savings, your ECS tasks will have **dynamic public IPs** that change on each deployment. This requires configuring MongoDB Atlas to allow connections from anywhere.

## MongoDB Atlas Network Configuration

### Option 1: Allow From Anywhere (Recommended for this setup)

1. Go to [MongoDB Atlas Console](https://cloud.mongodb.com)
2. Select your project
3. Navigate to **Network Access** (left sidebar)
4. Click **Add IP Address**
5. Select **"Allow Access from Anywhere"** or manually enter: `0.0.0.0/0`
6. Add a comment: "Lexiclab Production - ECS Tasks"
7. Click **Confirm**

**Security Note**: This allows connection attempts from any IP, but connections still require:
- ✅ **Valid MongoDB connection string** (stored in AWS Secrets Manager)
- ✅ **Valid username and password** (embedded in connection string)
- ✅ **TLS/SSL encryption** (enabled by default with MongoDB Atlas)
- ✅ **AWS Secrets Manager** protecting credentials (encrypted at rest and in transit)

Your database is still secure - just relying on authentication instead of IP whitelisting.

### Connection String Format

Your MongoDB Atlas connection string should look like:

```
mongodb+srv://username:password@cluster.mongodb.net/lexiclab?retryWrites=true&w=majority
```

**Never commit this to git!** It's stored securely in AWS Secrets Manager.

## Alternative: Use NAT Gateway for Static IPs

If you need IP whitelisting for compliance/security requirements, you can re-enable NAT Gateway:

### Re-enable NAT Gateway (adds $35/month)

Edit `/Users/pavloprovectus/Documents/my-projects/lexiclab-aws/main.tf`:

```hcl
module "networking" {
  source = "./modules/networking"

  # Change this line:
  enable_nat_gateway = true  # Was: false
  single_nat_gateway = true  # Use single NAT for cost savings

  # ... rest of config
}

# Update ECS services to use private subnets
module "ecs_service_api" {
  # ...
  subnet_ids       = module.networking.private_subnet_ids  # Was: public_subnet_ids
  assign_public_ip = false  # Was: true
}

module "ecs_service_ui" {
  # ...
  subnet_ids       = module.networking.private_subnet_ids  # Was: public_subnet_ids
  assign_public_ip = false  # Was: true
}
```

Then apply:
```bash
terraform apply

# Get NAT Gateway IP
terraform output nat_gateway_ips

# Add this IP to MongoDB Atlas IP whitelist instead of 0.0.0.0/0
```

**Cost**: Adds $35/month but provides static IP for MongoDB Atlas whitelisting.

## MongoDB Atlas Cluster Setup

If you haven't created a MongoDB Atlas cluster yet:

### 1. Create Free Cluster

1. Go to [MongoDB Atlas](https://cloud.mongodb.com)
2. Create account / Sign in
3. Click **"Build a Database"**
4. Choose **"Shared"** (Free tier M0)
5. Select **AWS** as cloud provider
6. Choose **eu-central-1** (Frankfurt) - same as your infrastructure
7. Name your cluster (e.g., "lexiclab-prod")
8. Click **"Create Cluster"**

### 2. Create Database User

1. In MongoDB Atlas, go to **Database Access**
2. Click **"Add New Database User"**
3. Choose **"Password"** authentication
4. Username: `lexiclab-api` (or your choice)
5. Password: **Auto-generate a secure password** (save it securely!)
6. Database User Privileges: **"Read and write to any database"**
7. Click **"Add User"**

### 3. Get Connection String

1. In MongoDB Atlas, go to **Database** → **Connect**
2. Choose **"Connect your application"**
3. Driver: **Node.js**, Version: **5.5 or later**
4. Copy the connection string:
   ```
   mongodb+srv://<username>:<password>@cluster.mongodb.net/?retryWrites=true&w=majority
   ```
5. Replace `<username>` with your database user
6. Replace `<password>` with the password you created
7. Add database name: `mongodb+srv://username:password@cluster.mongodb.net/lexiclab?retryWrites=true&w=majority`

### 4. Update Terraform Variables

Add the connection string to `terraform.tfvars`:

```hcl
mongodb_url = "mongodb+srv://lexiclab-api:YOUR_PASSWORD@cluster.mongodb.net/lexiclab?retryWrites=true&w=majority"
```

**Security**: This file is git-ignored, and the value is stored in AWS Secrets Manager when you run `terraform apply`.

## Testing MongoDB Connection

After deploying your infrastructure, verify the API can connect:

```bash
# Check API logs for MongoDB connection
aws logs tail /ecs/lexiclab-prod-api --follow

# Should see: "Successfully connected to MongoDB" or similar
# Should NOT see: "MongoNetworkError" or "connection timeout"
```

If you see connection errors:
1. Verify MongoDB Atlas network access allows `0.0.0.0/0`
2. Check connection string is correct in Secrets Manager:
   ```bash
   aws secretsmanager get-secret-value --secret-id lexiclab/prod/mongodb-url --query SecretString --output text
   ```
3. Verify MongoDB cluster is not paused (check Atlas console)

## MongoDB Atlas Free Tier Limits

The free M0 cluster includes:
- **Storage**: 512 MB
- **RAM**: Shared
- **vCPUs**: Shared
- **Connections**: 500 max
- **Good for**: Development, testing, small production apps (<50 users)

### When to Upgrade

Upgrade to paid tier (M10+ ~$50/month) when:
- Storage > 400 MB
- Concurrent connections > 400
- Need better performance
- Need automated backups
- Have 50+ active users

## Security Best Practices

Even with `0.0.0.0/0` network access:

1. ✅ **Use strong passwords** - MongoDB Atlas auto-generates secure passwords
2. ✅ **Enable TLS/SSL** - Enabled by default with `mongodb+srv://`
3. ✅ **Rotate credentials** - Change password periodically
4. ✅ **Monitor access logs** - Check MongoDB Atlas metrics for suspicious activity
5. ✅ **Use Secrets Manager** - Never hardcode connection strings
6. ✅ **Enable MongoDB Atlas alerts** - Get notified of unusual activity

## Troubleshooting

### Error: "MongoNetworkError: connection timed out"

**Solution**: Verify MongoDB Atlas network access:
1. Go to MongoDB Atlas → Network Access
2. Ensure `0.0.0.0/0` is in the IP Access List
3. Wait 1-2 minutes for changes to propagate
4. Restart ECS tasks: `./scripts/update-task.sh`

### Error: "Authentication failed"

**Solution**: Check connection string:
1. Verify username/password are correct
2. Ensure database name is included in connection string
3. Check for special characters in password (must be URL-encoded)
4. Update secret: `aws secretsmanager update-secret --secret-id lexiclab/prod/mongodb-url --secret-string "new-connection-string"`

### Error: "Cluster paused"

**Solution**: Resume cluster in MongoDB Atlas:
1. Go to MongoDB Atlas Console
2. Navigate to your cluster
3. Click **"Resume"** if paused
4. Free tier clusters auto-pause after 60 days of inactivity

## Cost Comparison

| Configuration | MongoDB Network Access | Monthly Cost | Security Level |
|--------------|----------------------|--------------|----------------|
| **Current (No NAT)** | 0.0.0.0/0 | **$0** | Good (auth-based) |
| **With NAT Gateway** | Specific IPs | **+$35** | Better (IP + auth) |
| **With PrivateLink** | VPC Private | **+$150** | Best (private network) |

For a small user base (10-50 users), the current configuration with `0.0.0.0/0` is **secure enough** and **$35-185/month cheaper**.

## Summary

**Required MongoDB Atlas Configuration**:
- ✅ Network Access: Allow `0.0.0.0/0`
- ✅ Database User: Created with strong password
- ✅ Connection String: Added to `terraform.tfvars`

This allows your ECS tasks (with dynamic IPs) to connect securely to MongoDB using authentication credentials stored in AWS Secrets Manager.
