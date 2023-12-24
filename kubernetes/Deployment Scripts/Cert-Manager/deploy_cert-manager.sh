#!/bin/bash
clear

echo
echo -e " \033[31;5m  ██╗     ██╗   ██╗██╗  ██╗██╗██╗   ██╗███╗   ███╗  \033[0m"
echo -e " \033[31;5m  ██║     ██║   ██║██║ ██╔╝██║██║   ██║████╗ ████║  \033[0m"
echo -e " \033[31;5m  ██║     ██║   ██║█████╔╝ ██║██║   ██║██╔████╔██║  \033[0m"
echo -e " \033[31;5m  ██║     ██║   ██║██╔═██╗ ██║██║   ██║██║╚██╔╝██║  \033[0m"
echo -e " \033[31;5m  ███████╗╚██████╔╝██║  ██╗██║╚██████╔╝██║ ╚═╝ ██║  \033[0m"
echo -e " \033[31;5m  ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝  \033[0m"
echo

echo -e " \033[34;5m         Cert-Manager Deployment Script             \033[0m"
echo

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                         App Versions                                              ###
#########################################################################################################
cert_manager_version="v1.13.3" # Cert Manager Version
#########################################################################################################
###                                     Inner Script Variables                                        ###
#########################################################################################################
#  ╔════════════════════╗
#  ║   Main Variables   ║
#  ╚════════════════════╝
keep_manifestes="true"                  
# Set this to true to keep a copy of all manifest files in the manifests folder

#########################################################################################################
###      !!!!!                    DO NOT TOUCH PAST HERE OR THINGS BLOW UP                 !!!!!      ###
#########################################################################################################

kubeconfig="$HOME/.kube/config"
k3sconfig="/etc/rancher/k3s/k3s.yaml"

# Check if $HOME/.kube/config exists
if [ -f $kubeconfig ] ; then
    echo -e "\e[32m$kubeconfig found...\e[0m"
    sudo chown $USER:$USER $kubeconfig
    sudo chmod 600 $kubeconfig
else
    echo -e "\e[31mNo kube config found in $HOME/.kube, checking for k3s config...\e[0m"
    if [ -f $k3sconfig ] ; then
        echo -e "\eFound $k3sconfig, copying to $kubeconfig...\e[0m"
        sudo cp $k3sconfig $kubeconfig
    else
        echo -e "\e[31mNo kube config found in $HOME/.kube or /etc/rancher/k3s\e[0m"
        echo -e "\e[31mExiting...\e[0m"
        exit 1
    fi
fi

echo -e "\e[32mEnsuring correct permissions and ownership for kubeconfig...\e[0m"
sudo chown $USER:$USER $kubeconfig
sudo chmod 600 $kubeconfig

##################################################
#       STARTING CERT-MANAGER INSTALLATION       #
##################################################

# Install Helm if not already installed:
if ! command -v helm &> /dev/null ; then
    echo -e "\e[32mInstalling Helm\e[0m"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Check if cert-manager is already installed by checking if the namespace exists, and if so store the result in cert_manager_installed
cert_manager_installed=$(kubectl get ns cert-manager --ignore-not-found=true -o jsonpath="{.metadata.name}")

# If cert-manager is not installed, install it
if [ -z "$cert_manager_installed" ] ; then
    echo -e "\e[32mInstalling cert-manager\e[0m"
    kubectl create namespace cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$cert_manager_version/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null
    helm repo update 2>/dev/null
    helm install cert-manager jetstack/cert-manager --namespace cert-manager 2>/dev/null
else
    echo -e "\e[32mCert-Manager already installed Upgrading Instead\e[0m"
    curl -sO https://raw.githubusercontent.com/Lukium/kubernetes/main/k3s/deploy-k3s/manifests/traefik/Helm/cert-manager-values.yaml
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$cert_manager_version/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null
    helm repo update 2>/dev/null
    helm upgrade cert-manager jetstack/cert-manager --namespace cert-manager 2>/dev/null
    
fi

if [ $keep_manifestes = "true" ] ; then
    if [ ! -d "$HOME/kubernetes/manifests/cert-manager" ] ; then
        echo -e "\e[32mCreating Manifest Directory for Cert-Manager: $HOME/kubernetes/manifests/cert-manager\e[0m"
        mkdir -p $HOME/kubernetes/manifests/cert-manager
    fi
    curl -sO https://github.com/cert-manager/cert-manager/releases/download/$cert_manager_version/cert-manager.crds.yaml
    mv cert-manager.crds.yaml $HOME/kubernetes/manifests/cert-manager/cert-manager.crds.yaml
fi

echo -e "\e[32mWaiting for cert-manager to be ready...\e[0m"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
echo -e "\e[32mCert-Manager installed successfully\e[0m"

##################################################
#       FINISHED CERT-MANAGER INSTALLATION       #
##################################################