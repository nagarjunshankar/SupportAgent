#!/bin/bash

# Purpose: Automated Kubernetes diagnostics using kubectl-ai for KNIME support
# Author: KNIME AI Support Agent

set -e

GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN} 🎯 Starting support bundle analysis for KNIME Support...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"

# --- Step 1: sbctl shell session ---
read -p "Provide the path of the downloaded Support Bundle(e.g., path to support-bundle**.tgz):" filename
sleep 2
set -e
# Start sbctl serve in background
nohup sbctl serve -s $filename > sbctl.log 2>&1 &
# Wait a few seconds for the server to start
sleep 5
# Extract the KUBECONFIG path from the log
KUBECONFIG_PATH=$(grep -oE "/var/folders/.*/local-kubeconfig-[0-9]+" sbctl.log | tail -n1)

if [ -z "$KUBECONFIG_PATH" ]; then
    echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
    echo "❌ Failed to extract KUBECONFIG path from log."
    echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
    exit 1
fi
# Export KUBECONFIG so kubectl can use it
export KUBECONFIG="$KUBECONFIG_PATH"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}🤖 Setting KUBECONFIG, AI Agent and Persona"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ KUBECONFIG set to $KUBECONFIG ${NC}"
#nohup sbctl serve -s "$filename" &
#nohup sbctl shell -s "$filename" &
#sleep 2

# Step 2: Checking and Installing kubectl-ai tool
#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

## Function to install kubectl-ai
#install_kubectl_ai() {
#    echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
#    echo "Installing kubectl-ai..."
#    echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
#    curl -sSL https://raw.githubusercontent.com/GoogleCloudPlatform/kubectl-ai/main/install.sh | bash
#    tar -zxvf kubectl-ai_Darwin_arm64.tar.gz
#    chmod a+x kubectl-ai
#    sudo mv kubectl-ai /usr/local/bin/
#}

# Check and install kubectl-ai
if command_exists kubectl-ai; then
    echo -e "${GREEN}✅ kubectl-ai is already installed.${NC}"
else
    echo -e "${GREEN}❌ kubectl-ai not found. Please install kubectlai to proceed forward${NC}"
    echo -e "${GREEN} https://github.com/GoogleCloudPlatform/kubectl-ai ${NC}"
    install_kubectl_ai
fi


# --- Step 2: API Key setup ---
#read -p "Do you want to export an OpenAI API key? [y/N]: " use_key

#if [[ "$use_key" == "y" || "$use_key" == "Y" ]]; then
  read -s -p "Enter your OpenAI API Key - Please find the key on 1password Vault: " OPENAI_KEY
  echo ""
  echo -e "${GREEN}✅ OPENAI_API_KEY has been set, Please edit the script to change the key${NC}"
  echo -e "${GREEN}✅ Running Kubectl-ai with OPENAI LLM Provider and Model gpt-4o${NC}"
  sleep 3
#fi

# --- Step 3: Set AI identity ---
echo -e "${GREEN}🤖 Setting kubectl-ai persona: KNIME AI Support Agent${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
kubectl-ai --llm-provider=openai --model=gpt-4o "Set yourself as KNIME AI Support Agent Persona" --quiet

