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

echo -e " \033[34;5m   K3S Let's Encrypt Certificate Deployment Script  \033[0m"
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

domain="domain.tld"
# Domain for Let's Encrypt

tls_secret="domain-tls"
# Name of the TLS secret

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

#################################################
#      STARTING CERTIFICATE INSTALLATION        #
#################################################

# Check that ClusterIssuer letsencrypt-production exists, otherwise error out
if [ ! "$(kubectl get clusterissuer letsencrypt-production)" ] ; then
    echo -e "\e[31mClusterIssuer letsencrypt-production not found\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Download the certificate manifest file
echo -e "\e[32mDownloading certificate manifest file\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/traefik/letsencrypt-certificate-manifest.yaml
if [ -f "letsencrypt-certificate-manifest.yaml" ] ; then
    echo -e "\e[32mCertificate manifest file downloaded\e[0m"
    # Replace domain and tls_secret variables in certificate manifest file
    echo -e "\e[32mReplacing domain and tls_secret variables in certificate manifest file\e[0m"
    sed -i.bak \
    -e "s|\\\$domain|$domain|g" \
    -e "s|\\\$tls_secret|$tls_secret|g" letsencrypt-certificate-manifest.yaml

    if [ $? -eq 0 ]; then
        echo -e "\e[32mCertificate manifest file modified\e[0m"
    else
        echo -e "\e[31mFailed to modify certificate manifest file\e[0m"
        echo -e "\e[31mExiting...\e[0m"
        exit 1
    fi
else
    echo -e "\e[31mCertificate manifest file not downloaded\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Apply the certificate manifest file
echo -e "\e[32mApplying certificate manifest file\e[0m"
kubectl apply -f letsencrypt-certificate-manifest.yaml
if [ $? -eq 0 ]; then
    echo -e "\e[32mCertificate manifest file applied\e[0m"
else
    echo -e "\e[31mFailed to apply certificate manifest file\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

# Check if keep_manifestes is set to true, if so move manifest files to manifests folder
if [ $keep_manifestes = "true" ]; then
    if [ ! -d "$HOME/kubernetes/manifests/traefik" ] ; then
        echo -e "\e[32mCreating Manifest Directory for traefik: $HOME/kubernetes/manifests/traefik\e[0m"
        mkdir -p $HOME/kubernetes/manifests/traefik
    fi
    echo -e "\e[32mStoring certificate manifest file in $HOME/kubernetes/manifests/traefik\e[0m"
    mv $HOME/letsencrypt-certificate-manifest.yaml $HOME/kubernetes/manifests/traefik/letsencrypt-certificate-manifest.yaml
else
    rm $HOME/letsencrypt-certificate-manifest.yaml
fi

echo -e "\e[32mCertificate installed successfully\e[0m"

#################################################
#      FINISHED CERTIFICATE INSTALLATION        #
#################################################


# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi