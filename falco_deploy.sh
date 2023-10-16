#!/bin/bash

. ./config.source

rsync -arve ssh ./falco root@${BaseNode}:~/

ssh root@${BaseNode} '
helm  delete falco -n falco
sleep 1

helm install falco falcosecurity/falco -f falco/falco-values-kmod-norule.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 

# helm install falco falcosecurity/falco -f falco/falco-values-kmod-default.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 
# helm install falco falcosecurity/falco -f falco/falco-values-kmod.yaml -f falco/custom-rules-network.yaml -f falco/custom-rules-process.yaml --namespace falco --create-namespace 
# helm upgrade falco falcosecurity/falco -f falco/falco-values-kmod-default.yaml -f falco/custom-rules-process.yaml -f falco/custom-rules-network.yaml --namespace falco --create-namespace

echo
helm  list --all-namespaces
echo
kubectl get pods -n falco -o wide
'
