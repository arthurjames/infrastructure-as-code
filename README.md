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
$ cd terraform/aws/vars
$ terraform apply
```

You'll need to fill in two values:
* var.key_name - which is the AWS key pair name you'll be using
* var.office_cidr - which is the network from where you'll grant SSH access to the public subnet. For example: 1.1.1.1/32.

#### VPC's

There are 4 separate vpc's:
* dmz: contains bastion
* ims: Infrastructure Management System
* dev
* prod

Each VPC can be kicked off with:

```
$ cd terraform/aws/<vpc>
$ terraform init
$ terraform plan
$ terraform apply
```

#### DMZ

DMZ contains your loghost/bastion.

#### Infrastructure Management System (IMS)

This step will create the necessary EC2 instances.
* public subnet:
  * nginx proxy with grafana

* private subnet:
  * jenkins
  * elasticsearch
  * prometheus

#### DEV/PROD

These environments are functionally exactly the same.
* public subnet:
  * nginx proxy
  
* private subnet:  
  * k8s master
  * k8s slaves
  * etcd

#### Peering connections

As a final step, create peering connections between your VPC's and add necessary routing rules.

```
$ cd terraform/aws/network
$ terraform init
$ terraform plan
$ terraform apply
```

### Ansible

For configuation management we use Ansible using a dynamic inventory script behind a bastion.

#### Preparation

Get the ansible roles you need:
```
$ cd ansible
$ ansible-galaxy install -r requirements.yml
```

Make sure your ssh keypair has been added to your ssh-agent:
```
$ ssh-add ~/.ssh/yourprivatekey.pem
$ ssh-add -L
```

In directory `inventory/ec2.ini` check if the following settings are correct:
```
destination_variable = private_dns_name
vpc_destination_variable = private_ip_address
```

Change your ~/.ssh/config (or create one if it doesn't exist):
```
Host 10.*.*.*
  User admin
  IdentityFile ~/.ssh/yourprivatekey.pem
  ProxyCommand ssh -q -W %h:%p bastion
Host bastion
  Hostname <public-dns-bastion>
  IdentityFile ~/ssh/yourprivatekey.pem
  ForwardAgent yes
```  

#### Configuration

```
$ ansible-playbook bootstrap.yml
$ ansible-playbook elastic.yml
$ ansible-playbook grafana.yml
$ ansible-playbook jenkins.yml
$ ansible-playbook prometheus.yml
```

#### Problems

```
admin@bastion_1:~/infrastructure-as-code/ansible$ ansible-playbook bootstrap.yml
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
admin@bastion_1:~# sudo apt-get update
admin@bastion_1:~# sudo apt-get install ansible
admin@bastion_1:~# ansible --version
ansible 2.5.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/root/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.12 (default, Dec  4 2017, 14:50:18) [GCC 5.4.0 20160609]
```

## Acknowledgements

* Inspiration for the terraform setup is taken from Nicki Watt's talk at HashiConf 2017. See [OpenCredo](https://www.youtube.com/watch?v=wgzgVm7Sqlk&t=16s)
