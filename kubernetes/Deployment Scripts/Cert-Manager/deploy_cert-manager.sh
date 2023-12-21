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

# Check if $HOME/.kube/config exists and if so save to kubeconfig variable
if [ -f "$HOME/.kube/config" ] ; then
    echo -e "\e[32mKube config found in $HOME/.kube\e[0m"
    # Set file to variable
    kubeconfig=$HOME/.kube/config
fi

# Check if /etc/rancher/k3s/k3s.yaml exists and if so save to k3sconfig variable
if [ -f "/etc/rancher/k3s/k3s.yaml" ] ; then
    echo -e "\e[32mk3s.yaml found in /etc/rancher/k3s\e[0m"
    # Set file to variable
    k3sconfig=/etc/rancher/k3s/k3s.yaml
    # if kubeconfig is set, delete the file, copy k3sconfig to kubeconfig
    if [ ! -z "$kubeconfig" ] ; then
        echo -e "\e[32mDeleting kubeconfig\e[0m"
        sudo rm $kubeconfig
        echo -e "\e[32mCopying k3sconfig to kubeconfig\e[0m"
        sudo cp $k3sconfig $kubeconfig
    fi
fi

# Check if kubeconfig or k3sconfig is set, if not exit
if [ -z "$kubeconfig" ] && [ -z "$k3sconfig" ] ; then
    echo -e "\e[31mNo kube config found in $HOME/.kube or /etc/rancher/k3s\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# If either kubeconfig or k3sconfig are set, get their permissions and set to kubeconfig_permissions and k3sconfig_permissions respectively
if [ ! -z "$kubeconfig" ] ; then
    kubeconfig_permission=$(stat -c "%a" $kubeconfig)
fi

if [ ! -z "$k3sconfig" ] ; then
    k3sconfig_permission=$(stat -c "%a" $k3sconfig)
fi

# If kubeconfig is set and permission is not 644, change it, will be changed back later
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission to 644\e[0m"
    sudo chmod 644 $kubeconfig
fi

# If k3sconfig is set and permission is not 644, change it, will be changed back later
if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission to 644\e[0m"
    sudo chmod 644 $k3sconfig
fi

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

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi