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

echo -e " \033[34;5m            Longhorn Deployment Script              \033[0m"
echo

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                         App Versions                                              ###
#########################################################################################################
longhorn_version="v1.5.3" # Longhorn Version
#########################################################################################################
###                                     Inner Script Variables                                        ###
#########################################################################################################

############################
#  ╔════════════════════╗  #
#  ║   Main Variables   ║  #
#  ╚════════════════════╝  #
############################
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
#         STARTING LONGHORN INSTALLATION         #
##################################################

curl -sO https://raw.githubusercontent.com/longhorn/longhorn/$longhorn_version/deploy/longhorn.yaml
if [ $? -eq 0 ] ; then
    echo -e "\033[32;5mLonghorn manifest downloaded successfully!\033[0m"
else
    echo -e "\033[31;5mLonghorn manifest download failed!\033[0m"
    echo -e "\033[31;5mExiting...\033[0m"
    exit 1
fi

# Apply the Longhorn manifest
echo -e "\033[32;5mApplying Longhorn manifest\033[0m"
kubectl apply -f longhorn.yaml

if [ $keep_manifestes == "true" ] ; then
    if [ ! -d "$HOME/kubernetes/manifests/longhorn" ] ; then
        mkdir -p $HOME/kubernetes/manifests/longhorn
    fi
    mv longhorn.yaml $HOME/kubernetes/manifests/longhorn/longhorn.yaml
else
    rm longhorn.yaml
fi

##################################################
#         FINISHED LONGHORN INSTALLATION         #
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