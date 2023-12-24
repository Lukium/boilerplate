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