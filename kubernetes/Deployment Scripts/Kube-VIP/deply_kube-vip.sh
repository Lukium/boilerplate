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

echo -e " \033[34;5m            Kube-Vip Deployment Script              \033[0m"
echo

declare -A masters

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                         App Versions                                              ###
#########################################################################################################
kube_vip_version="v0.6.4" # Kube-VIP Version
#########################################################################################################
###                                     Inner Script Variables                                        ###
#########################################################################################################
#  ╔════════════════════╗
#  ║   Main Variables   ║
#  ╚════════════════════╝
keep_manifestes="true"                  
# Set this to true to keep a copy of all manifest files in the manifests folder

vip=192.168.200.100                       
# the desired Virtual IP for the master nodes

interface=eth0                          
# connection interface on the hosts. You can check this by running 'ip a' on the hosts
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

################################
#     KUBE-VIP INSTALLATION    #
################################
# Install Kube-VIP for High Availability

echo -e "\e[32mInstalling Kube-VIP on Cluster...\e[0m"

echo -e "\e[32mApplying kube0vip rbac from kube-vip.io...\e[0m"
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml # Install RBAC

echo -e "\e[32mDownloading base kube-vip manifest, modifying it, and applying it...\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/kube-vip/kube-vip.yaml # Download kube-vip manifest
sed -i.bak 's/$kube_vip_version/'"$kube_vip_version"'/g; s/$interface/'"$interface"'/g; s/$vip/'"$vip"'/g' kube-vip.yaml
rm kube-vip.yaml.bak # Remove backup file
kubectl apply -f kube-vip.yaml # Apply kube-vip manifest

echo -e "\e[32mApplying kube-vip-cloud-controller.yaml kube-vip's github...\e[0m"
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

# Use CURL to add VIP to Certificate.
curl -vk --resolve $vip:6443:127.0.0.1  https://$vip:6443/ping &> /dev/null 

if [ $keep_manifestes = "true" ] ; then
    echo -e "\e[32mCreating Manifest Directory for kube-vip: $HOME/kubernetes/manifests/kube-vip\e[0m"
    mkdir -p $HOME/kubernetes/manifests/kube-vip # Create directory for kube-vip manifest
    echo -e "\e[32mStoring RBAC manifest in $HOME/kubernetes/manifests/kube-vip-rbac.yaml\e[0m"
    curl -sO https://kube-vip.io/manifests/rbac.yaml # Download kube-vip manifest
    mv $HOME/rbac.yaml $HOME/kubernetes/manifests/kube-vip/rbac.yaml # Move kube-vip manifest to directory
    echo -e "\e[32mStoring kube-vip.yaml in $HOME/kubernetes/manifests/kube-vip.yaml\e[0m"
    mv $HOME/kube-vip.yaml $HOME/kubernetes/manifests/kube-vip/kube-vip.yaml # Move kube-vip manifest to directory
    echo -e "\e[32mStoring kube-vip-cloud-controller.yaml in $HOME/kubernetes/manifests/kube-vip-cloud-controller.yaml\e[0m"
    curl -sO https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml # Download kube-vip manifest
    mv $HOME/kube-vip-cloud-controller.yaml $HOME/kubernetes/manifests/kube-vip/kube-vip-cloud-controller.yaml # Move kube-vip manifest to directory    
else
    rm $HOME/rbac.yaml # Remove kube-vip manifest from local machine
    rm $HOME/kube-vip.yaml # Remove kube-vip manifest from local machine
    rm $HOME/kube-vip-cloud-controller.yaml # Remove kube-vip manifest from local machine
fi

echo -e "\033[32;5mKube-VIP installed successfully!\033[0m"

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi