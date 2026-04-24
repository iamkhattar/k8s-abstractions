INFRA_DIR    := justfile_directory() + "/infra" 

default: # 
    @just --list

# Plan K8S Cluster using Terraform
[group: 'cluster']
plan:
    @echo "Planning K8S cluster..."
    @cd {{INFRA_DIR}} && terraform plan -var-file=variables.tfvars

# Apply K8S Cluster using Terraform
[group: 'cluster']
apply:
    @echo "Creating K8S cluster..."
    @cd {{INFRA_DIR}} && terraform apply -var-file=variables.tfvars -auto-approve

# Destory K8S Cluster using Terraform
[group: 'cluster']
destroy:
    @echo "Destroying K8S cluster..."
    @cd {{INFRA_DIR}} && terraform destroy -var-file=variables.tfvars -auto-approve

# Login to K8S Cluster
[group: 'cluster']
login:
    @echo "Logging into K8S cluster..."
    @cd {{INFRA_DIR}} && ssh -o StrictHostKeyChecking=no -i config/.ssh/id_rsa groot@$(terraform output -raw server_node_ip)