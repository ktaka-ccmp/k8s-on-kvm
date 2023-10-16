#!/bin/bash

. ./config.source

#####
#####
cat << K8S > /tmp/k8s_setup.sh
#!/bin/bash

aptitude update 
aptitude upgrade -y
aptitude install systemd-sysv apt-transport-https ca-certificates curl gnupg runc wget -y

cat << EOF >/etc/sysctl.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward=1
EOF

cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

wget ${ContainerdURL}
tar Cxzvf /usr/local ${Containerd}

mkdir -p /etc/containerd/
containerd config default | sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' > /etc/containerd/config.toml

wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
cp containerd.service /lib/systemd/system/

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL ${ReleasekeyURL} | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${DebURL} /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

aptitude update 
aptitude install  kubelet kubeadm kubectl -y
apt-mark hold kubelet kubeadm kubectl
K8S

#####
#####

cat << EOF > /tmp/k8s_setup_m.sh
CTL="${MasterNodes#* }"
NODE="${WorkerNodes}"

#####
kubeadm init --control-plane-endpoint=\$(hostname) --pod-network-cidr=10.244.0.0/16

mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

#####
token=\$(kubeadm token list -o yaml | egrep token: |awk '{print \$2}')
hash=\$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
host=\$(hostname)

#####
for ctl in \$CTL ; do rsync -aRve 'ssh -oStrictHostKeyChecking=no' /etc/kubernetes/pki/*[ca,sa].* \$ctl:/; rsync -aRve ssh /etc/kubernetes/pki/etcd/ca.* \$ctl:/; done

for h in \$CTL; do
echo \$h
ssh -oStrictHostKeyChecking=no root@\$h "kubeadm join \$host:6443 --token \$token --discovery-token-ca-cert-hash sha256:\$hash --control-plane"
done

#####
for h in \$NODE ; do
echo \$h
ssh -oStrictHostKeyChecking=no root@\$h "kubeadm join \$host:6443 --token \$token --discovery-token-ca-cert-hash sha256:\$hash"
done

#####
sleep 10
kubectl get  node -o wide
echo
sleep 10
kubectl get  node -o wide

EOF

##### base image setup

wait_for_base_node(){
while ! ssh -oStrictHostKeyChecking=no root@${BaseNode} uptime ; do echo "Waiting for ${BaseNode} to come up." ; sleep 1 ; done
echo "${BaseNode} has come up!"
}

sudo mem=8g smp=4 /kvm/sbin/kvm create ${BaseNode}

wait_for_base_node

scp -o "StrictHostKeyChecking=no" /tmp/k8s_setup.sh root@${BaseNode}:~/
ssh -oStrictHostKeyChecking=no root@${BaseNode} "chmod +x ./k8s_setup.sh && ./k8s_setup.sh && reboot"

wait_for_base_node
ssh root@${BaseNode} "systemctl daemon-reload && systemctl enable --now containerd && sleep 3 && ps -ef |grep containerd "
ssh root@${BaseNode} "poweroff"
sudo /kvm/sbin/kvm con ${BaseNode}

sudo bash -c "for host in ${MasterNodes} ${WorkerNodes} ;do
echo cp /kvm/data/${BaseNode}.img /kvm/data/\$host.img
cp /kvm/data/${BaseNode}.img /kvm/data/\$host.img
done"

for h in ${BaseNode} ${MasterNodes} ${WorkerNodes} ;do echo $h; sudo mem=8g smp=4 /kvm/sbin/kvm create $h ; done

wait_for_base_node
for h in ${BaseNode} ${MasterNodes} ${WorkerNodes} ;do ssh-keygen -f "/home/ktaka/.ssh/known_hosts" -R "$h" ; done
for h in ${BaseNode} ${MasterNodes} ${WorkerNodes} ;do echo $h; ssh -oStrictHostKeyChecking=no root@$h uptime ; done

##### k8s_setup

scp /tmp/k8s_setup_m.sh root@${TheMaster}:~/
ssh root@${TheMaster} "chmod +x ./k8s_setup_m.sh && time ./k8s_setup_m.sh"

ssh root@${BaseNode} "
mkdir -p \$HOME/.kube
scp -o "StrictHostKeyChecking=no" ${TheMaster}:/etc/kubernetes/admin.conf \$HOME/.kube/config-${TheMaster}
(cd \$HOME/.kube/ ; ln -sf config-${TheMaster} config)
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
kubectl get node -o wide
kubectl get pods -o wide --all-namespaces
"

