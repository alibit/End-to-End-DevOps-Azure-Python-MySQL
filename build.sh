subscription_id=$(cat subscription.txt)
cluster_name="cluster-1-dev-aks" # Update this if the cluster name is changed in terraform
Location="East US"
resource_group="cluster-1-dev-rg"
sql_servername="cluster-1-dev-sql-server"
acr_name="cluster1devacr"
service_principal_name="pyapp"
app_image_name="$acr_name.azurecr.io/todo-app-img:latest"
service_name="todo-app-service"
argo_service_name="argocd-server"
alertmanager_service_name="kube-prometheus-stack-alertmanager"
grafana_service_name="kube-prometheus-stack-grafana"
prometheus_service_name="kube-prometheus-stack-prometheus"
namespace="todo-app"
argo_namespace="argocd"
monitoring_namespace="monitoring"
alertmanager_port="9093"
prometheus_port="9090"

# Check if the service principal already exists
echo "------------Check if Service Principal Exists---------------"
service_principal_id=$(az ad sp list --display-name "$service_principal_name" --query "[?appDisplayName=='$service_principal_name'].appId" -o tsv)

if [ -z "$service_principal_id" ]; then
  echo "Service principal '$service_principal_name' does not exist, Run the script 'run_me_first.sh' to create one."
  exit 1
else
  echo "Service principal '$service_principal_name' exists with ID: $service_principal_id"
fi

# update helm repos
helm repo update

# Build the infrastructure
echo "---------------------Creating AKS & ACR---------------------"
cd terraform || { echo "Terraform directory not found"; exit 1; }
terraform init || { echo "Terraform init failed"; exit 1; }
terraform apply -auto-approve || { echo "Terraform apply failed"; exit 1; }
cd ..

# Update kubeconfig
echo "--------------------Updating Kubeconfig---------------------"
az aks get-credentials --resource-group $resource_group --name $cluster_name || { echo "Failed to update kubeconfig"; exit 1; }

# remove preious docker images
echo "--------------------Remove Previous build--------------------"
docker rmi -f $app_image_name || true

# build new docker image with new tag
echo "--------------------Build new Image--------------------"
docker build -t $app_image_name todo-app/

# ACR Login
echo "----------------------Logging into ACR----------------------"
az acr login --name $acr_name || { echo "ACR login failed"; exit 1; }

# Push the latest build to ACR
echo "--------------------Pushing Docker Image--------------------"
docker push $app_image_name || { echo "Docker push failed"; exit 1; }

# # create namespace
echo "--------------------creating Namespace--------------------"
kubectl create ns $namespace || true

# # Create role assignment
AKS_MANAGED_IDENTITY=$(az aks show --resource-group $resource_group --name $cluster_name --query "identityProfile.kubeletidentity.clientId" -o tsv)
az role assignment create --assignee $AKS_MANAGED_IDENTITY --scope $(az acr show --name $acr_name --resource-group $resource_group --query id -o tsv) --role AcrPull

# Secret for the SQL Server endpoint (DB_HOST)
DB_HOST=$(az sql server show --name $sql_servername --resource-group $resource_group --query fullyQualifiedDomainName --output tsv)
kubectl create secret -n $namespace generic sql-endpoint --from-literal=endpoint=$DB_HOST

# Secret for the SQL Server username (DB_USER)
DB_USER=$(cd terraform && terraform output -raw db_username)
kubectl create secret -n $namespace generic db-username --from-literal=username=$DB_USER

# Secret for the SQL Server password (DB_PASSWORD)
DB_PASSWORD=$(cd terraform && terraform output -raw db_password)
kubectl create secret -n $namespace generic db-password --from-literal=password=$DB_PASSWORD

# Deploy the application
echo "-----------------------Deploying App------------------------"
kubectl apply -n $namespace -f k8s || { echo "App deployment failed"; exit 1; }

# Wait for application to be deployed
echo "--------------------Wait for all pods to be running--------------------"
sleep 60s

# Get LoadBalancer
echo "----------------------Application URL-----------------------"
echo "$(kubectl get svc $service_name -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; })"

echo ""

echo "------------------------ArgoCD URL--------------------------"
kubectl get svc $argo_service_name -n $argo_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }

echo ""

echo "-------------------- ArgoCD Credentials---------------------"
argo_pass=$(kubectl -n $argo_namespace get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
echo "┌─────────┬───────────────────────────┐"
echo "│  USER   │  PASSWORD                 │"
echo "├─────────┼───────────────────────────┤"
echo "│  admin  │ $argo_pass          │"
echo "└─────────┴───────────────────────────┘"

echo ""

echo "----------------------Alertmanager URL----------------------"
echo "$(kubectl get svc $alertmanager_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }):$alertmanager_port"

echo ""

echo "-----------------------Prometheus URL-----------------------"
echo "$(kubectl get svc $prometheus_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }):$prometheus_port"

echo ""

echo "------------------------ Grafana URL------------------------"
kubectl get svc $grafana_service_name -n $monitoring_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || { echo "Failed to retrieve service IP"; exit 1; }

echo ""

echo "-------------------- Grafana Credentials--------------------"
grafana_user=$(kubectl -n $monitoring_namespace get secret $grafana_service_name -o jsonpath="{.data.admin-user}" | base64 --decode)
grafana_pass=$(kubectl -n $monitoring_namespace get secret $grafana_service_name -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "┌───────────────┬─────────────────────────┐"
echo "│  USER         │  PASSWORD               │"
echo "├───────────────┼─────────────────────────┤"
echo "│ $grafana_user         │ $grafana_pass                   │"
echo "└───────────────┴─────────────────────────┘"