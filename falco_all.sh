#!/bin/bash

./falco_build_module.sh
./falco_storage.sh
./falco_helm_setup.sh
./falco_deploy.sh

