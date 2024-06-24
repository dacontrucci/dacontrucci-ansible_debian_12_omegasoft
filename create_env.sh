#!/bin/bash
#set -x


conda activate base && \
conda create -p venv/ python=3.9 && \
conda activate ./venv && \

conda install -c conda-forge ansible-core=2.11.2 && \
ansible-galaxy collection install ansible.posix community.mysql community.general
