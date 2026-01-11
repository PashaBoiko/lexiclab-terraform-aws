#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Initialize AWS Secrets ===${NC}"
echo ""
echo "This script helps you create secrets in AWS Secrets Manager."
echo "You can also use Terraform variables to create these automatically."
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

AWS_REGION="eu-central-1"

# Function to create or update secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3

    # Check if secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region $AWS_REGION &>/dev/null; then
        echo -e "${YELLOW}Secret $secret_name already exists. Updating...${NC}"
        aws secretsmanager update-secret \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region $AWS_REGION &>/dev/null
    else
        echo -e "${YELLOW}Creating secret $secret_name...${NC}"
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region $AWS_REGION &>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Secret $secret_name created/updated${NC}"
    else
        echo -e "${RED}✗ Failed to create/update secret $secret_name${NC}"
        return 1
    fi
}

# MongoDB URL
echo ""
read -sp "Enter MongoDB Atlas connection URL: " MONGODB_URL
echo ""
create_or_update_secret "lexiclab/prod/mongodb-url" "$MONGODB_URL" "MongoDB Atlas connection URL"

# JWT Secret
echo ""
echo "Enter JWT secret (or press Enter to generate one):"
read -sp "JWT Secret: " JWT_SECRET
echo ""

if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo -e "${YELLOW}Generated JWT secret${NC}"
fi

create_or_update_secret "lexiclab/prod/jwt-secret" "$JWT_SECRET" "JWT authentication secret"

# SES Credentials
echo ""
read -p "Enter AWS SES Access Key ID: " SES_ACCESS_KEY_ID
read -sp "Enter AWS SES Secret Access Key: " SES_SECRET_ACCESS_KEY
echo ""

SES_JSON=$(jq -n \
    --arg aki "$SES_ACCESS_KEY_ID" \
    --arg sak "$SES_SECRET_ACCESS_KEY" \
    '{access_key_id: $aki, secret_access_key: $sak}')

create_or_update_secret "lexiclab/prod/ses-credentials" "$SES_JSON" "AWS SES credentials"

# S3 Credentials
echo ""
read -p "Enter AWS S3 Access Key ID: " S3_ACCESS_KEY_ID
read -sp "Enter AWS S3 Secret Access Key: " S3_SECRET_ACCESS_KEY
echo ""

S3_JSON=$(jq -n \
    --arg aki "$S3_ACCESS_KEY_ID" \
    --arg sak "$S3_SECRET_ACCESS_KEY" \
    '{access_key_id: $aki, secret_access_key: $sak}')

create_or_update_secret "lexiclab/prod/s3-credentials" "$S3_JSON" "AWS S3 credentials"

echo ""
echo -e "${GREEN}=== All secrets created/updated successfully! ===${NC}"
echo ""
echo "Note: If you prefer to use Terraform to manage secrets, add these values to terraform.tfvars"
