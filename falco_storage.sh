#!/bin/bash

. ./config.source

ssh root@${BaseNode} "cat << EOF > pv-volume-local.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${PvNode}
EOF

cat <<EOF> sc-local.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f pv-volume-local.yaml 
kubectl apply -f sc-local.yaml 

echo "SC:" ; kubectl get sc ; echo "PV:" ; kubectl get pv ; echo "PVC:" ; kubectl get pvc --all-namespaces
"