# Print KOTS Version and Kubernetes version
sleep 5
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ Fetching Namespace where HUB is installed and this script works only for knime namespace${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
kubectl get ns | grep knime*
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ Checking KOTS Version${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
sleep 5
echo ""
kubectl get pod -n default -l app=kotsadm -o name | xargs -I {} kubectl describe -n default {} | grep "Image:" | awk '{print $2}' | sort -u
sleep 5

echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ Checking Kubernetes Version and Pods in Kube-system namespace${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
sleep 5
kubectl get pods -n kube-system -o custom-columns="IMAGES:.spec.containers[*].image" | grep kube-apiserver
echo ""
sleep 2

echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ listing pods in kube-system namespace${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl get pods -n kube-system --no-headers -o wide \
| awk '
  {
    age = $5
    unit = substr(age, length(age))
    val = substr(age, 1, length(age) - 1)
    if (unit == "d" && val <= 10) print
    else if (unit == "h" || unit == "m" || unit == "s") print
  }' \
| kubectl-ai --llm-provider=openai --model=gpt-4o "analyze these kube-system pods that are younger than 10 days for any potential issues or misconfigurations" --quiet
sleep 2
echo ""

echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Analyzing if we have any recent restarts on the pods${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl-ai --llm-provider=openai --model=gpt-4o "check the pods in kube-system namespace for any recent restarts and check the reason behind restarts" --quiet
sleep 5

# --- Step 4: Run diagnostics ---
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}🔍 Describing cluster nodes and resources...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl-ai --llm-provider=openai --model=gpt-4o "describe all nodes and show allocated resources section in Tabular format and explain it" --quiet
sleep 5

echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking pods in the 'default' namespace...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
kubectl get pods -n default
echo ""
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📜 Checking logs for the 'kotsadm' pod specifically for HELM Upgrade FAILED errors...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl-ai --llm-provider=openai --model=gpt-4o "get logs from the kotsadm pod in the default namespace and check only for FAILED error message" --quiet
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking Infra pods(statefulsets) in the 'knime' namespace...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl get pods -n knime -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="StatefulSet")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'
#kubectl-ai --llm-provider=openai --model=gpt-4o "list statefulset in the knime namespace and list the related pods first in tabular format with Age and restart column" --quiet
#kubectl-ai --llm-provider=openai --model=gpt-4o "list statefulsets in the knime namespace and give me reason for any restarts"
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking the Status of HUB as per the below Order${NC}"
echo -e "${GREEN}PostgresSQL -> Keycloak -> HUB Services(rest, catalog, accounts) -> HUB Webapp${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking Infra pods(postgres) in the 'knime' namespace...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
kubectl get pods -n knime | grep knime-postgres-cluster-0
echo ""
POD_NAME="knime-postgres-cluster-0"
NAMESPACE="knime"

# Get pod status
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[*].state}' | grep -o '"[a-zA-Z]*":{' | sed 's/[":{]//g' 2>/dev/null)

echo "Pod Status: $POD_STATUS"
echo ""

if [[ "$POD_STATUS" != "running" ]]; then
    echo -e "${GREEN}Pod is not in Running status. Checking logs for issues...${NC}"
    
    FILTERED_LOGS=$(kubectl logs $POD_NAME -n $NAMESPACE | grep -iE "error|fatal|panic|exception|caused|wal position|healthiest" | awk '!seen[$0]++' | tail -n 20)
    echo -e "${GREEN}Fetching the last few lines of logs from the Keycloak Pod${NC}"
    echo ""
    echo "$FILTERED_LOGS"
    
    
    if [[ -n "$FILTERED_LOGS" ]]; then
        echo ""
        echo -e "${GREEN}Running AI diagnostics on filtered logs...${NC}"
        echo "$FILTERED_LOGS" | kubectl-ai --llm-provider=openai --model=gpt-4o "analyze the following logs and identify any issues" --quiet
    else
        echo "No relevant logs found to analyze."
    fi
    
    sleep 5
else
    echo "Pod is Running. Proceeding to next steps..."
fi

# Continue with your script...
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking Infra pods(keycloak) in the 'knime' namespace...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
kubectl get pods -n knime | grep knime-keycloak-0
echo ""
echo ""
POD_NAME="knime-keycloak-0"
NAMESPACE="knime"

# Get pod status
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[*].state}' | grep -o '"[a-zA-Z]*":{' | sed 's/[":{]//g' 2>/dev/null)

echo "Pod Status: $POD_STATUS"
echo ""

if [[ "$POD_STATUS" != "running" ]]; then
    echo -e "${GREEN}Pod is not in Running status. Checking logs for issues...${NC}"
    
    FILTERED_LOGS=$(kubectl logs $POD_NAME -n $NAMESPACE | grep -iE "error|fatal|panic|exception|caused|wal position|healthiest" | awk '!seen[$0]++' | tail -n 20)
    echo -e "${GREEN}Fetching the last few lines of logs from the Keycloak Pod${NC}"
    echo ""
    echo "$FILTERED_LOGS"
    
    if [[ -n "$FILTERED_LOGS" ]]; then
        echo ""
        echo -e "${GREEN}Running AI diagnostics on filtered logs...${NC}"
        echo "$FILTERED_LOGS" | kubectl-ai --llm-provider=openai --model=gpt-4o "analyze the following logs and identify any issues" --quiet
    else
        echo "No relevant logs found to analyze."
    fi
    
    sleep 5
else
    echo "Pod is Running. Proceeding to next steps..."
fi

echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 listing crashloop pods in the knime namespace and checking the reason${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
CRASHED_PODS=$(kubectl get pods -n knime 2>/dev/null | grep -i crash || true)

if [[ -n "$CRASHED_PODS" ]]; then
    echo "Crashed pods detected:"
    echo "$CRASHED_PODS"
    # You can act on this list or loop over them if needed
else
    echo "No crashed pods found in knime namespace."
fi
#kubectl-ai --llm-provider=openai --model=gpt-4o "get the pods in the knime namespace and provide reason for crashloop" --quiet
sleep 5

echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📜 Logs for the 'rest-interface' pod (error scan)...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl-ai --llm-provider=openai --model=gpt-4o "get logs from the rest-interface pod in the knime namespace and show any errors or stack traces" --quiet
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}📦 Checking all the pods in the 'knime' namespace...${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
kubectl get pods -n knime -o wide
sleep 5
echo ""
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ Cluster analysis complete — done by KNIME AI Support Agent using GPT-4o.${NC}"
echo -e "${GREEN}--------------------------------------------------------------------------------------------------------------${NC}"
echo ""
echo -e "${GREEN}📜 I am now open for any questions you have. Example: You can ask me about specific pod within a namespace in Natural Language${NC}"

kubectl-ai --llm-provider=openai --model=gpt-4o
