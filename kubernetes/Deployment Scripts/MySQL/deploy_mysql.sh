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

echo -e " \033[34;5m             MySQL Deployment Script                \033[0m"
echo

#########################################################################################################
#                                SET YOUR PARAMETERS IN THIS SECTION                                    #
#########################################################################################################
###                                         App Versions                                              ###
#########################################################################################################
mysql_version="8.2.0" # MYSQL Version
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

cleanup_existing="true"
# Set this to true to delete existing PVCs. This will also destroy and existing mysql pods
# in the same namespace as mysql_namespace

#############################
#  ╔═════════════════════╗  #
#  ║   MYSQL Variables   ║  #
#  ╚═════════════════════╝  #
#############################

mysql_database_name="mydatabase"
# Name of the database to create

mysql_root_password="password"
# Root password for MySQL

mysql_ip=192.168.200.151
# IP for MySQL (Must be available in Load Balancer Range)

mysql_port="3306"
# Port for MySQL

use_node_selector="true"
# Set this to true to use node selector for user pods

node_selector_key="has-gpu"
# Node selector key for user pods

node_selector_value="false"
# Node selector value for user pods

mysql_namespace="mysql"
# Namespace for MySQL
# will be used for naming the statefulset as mysql_namespace-statefulset
# will be used for naming the PVC as mysql_namespace-pvc
# will be used for naming the service as mysql_namespace-service

mysql_storage_class="longhorn"
# Storage class for MySQL

mysql_storage_size="5Gi"
# Storage size for MySQL

mysql_min_memory="256Mi"
# Minimum memory for MySQL

mysql_max_memory="1Gi"
# Maximum memory for MySQL

mysql_min_cpu="250m"
# Minimum CPU for MySQL

mysql_max_cpu="1"
# Maximum CPU for MySQL

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

#########################################
#       STARTING MYSQL DEPLOYMENT       #
#########################################

# Ensure that storage class exists
if [ ! -z "$mysql_storage_class" ] ; then
    echo -e "\e[32mEnsuring that $mysql_storage_class storage class exists\e[0m"
    kubectl get sc $mysql_storage_class > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo -e "\e[32m$mysql_storage_class storage class exists\e[0m"
    else
        echo -e "\e[31m$mysql_storage_class storage class does not exist, exiting...\e[0m"
        exit 1
    fi
fi

# Cleanup existing installation if cleanup_existing is true
if [ $cleanup_existing = "true" ] ; then
    echo -e "\e[32mCleaning up existing PVCs\e[0m"
    # Check if mysql is running in the same namespace as mysql_namespace, and if so delete its statefulset
    kubectl get statefulset "${mysql_namespace}-statefulset" -n $mysql_namespace > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo -e "\e[32mMySQL is running in the same namespace as $mysql_namespace, deleting statefulset\e[0m"
        kubectl delete statefulset "${mysql_namespace}-statefulset" -n $mysql_namespace
        # wait for statefulset to be deleted
        echo -e "\e[32mWaiting for statefulset to be deleted\e[0m"
        kubectl wait --for=delete statefulset "${mysql_namespace}-statefulset" -n $mysql_namespace --timeout=300s
        echo -e "\e[32mStatefulset deleted\e[0m"
    fi
    # check if any PVCs exist in the same namespace as mysql_namespace, and if so delete them
    kubectl get pvc -n $mysql_namespace > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo -e "\e[32mPVCs exist in the same namespace as $mysql_namespace, deleting PVCs\e[0m"
        # create an array of names of every PVC in the same namespace as mysql_namespace
        pvc_names=($(kubectl get pvc -n $mysql_namespace | awk '{print $1}' | grep -v NAME))
        # loop through the array and delete each PVC
        for pvc_name in "${pvc_names[@]}" ; do
            echo -e "\e[32mDeleting PVC $pvc_name\e[0m"
            kubectl delete pvc $pvc_name -n $mysql_namespace
            # wait for PVC to be deleted
            echo -e "\e[32mWaiting for PVC to be deleted\e[0m"
            kubectl wait --for=delete pvc $pvc_name -n $mysql_namespace --timeout=300s
        done
    fi
    # check if any services exist in the same namespace as mysql_namespace, and if so delete them
    kubectl get service -n $mysql_namespace > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo -e "\e[32mServices exist in the same namespace as $mysql_namespace, deleting services\e[0m"
        # create an array of names of every service in the same namespace as mysql_namespace
        service_names=($(kubectl get service -n $mysql_namespace | awk '{print $1}' | grep -v NAME))
        # loop through the array and delete each service
        for service_name in "${service_names[@]}" ; do
            echo -e "\e[32mDeleting service $service_name\e[0m"
            kubectl delete service $service_name -n $mysql_namespace
        done
    fi
fi

# Create the namespace if it doesn't already exist
if [ ! -z "$mysql_namespace" ] ; then
    echo -e "\e[32mEnsuring that $mysql_namespace namespace exists\e[0m"
    kubectl get namespace $mysql_namespace > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo -e "\e[32m$mysql_namespace namespace exists\e[0m"
    else
        echo -e "\e[32m$mysql_namespace namespace does not exist, creating...\e[0m"
        kubectl create namespace $mysql_namespace
    fi
fi

# Check if secret name mysql-root-pass with value password exists
echo -e "\e[32mChecking if secret mysql-root-pass exists\e[0m"
kubectl get secret mysql-root-pass -n $mysql_namespace > /dev/null 2>&1
if [ $? -eq 0 ] ; then
    echo -e "\e[32mmysql-root-pass secret exists, removing it and replacing it...\e[0m"
    kubectl delete secret mysql-root-pass -n $mysql_namespace
    kubectl create secret generic mysql-root-pass --from-literal=password=$mysql_root_password -n $mysql_namespace
else
    echo -e "\e[32mmysql-root-pass secret does not exist, creating...\e[0m"
    kubectl create secret generic mysql-root-pass --from-literal=password=$mysql_root_password -n $mysql_namespace
fi

# Download the MySQL manifest
echo -e "\e[32mDownloading MySQL manifest\e[0m"
curl -sO https://raw.githubusercontent.com/Lukium/boilerplate/main/kubernetes/manifests/mysql/mysql-manifest.yaml
if [ -f mysql-manifest.yaml ] ; then
    echo -e "\e[32mMySQL manifest downloaded successfully\e[0m"
    sed -i.bak \
    -e "s|\\\$mysql_version|$mysql_version|g" \
    -e "s|\\\$mysql_database_name|$mysql_database_name|g" \
    -e "s|\\\$mysql_root_password|$mysql_root_password|g" \
    -e "s|\\\$mysql_ip|$mysql_ip|g" \
    -e "s|\\\$mysql_port|$mysql_port|g" \
    -e "s|\\\$node_selector_key|$node_selector_key|g" \
    -e "s|\\\$node_selector_value|$node_selector_value|g" \
    -e "s|\\\$mysql_namespace|$mysql_namespace|g" \
    -e "s|\\\$mysql_storage_class|$mysql_storage_class|g" \
    -e "s|\\\$mysql_storage_size|$mysql_storage_size|g" \
    -e "s|\\\$mysql_min_memory|$mysql_min_memory|g" \
    -e "s|\\\$mysql_max_memory|$mysql_max_memory|g" \
    -e "s|\\\$mysql_min_cpu|$mysql_min_cpu|g" \
    -e "s|\\\$mysql_max_cpu|$mysql_max_cpu|g" mysql-manifest.yaml   

    if [ $? -eq 0 ] ; then
        # Check if use_node_selector is true, if not, remove the nodeSelector section from the manifest
        if [ ! $use_node_selector = "true" ] ; then
            echo -e "\e[32mRemoving nodeSelector section from MySQL manifest\e[0m"
            sed -i.bak \
            -e '/nodeSelector:/,+1d' mysql-manifest.yaml
            if [ $? -eq 0 ] ; then
                echo -e "\e[32mnodeSelector section removed successfully\e[0m"
            else
                echo -e "\e[31mFailed to remove nodeSelector section, exiting...\e[0m"
                exit 1
            fi
        fi
        echo -e "\e[32mMySQL manifest modified successfully\e[0m"
        rm mysql-manifest.yaml.bak
    else
        echo -e "\e[31mMySQL manifest failed to modify, exiting...\e[0m"
        exit 1
    fi
else
    echo -e "\e[31mMySQL manifest failed to download, exiting...\e[0m"
    exit 1
fi

# Apply the MySQL manifest
echo -e "\e[32mApplying MySQL manifest\e[0m"
kubectl apply -f mysql-manifest.yaml

# Wait for MySQL pod to be ready
echo -e "\e[32mWaiting for MySQL pod to be ready\e[0m"
kubectl wait --for=condition=ready pod -l app=mysql -n $mysql_namespace --timeout=300s
echo -e "\e[32mMySQL pod is ready\e[0m"

# Store manifests if keep_manifestes is true
if [ $keep_manifestes = "true" ] ; then
    if [ ! -d "$HOME/kubernetes/manifests/mysql" ] ; then
        echo -e "\e[32mCreating Manifest Directory for MySQL: $HOME/kubernetes/manifests/mysql\e[0m"
        mkdir -p $HOME/kubernetes/manifests/mysql
    fi
    mv mysql-manifest.yaml $HOME/kubernetes/manifests/mysql/mysql-manifest.yaml
else
    rm mysql-manifest.yaml
fi

echo -e "\e[32mMySQL installed successfully\e[0m"

#########################################
#       FINISHED MYSQL DEPLOYMENT       #
#########################################

# Change permissions back to original
if [ ! -z "$kubeconfig" ] && [ $kubeconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging kubeconfig permission back to $kubeconfig_permission\e[0m"
    sudo chmod $kubeconfig_permission $kubeconfig
fi

if [ ! -z "$k3sconfig" ] && [ $k3sconfig_permission != "644" ] ; then
    echo -e "\e[32mChanging k3sconfig permission back to $k3sconfig_permission\e[0m"
    sudo chmod $k3sconfig_permission $k3sconfig
fi