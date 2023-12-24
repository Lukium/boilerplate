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

echo -e " \033[34;5m             Traefik Deployment Script              \033[0m"
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

traefik_username="admin"
# Username for traefik dashboard

traefik_password="password"
# Password for traefik dashboard

replica_count=1
# Number of replicas for traefik - Should match the number of worker nodes

selector_label_key="worker"
# Label Key for nodes you want to use for traefik

selector_label_value="true"
# Label Value for nodes you want to use for traefik

traefik_ip=192.168.200.150
# IP for traefik dashboard, must be within the range of the load balancer

set_tls_ingress="true"
# Set this to true to enable tls ingress

tls_secret="domain-tls"
# Name of the TLS secret - Only needed if set_tls_ingress is set to true

domain="domain.tld"
# Domain for Ingress - Only needed if set_tls_ingress is set to true
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

#####################################
#       TRAEFIK INSTALLATION        #
#####################################

# Check if htpasswd is installed, if not install it, also store whether it was installed or not
if ! command -v htpasswd &> /dev/null ; then
    echo -e "\e[32mInstalling htpasswd\e[0m"
    sudo apt install apache2-utils -y
    htpasswd_installed="true"
else
    htpasswd_installed="false"
fi

# Check if helm is intalled and if not install it
if ! command -v helm &> /dev/null ; then
    echo -e "\e[32mInstalling Helm\e[0m"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Hash and base64 encode username and password for traefik using htpasswd
echo -e "\e[32mHashing and base64 encoding username and password for traefik\e[0m"
traefik_username_hash=$(echo $traefik_password | htpasswd -ni $traefik_username | base64)
echo -e "\e[32mInstalling Traefik\e[0m"
echo -e "\e[32mLoading Helm Repos and updating them\e[0m"
helm repo add traefik https://helm.traefik.io/traefik 2>/dev/null
helm repo add emberstack https://emberstack.github.io/helm-charts 2>/dev/null # required to share certs for CrowdSec
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts 2>/dev/null
helm repo update 2>/dev/null
echo -e "\e[32mHelm Repos loaded and updated successfully\e[0m"

# Check if traefik namespace exists, if not create it
traefik_namespace=$(kubectl get ns traefik --ignore-not-found=true -o jsonpath="{.metadata.name}")
if [ -z "$traefik_namespace" ] ; then
    echo -e "\e[32mCreating traefik namespace\e[0m"
    kubectl create namespace traefik
    echo -e "\e[32mTraefik namespace created successfully\e[0m"
fi

echo -e "\e[32mDownloading traefik helm values\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/helm/traefik/traefik-values.yaml

if [ -f traefik-values.yaml ]; then
    sed -i.bak \
    -e "s|\\\$replica_count|$replica_count|g" \
    -e "s|\\\$selector_label_key|$selector_label_key|g" \
    -e "s|\\\$selector_label_value|$selector_label_value|g" \
    -e "s|\\\$traefik_ip|$traefik_ip|g" traefik-values.yaml

    if [ $? -eq 0 ]; then
        echo "Replacement successful"
        rm traefik-values.yaml.bak
    else
        echo "sed encountered an error"
        mv traefik-values.yaml.bak traefik-values.yaml
        exit 1
    fi
else
    echo "Failed to download traefik-values.yaml"
    exit 1
fi

echo -e "\e[32mDownloading traefik manifest\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/traefik/traefik-manifest.yaml
if [ -f traefik-manifest.yaml ]; then
    sed -i.bak \
    -e "s|\\\$traefik_username_hash|$traefik_username_hash|g" traefik-manifest.yaml

    if [ $? -eq 0 ]; then
        echo "Replacement successful"
        rm traefik-manifest.yaml.bak
    else
        echo "sed encountered an error"
        mv traefik-manifest.yaml.bak traefik-manifest.yaml
        exit 1
    fi
else
    echo "Failed to download traefik-manifest.yaml"
    exit 1
fi

if [ $set_tls_ingress = "true" ] ; then
    echo -e "\e[32mSetting up TLS Ingress\e[0m"
    curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/traefik/traefik-ingress.yaml
    if [ -f traefik-ingress.yaml ]; then
        sed -i.bak \
        -e "s|\\\$tls_secret|$tls_secret|g" \
        -e "s|\\\$domain|$domain|g" traefik-ingress.yaml

        if [ $? -eq 0 ]; then
            echo "Replacement successful"
            rm traefik-ingress.yaml.bak
        else
            echo "sed encountered an error"
            mv traefik-ingress.yaml.bak traefik-ingress.yaml
            exit 1
        fi
    else
        echo "Failed to download traefik-ingress.yaml"
        exit 1
    fi
fi

echo -e "\e[32mTraefik files downloaded successfully and modified\e[0m"

if [ -z "$traefik_namespace" ] ; then
    echo -e "\e[32mInstalling Traefik\e[0m"
    helm install --namespace=traefik traefik traefik/traefik -f traefik-values.yaml 2>/dev/null
    kubectl apply -f traefik-manifest.yaml
    if [ $set_tls_ingress = "true" ] ; then
        kubectl apply -f traefik-ingress.yaml
    fi
else
    echo -e "\e[32mTraefik already installed Upgrading Instead\e[0m"
    helm upgrade --namespace=traefik traefik traefik/traefik -f traefik-values.yaml 2>/dev/null
    kubectl apply -f traefik-manifest.yaml
    if [ $set_tls_ingress = "true" ] ; then
        kubectl apply -f traefik-ingress.yaml
    fi
fi

if [ $keep_manifestes = "true" ] ; then
    if [ ! -d "$HOME/kubernetes/manifests/traefik" ] ; then
            echo -e "\e[32mCreating Manifest Directory for traefik: $HOME/kubernetes/manifests/traefik\e[0m"
            mkdir -p $HOME/kubernetes/manifests/traefik
        fi
    echo -e "\e[32mStoring traefik files in $HOME/kubernetes/manifests/traefik\e[0m"
    mv $HOME/traefik-values.yaml $HOME/kubernetes/manifests/traefik/traefik-values.yaml
    mv $HOME/traefik-manifest.yaml $HOME/kubernetes/manifests/traefik/traefik-manifest.yaml
    if [ $set_tls_ingress = "true" ] ; then
        mv $HOME/traefik-ingress.yaml $HOME/kubernetes/manifests/traefik/traefik-ingress.yaml
    fi
else
    rm $HOME/traefik-values.yaml
    rm $HOME/traefik-manifest.yaml
    if [ $set_tls_ingress = "true" ] ; then
        rm $HOME/traefik-ingress.yaml
    fi
fi

echo -e "\e[32mTraefik installed successfully\e[0m"

#############################################
#      FINISHED TRAEFIK INSTALLATION        #
#############################################

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi