#!/usr/bin/env bash
set -e
cd terraform
terraform destroy -auto-approve
rm terraform*
rm -rf tmp/
rm -rf ../etc
