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
        rm letsencrypt-certificate-manifest.yaml.bak
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