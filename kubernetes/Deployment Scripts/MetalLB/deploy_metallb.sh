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

echo -e " \033[34;5m            Metallb Deployment Script               \033[0m"
echo
echo

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                         App Versions                                              ###
#########################################################################################################
metallb_version="v0.13.12" # metallb version
#########################################################################################################
###                                     Inner Script Variables                                        ###
#########################################################################################################
keep_manifestes="true"                  
# Set this to true to keep a copy of all manifest files in the manifests folder

lbrange=192.168.200.150-192.168.200.199     
# The desired range to be available for load balancing services
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

################################
#     METALLB INSTALLATION     #
################################

# Install MetalLB for Load Balancing
echo -e "\e[32mInstalling MetalLB on Cluster\e[0m"


# Create MetalLB namespace
echo -e "\e[32mCreating MetalLB Namespace\e[0m"
kubectl create namespace metallb-system
echo -e "\033[32;5mMetalLB Namespace created successfully!\033[0m"

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/$metallb_version/config/manifests/metallb-native.yaml

# Wait until a pod has been created for the metallb system, suppress output
echo -e "\e[32mWaiting for MetalLB pod to be created\e[0m"
while [ "$(kubectl get pods -n metallb-system -o jsonpath='{.items[0].metadata.name}' 2>/dev/null )" = "" ]; do
    echo -e "\e[32mMetalLB pod not created, waiting 3 seconds\e[0m"
    sleep 3
done

# Wait for MetalLB to be ready
echo -e "\e[32mWaiting for MetalLB to be ready\e[0m"
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=component=controller \
                --timeout=120s

# Download ipAddressPool and configure using lbrange above
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/metallb/metallb.yaml # Download MetalLB manifest
sed -i.bak 's/$lbrange/'"$lbrange"'/g' metallb.yaml # Replace $lbrange with lbrange variable
rm metallb.yaml.bak # Remove backup file

# Apply MetalLB manifest
kubectl apply -f metallb.yaml

if [ $keep_manifestes = "true" ] ; then
    echo -e "\e[32mCreating Manifest Directory for MetalLB: $HOME/kubernetes/manifests/metallb\e[0m"
    mkdir -p $HOME/kubernetes/manifests/metallb # Create directory for MetalLB manifest
    echo -e "\e[32mStoring metallb manifests in $HOME/kubernetes/manifests/metallb\e[0m"    
    curl -sO https://raw.githubusercontent.com/metallb/metallb/$metallb_version/config/manifests/metallb-native.yaml # Download MetalLB manifest
    mv $HOME/metallb-native.yaml $HOME/kubernetes/manifests/metallb/metallb-native.yaml # Move MetalLB manifest to directory
    mv $HOME/metallb.yaml $HOME/kubernetes/manifests/metallb/metallb.yaml # Move MetalLB manifest to directory
else
    rm $HOME/metallb-native.yaml # Remove MetalLB manifest from local machine
    rm $HOME/metallb.yaml # Remove MetalLB manifest from local machine
fi

# Installation complete
echo -e "\033[32;5mMetalLB installed successfully!\033[0m"

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi