#!/bin/bash

. ./config.source

echo "Deploying falco on ${BaseNode}..."

rsync -arve ssh ./falco root@${BaseNode}:~/

ssh -t root@${BaseNode} '
echo
helm  list --all-namespaces

helm  delete falco -n falco
sleep 1

helm install falco falcosecurity/falco -f falco/falco-values-kmod-norule.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 

# helm install falco falcosecurity/falco -f falco/falco-values-kmod-default.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 
# helm install falco falcosecurity/falco -f falco/falco-values-kmod.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 
# helm upgrade falco falcosecurity/falco -f falco/falco-values-kmod-default.yaml -f falco/custom-rules-process.yaml -f falco/custom-rules-network.yaml --namespace falco --create-namespace

echo
watch -n 1 "kubectl get pods -n falco -o wide"
echo
helm  list --all-namespaces
'
