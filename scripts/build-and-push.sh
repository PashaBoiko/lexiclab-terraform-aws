#!/bin/bash
set -e

# Configuration
AWS_REGION="eu-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Lexiclab Docker Build and Push ===${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Get ECR repository URLs from Terraform outputs
cd "$PROJECT_ROOT"
echo -e "${YELLOW}Getting ECR repository URLs from Terraform...${NC}"
API_REPO=$(terraform output -raw ecr_api_repository_url 2>/dev/null || echo "")
UI_REPO=$(terraform output -raw ecr_ui_repository_url 2>/dev/null || echo "")

if [ -z "$API_REPO" ] || [ -z "$UI_REPO" ]; then
    echo -e "${RED}Error: Could not get ECR repository URLs from Terraform${NC}"
    echo "Make sure you have run 'terraform apply' first"
    exit 1
fi

echo "API Repository: $API_REPO"
echo "UI Repository: $UI_REPO"
echo ""

# Authenticate Docker to ECR
echo -e "${YELLOW}Authenticating Docker to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to authenticate to ECR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Authentication successful${NC}"
echo ""

# Build and push API
echo -e "${YELLOW}Building API image...${NC}"
API_DIR="$PROJECT_ROOT/../lexiclab-nest-api"

if [ ! -d "$API_DIR" ]; then
    echo -e "${RED}Error: API directory not found at $API_DIR${NC}"
    exit 1
fi

cd "$API_DIR"

# Get git commit hash for tagging (if available)
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")

echo "Building from: $API_DIR"
docker build -t ${API_REPO}:latest -t ${API_REPO}:${GIT_HASH} .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to build API image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ API image built successfully${NC}"
echo ""

echo -e "${YELLOW}Pushing API image to ECR...${NC}"
docker push ${API_REPO}:latest
docker push ${API_REPO}:${GIT_HASH}

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to push API image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ API image pushed successfully${NC}"
echo ""

# Build and push UI
echo -e "${YELLOW}Building UI image...${NC}"
UI_DIR="$PROJECT_ROOT/../lexiclab-ui-react"

if [ ! -d "$UI_DIR" ]; then
    echo -e "${RED}Error: UI directory not found at $UI_DIR${NC}"
    exit 1
fi

cd "$UI_DIR"

# Get git commit hash for tagging (if available)
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")

echo "Building from: $UI_DIR"
docker build -t ${UI_REPO}:latest -t ${UI_REPO}:${GIT_HASH} .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to build UI image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ UI image built successfully${NC}"
echo ""

echo -e "${YELLOW}Pushing UI image to ECR...${NC}"
docker push ${UI_REPO}:latest
docker push ${UI_REPO}:${GIT_HASH}

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to push UI image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ UI image pushed successfully${NC}"
echo ""

echo -e "${GREEN}=== All images pushed successfully! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Force ECS deployment: ./scripts/update-task.sh"
echo "2. Or run: terraform apply (if task definitions changed)"
