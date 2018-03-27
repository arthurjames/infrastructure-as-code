# Infra

This project helps to setup the ArthurJames environment on OpenStack.

## Getting started

There are 2 major steps to be taken:
* using terraform to deploy the infrastructure
* using ansible configure the nodes in your infrastructure

### Terraform

First, follow these steps to set up the core environment (vpc, subnets, acl's and bastion).

#### Global variables

Generate the vars that serve for setting up the core environment.

```
$ cd terraform/envs/ims/ims_vars
$ terraform apply
```

You'll need to fill in two values:
* var.key_name - which is the AWS key pair name you'll be using
* var.office_cidr - which is the network from where you'll grant SSH access to the public subnet. For example: 1.1.1.1/32.

#### Core environment

```
$ cd terraform/envs/ims/core
$ terraform init
$ terraform plan
$ terraform apply
```

#### Infrastructure Management System (IMS)

This step will create the necessary EC2 instances, three on the IMS subnet:
* jenkins
* elasticsearch
* prometheus

And finally, the proxy for the webinterfaces of elasticsearch and prometheus:
* nginx proxy

#### Kubernetes

This step will create a kubernetes setup which consists of:
* master
* slaves
* etcd

#### Connect to bastion

OSX:
```
$ ssh-add -k ~/.ssh/yourprivatekey.pem
$ ssh-add -L
```

### Ansible

For configuration of the nodes we'll move to AWS. We want to configure all nodes be it on public or private subnets. Because most
nodes do not have a public dns name, nor public ip, we need to select those nodes by private ip's.

#### Preparation

Get the ansible roles you need:
```
$ cd ansible
$ ansible-galaxy install -r requirements.yml
```

#### Bootstrap

We need a node where we can bootstrap the ansible playbooks from. For convenience, we'll pick the bastion host.

#### Problems

```
ubuntu@bastion_1:~/infrastructure-as-code/ansible$ ansible-playbook bootstrap.yml
ERROR! no action detected in task

The error appears to have been in '/etc/ansible/roles/ansible-role-ntp/tasks/main.yml': line 19, column 3, but may
be elsewhere in the file depending on the exact syntax problem.

The offending line appears to be:


- name: Set timezone
  ^ here
```

The problem here is you're having an old ansible version installed. Should be >= 2.2.
```
root@ip-10-0-1-124:~# apt-add-repository ppa:ansible/ansible
ubuntu@bastion_1:~# sudo apt-get update
ubuntu@bastion_1:~# sudo apt-get install ansible
ubuntu@bastion_1:~# ansible --version
ansible 2.5.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/root/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.12 (default, Dec  4 2017, 14:50:18) [GCC 5.4.0 20160609]
```

## Acknowledgements

* Inspiration for the terraform setup is taken from Nicki Watt's talk at HashiConf 2017. See [OpenCredo](https://www.youtube.com/watch?v=wgzgVm7Sqlk&t=16s)
