#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Force ECS Service Deployment ===${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Get cluster and service names from Terraform outputs
cd "$PROJECT_ROOT"
echo -e "${YELLOW}Getting ECS configuration from Terraform...${NC}"
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
API_SERVICE=$(terraform output -raw api_service_name 2>/dev/null || echo "")
UI_SERVICE=$(terraform output -raw ui_service_name 2>/dev/null || echo "")

if [ -z "$CLUSTER_NAME" ] || [ -z "$API_SERVICE" ] || [ -z "$UI_SERVICE" ]; then
    echo -e "${RED}Error: Could not get ECS configuration from Terraform${NC}"
    echo "Make sure you have run 'terraform apply' first"
    exit 1
fi

echo "Cluster: $CLUSTER_NAME"
echo "API Service: $API_SERVICE"
echo "UI Service: $UI_SERVICE"
echo ""

# Force new deployment for API service
echo -e "${YELLOW}Forcing new deployment for API service...${NC}"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $API_SERVICE \
    --force-new-deployment \
    --output json > /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to update API service${NC}"
    exit 1
fi

echo -e "${GREEN}✓ API service deployment initiated${NC}"

# Force new deployment for UI service
echo -e "${YELLOW}Forcing new deployment for UI service...${NC}"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $UI_SERVICE \
    --force-new-deployment \
    --output json > /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to update UI service${NC}"
    exit 1
fi

echo -e "${GREEN}✓ UI service deployment initiated${NC}"
echo ""

echo -e "${GREEN}=== Deployment initiated successfully! ===${NC}"
echo ""
echo "Monitor deployment status:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $API_SERVICE $UI_SERVICE"
echo ""
echo "Watch CloudWatch logs:"
echo "  aws logs tail /ecs/lexiclab-prod-api --follow"
echo "  aws logs tail /ecs/lexiclab-prod-ui --follow"
