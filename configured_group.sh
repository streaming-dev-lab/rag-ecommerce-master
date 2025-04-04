#!/bin/sh

current_dir=$(pwd)
gp_name=$(echo "$current_dir" | cut -d'/' -f3)

echo "Directory name: $gp_name"

sed -i "s/Name = \"bastion\"/Name = \"${gp_name}\"/g" terraform/main.tf
echo "Configured group to → '$gp_name'"
