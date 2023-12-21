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

echo -e " \033[34;5m Traefik External Service Ingress Deployment Script \033[0m"
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

service_name="rancher"
# Name of the service to be used in the Ingress.
# Will be reacheable at service_name.domain.tld and www.service_name.domain.tld

domain="domain.tld"
# Domain for to be used in Ingress

service_ip=192.168.200.101
# IP of the service to be used in the Ingress

service_port=443
# Port of the service to be used in the Ingress

tls_secret="domain-tls"
# Name of the TLS secret to be used in the Ingress
# You can check your available options with:
# kubectl get secrets -n traefik -o wide | grep tls

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

##############################################
#       STARTING INGRESS INSTALLATION        #
##############################################

# Check that the tls_secret is exists with kubectl
if ! kubectl get secrets -n traefik | grep $tls_secret > /dev/null ; then
    echo -e "\e[31mThe TLS secret $tls_secret does not exist in the traefik namespace\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
else
    echo -e "\e[32mTLS secret $tls_secret found in the traefik namespace\e[0m"
fi

# Download the ingress manifest
echo -e "\e[32mDownloading ingress manifest\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/traefik/traefik-external-ingress.yaml
if [ -f "traefik-external-ingress.yaml" ] ; then
    echo -e "\e[32mIngress manifest downloaded\e[0m"
    # Replace the variables in the manifest
    echo -e "\e[32mReplacing variables in ingress manifest\e[0m"
    sed -i.bak \
    -e "s|\\\$service_name|$service_name|g" \
    -e "s|\\\$domain|$domain|g" \
    -e "s|\\\$service_ip|$service_ip|g" \
    -e "s|\\\$service_port|$service_port|g" \
    -e "s|\\\$tls_secret|$tls_secret|g" traefik-external-ingress.yaml
    if [ $? -eq 0 ] ; then
        echo -e "\e[32mIngress manifest variables replaced\e[0m"
        rm traefik-external-ingress.yaml.bak
        # Apply the ingress manifest
        echo -e "\e[32mApplying ingress manifest\e[0m"
        kubectl apply -f traefik-external-ingress.yaml
        if [ $? -eq 0 ] ; then
            echo -e "\e[32mIngress manifest applied\e[0m"
            # Check if keep_manifestes is set to true and if so, move the manifest to the manifests folder
            if [ "$keep_manifestes" = "true" ] ; then
                if [ ! -d "$HOME/kubernetes/manifests/traefik" ] ; then
                    echo -e "\e[32mCreating manifests folder\e[0m"
                    mkdir -p $HOME/kubernetes/manifests/traefik
                fi
                echo -e "\e[32mMoving ingress manifest to manifests folder\e[0m"
                mv traefik-external-ingress.yaml manifests/traefik-external-ingress.yaml
            else                
                rm traefik-external-ingress.yaml
            fi
        else
            echo -e "\e[31mIngress manifest not applied\e[0m"
            echo -e "\e[31mExiting...\e[0m"
            exit 1
        fi
    else
        echo -e "\e[31mIngress manifest variables not replaced\e[0m"
        echo -e "\e[31mExiting...\e[0m"
        exit 1
    fi
else
    echo -e "\e[31mIngress manifest not downloaded\e[0m"
    echo -e "\e[31mExiting...\e[0m"
    exit 1
fi

echoe -e "\e[32mExternal Ingress Deployment Complete\e[0m"

##############################################
#       FINISHED INGRESS INSTALLATION        #
##############################################

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi