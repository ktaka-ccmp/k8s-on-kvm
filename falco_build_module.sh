#!/bin/bash

. ./config.source


cat << EOF > /tmp/falco_mod_compile.sh
#!/bin/bash

ln -sf /root/linux-6.4.11 /lib/modules/\$(uname -r)/build
aptitude install dkms clang llvm -y

wget ${FalcoSrcURL}
tar xvf ${FalcoSRC}
cp -R ${FalcoBin}/* /
falco-driver-loader
falco-driver-loader bpf

for h in ${MasterNodes} ${WorkerNodes} ; do
	echo scp -o "StrictHostKeyChecking=no" .falco/falco-bpf.o  \$h:/lib/modules/
	scp -o "StrictHostKeyChecking=no" .falco/falco-bpf.o  \$h:/lib/modules/
done

for h in ${MasterNodes} ${WorkerNodes} ; do
	echo ssh \$h 'rmmod falco'
	ssh \$h 'rmmod falco'
	echo rsync -ave ssh /lib/modules/\$(uname -r) \$h:/lib/modules/
	rsync -ave ssh /lib/modules/\$(uname -r) \$h:/lib/modules/
done
EOF

rsync -are ssh ${KernSRC} root@${BaseNode}:/root/
scp -o "StrictHostKeyChecking=no" /tmp/falco_mod_compile.sh root@${BaseNode}:~/
ssh -oStrictHostKeyChecking=no root@${BaseNode} "chmod +x ./falco_mod_compile.sh && time ./falco_mod_compile.sh"


