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

echo -e " \033[34;5m        K3S Let's Encrypt Deployment Script         \033[0m"
echo

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                     Inner Script Variables                                        ###
#########################################################################################################
#  ╔════════════════════╗
#  ║   Main Variables   ║
#  ╚════════════════════╝
keep_manifestes="true"                  
# Set this to true to keep a copy of all manifest files in the manifests folder

cf_token="token"
# Cloudflare API Token

letsencrypt_email="email@domain.tld"
# Email for Let's Encrypt

cloudflare_email="email@domain.tld"
# Email for Cloudflare

cloudflare_domain="domain.tld"
# Domain for Cloudflare
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
#          STARTING CERT-MANAGER UPGRADE         #
##################################################

# Install Helm if not already installed:
if ! command -v helm &> /dev/null ; then
    echo -e "\e[32mInstalling Helm\e[0m"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Check if cert-manager is already installed by checking if the namespace exists, and if so store the result in cert_manager_installed
cert_manager_installed=$(kubectl get ns cert-manager --ignore-not-found=true -o jsonpath="{.metadata.name}")

# If cert-manager is not already installed, error out
if [ -z "$cert_manager_installed" ] ; then
    echo -e "\e[31mCert-manager is not installed, please run deploy_cert-manager.sh first\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/helm/cert-manager/cert-manager_cloudflare-values.yaml
if [ -f "cert-manager_cloudflare-values.yaml" ] ; then
    echo -e "\e[32mSuccessfully downloaded cert-manager_cloudflare-values.yaml\e[0m"
else
    echo -e "\e[31mFailed to download cert-manager_cloudflare-values.yaml\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/cert-manager/cert-manager_cloudflare-manifest.yaml
if [ -f "cert-manager_cloudflare-manifest.yaml" ] ; then
    sed -i.bak \
    -e "s|\\\$cf_token|$cf_token|g" \
    -e "s|\\\$letsencrypt_email|$letsencrypt_email|g" \
    -e "s|\\\$cloudflare_email|$cloudflare_email|g" \
    -e "s|\\\$cloudflare_domain|$cloudflare_domain|g" cert-manager_cloudflare-manifest.yaml

    if [ $? -eq 0 ] ; then
        echo -e "\e[32mSuccessfully replaced variables in cert-manager_cloudflare-manifest.yaml\e[0m"
        rm cert-manager_cloudflare-manifest.yaml.bak
    else
        echo -e "\e[31mFailed to replace variables in cert-manager_cloudflare-manifest.yaml\e[0m"
        mv cert-manager_cloudflare-manifest.yaml.bak cert-manager_cloudflare-manifest.yaml
        echo -e "\e[31mExiting...\e[0m"
        exit 1
    fi    
else
    echo -e "\e[31mFailed to download cert-manager_cloudflare-manifest.yaml\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Ensure that helm repos are loaded and updated
echo -e "\e[32mLoading Helm Repos and updating them\e[0m"
helm repo add jetstack https://charts.jetstack.io 2>/dev/null
helm repo update 2>/dev/null
echo -e "\e[32mHelm Repos loaded and updated successfully\e[0m"

# Upgrade cert-manager
echo -e "\e[32mUpgrading cert-manager\e[0m"
helm upgrade cert-manager jetstack/cert-manager --namespace cert-manager --values cert-manager_cloudflare-values.yaml 2>/dev/null
if [ $? -eq 0 ] ; then
    echo -e "\e[32mCert-Manager upgraded successfully\e[0m"
else
    echo -e "\e[31mFailed to upgrade cert-manager\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Apply cert-manager manifest
echo -e "\e[32mApplying cert-manager manifest\e[0m"
kubectl apply -f cert-manager_cloudflare-manifest.yaml 2>/dev/null
if [ $? -eq 0 ] ; then
    echo -e "\e[32mCert-Manager manifest applied successfully\e[0m"
else
    echo -e "\e[31mFailed to apply cert-manager manifest\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Wait for cert-manager to be ready
echo -e "\e[32mWaiting for cert-manager to be ready...\e[0m"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

if [ keep_manifestes = "true" ] ; then
    if [ ! -d "$HOME/kubernetes/manifests/cert-manager" ] ; then
        echo -e "\e[32mCreating Manifest Directory for Cert-Manager: $HOME/kubernetes/manifests/cert-managerin\e[0m"
        mkdir -p $HOME/kubernetes/manifests/cert-manager
    fi
    mv cert-manager_cloudflare-values.yaml $HOME/kubernetes/manifests/cert-manager/cert-manager_cloudflare-values.yaml
    mv cert-manager_cloudflare-manifest.yaml $HOME/kubernetes/manifests/cert-manager/cert-manager_cloudflare-manifest.yaml
else
    rm cert-manager_cloudflare-values.yaml
    rm cert-manager_cloudflare-manifest.yaml
fi

echo -e "\e[32mCert-Manager upgraded successfully\e[0m"
echo -e "\e[32mIf you need to add more domains with the same cloudflare token, use:\e[0m"
echo -e "\e[32m    kubectl edit ClusterIssuer letsencrypt-production\e[0m"
echo -e "\e[32mand add additional Dns Zones\e[0m"

##################################################
#           FINISHED CERT-MANAGER UPGRADE        #
##################################################
