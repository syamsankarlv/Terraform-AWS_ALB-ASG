# Creating Application Load Balancer using Terraform

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

Terraform is a tool for building infrastructure with various technologies including Amazon AWS, Microsoft Azure, Google Cloud, and vSphere. Here is a simple document on how to use Terraform to build an AWS ALB Application load balancer.

This Terraform script sets up an Application Load Balancer (ALB) with associated target groups, listeners, forwarding rules, launch configurations, auto-scaling groups (ASGs), and security groups on AWS. Below is a detailed explanation of the components and configurations used.

# Resources Created

- **[VPC & Components](https://github.com/syamsankarlv/terraform-aws_vpc)**
- **[Target Groups]()**
- **[Application Load Balancer]()**
- **[Listener Configuration-HTTP Listener](Explanation)**
- **[Listener Rules]()**
- **[Launch Configurations]()**
- **[Auto Scaling Groups]()**
- **[Security Groups]()**


# Features

- Easy to use and customize with a fully automated process for simplified operations.
- Enhanced fault tolerance through configured autoscaling.
- Instance Refresh enables automatic deployment of instances within Auto Scaling Groups.
- Host-based routing directs traffic according to specific requirements.
- VPC configuration can be deployed in any region, automatically fetching available zones using the data source AZ.
- Each subnet CIDR block is automatically calculated using the cidrsubnet function.


# Basic Architecture

![Basic Architecture](https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/fbc57233-4ab1-411c-af34-984b173c384e)


## How It Can Be Configured

### VPC Creation

Initially created the VPC with 6 subnets for the networking part, consisting of `3 public` and `3 private` subnets. The subnets were calculated using the `cidrsubnet` function, and the `availability zones` were fetched automatically by the `data source`. I'm not adding the other VPC components in the below code. So I'm concluding here.

```sh
#===============================#
#          VPC Setup            #
#===============================#

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "${var.project}-vpc"
    project = var.project
  }

}

#===============================#
#      Fetching AZ's Name       #
#===============================#

data "aws_availability_zones" "az" {
  state = "available"

}
```

# Target Groups

### Target Group One
```sh
#-------------------------------------#
#         Target Group one            #
#-------------------------------------#

resource "aws_lb_target_group" "tg-one" {
  name                          = "lb-tg-one"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay          = 60
  stickiness {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 60
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name    = "${var.project}-lb-tg-one"
    project = var.project
  }
}
```
This block creates a target group named lb-tg-one that listens on port 80 using the HTTP protocol. It uses a round-robin algorithm for load balancing, with a health check configured to check the root path `(/)` every 30 seconds. Stickiness is disabled, and targets are deregistered with a delay of 60 seconds.

# Application Load Balancer

## ALB Configuration

```sh
#========================================================#
#           Application LoadBalancer                     #
#========================================================#

resource "aws_lb" "lb" {
  name                       = "lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.sgweb.id]
  subnets                    = [aws_subnet.Public-1.id, aws_subnet.Public-2.id, aws_subnet.Public-3.id]
  enable_deletion_protection = false
  depends_on                 = [aws_lb_target_group.tg-one]
  tags = {
    Name    = "${var.project}-lb"
    project = var.project
  }
}


output "alb-endpoint" {
  value = aws_lb.lb.dns_name
}
```
This block creates an ALB named `lb` that is publicly accessible (not internal). It is assigned to security groups and subnets, with deletion protection disabled. The ALB's DNS name is outputted for easy reference.

# Listener Configuration

## HTTP Listener

```sh
#========================================================
# Creating http listener of application loadbalancer
#========================================================

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  #-------------------------------------
  #default action of the target group.
  #-------------------------------------

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-one.arn
  }

  depends_on = [aws_lb.lb]
  tags = {
    Name    = "${var.project}-listener"
    project = var.project
  }
}
```
This block configures an HTTP listener on port 80 for the ALB. The listener forwards incoming requests to `tg-one` by default.

# Listener Rules
## Forwarding Rule for Specific Hostname
```sh
#========================================================#
#    Forwarder with domain-hostname to target group      #
#========================================================#

#-------------------------------------#
#       First forwarding rule         #
#-------------------------------------#

resource "aws_lb_listener_rule" "rule-one" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-one.arn
  }

  condition {
    host_header {
      values = ["first-host-name.example.com"]
      
    }
    
  }
}
```
This block defines a listener rule that forwards requests with the host header `first-host-name.example.com` to `tg-one`.

# Launch Configurations
## Launch Configuration One
```sh
#==========================================#
#          Launch Configurations           #
#==========================================#

resource "aws_launch_configuration" "launch-one" {
  image_id        = var.image_id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.sgweb.id]
  user_data       = file("launch-conf.sh")
  lifecycle {
    create_before_destroy = true
  }
}
```
This block creates a launch configuration using the specified `AMI (image_id)`,`Instance type`, and `security groups`. User data is loaded from a script file `(launch-conf.sh)`.

# Auto Scaling Groups
## Auto Scaling Group One
```sh
#=====================================#
#           ASG Creations             #
#=====================================#

#-------------------------------------#
#   First ASG with Launch conf one    #
#-------------------------------------#

resource "aws_autoscaling_group" "asg-one" {
  launch_configuration = aws_launch_configuration.launch-one.id
  health_check_type    = "EC2"
  min_size             = var.asg_count
  max_size             = var.asg_count
  desired_capacity     = var.asg_count
  vpc_zone_identifier  = [aws_subnet.Public-1.id, aws_subnet.Public-2.id, aws_subnet.Public-3.id]
  target_group_arns    = [aws_lb_target_group.tg-one.arn]
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "asg-one"
  }
  lifecycle {
    create_before_destroy = true
  }
}
```
This block defines an ASG with a specified number of instances `(asg_count)`. The ASG uses the launch configuration `launch-one` and is associated with the target group `tg-one`.

# Security Groups
## Security Group for Web Servers
```sh
#===============================================#
#        Security Groups for webserver          #
#===============================================#

resource "aws_security_group" "sgweb" {
  name        = "sgweb"
  description = "Allow 80,443,22"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name    = "webserver"
    project = var.project
  }
  lifecycle {
    create_before_destroy = true
  }
}

```
This block creates a security group `sgweb` allowing inbound traffic on ports `80 (HTTP)`, `443 (HTTPS)`, and `22 (SSH)` from any IP address `(0.0.0.0/0)`. Egress traffic is unrestricted.


# User Customisation

-  The user can modify only the `variables.tf` file to meet specific requirements without altering the main Terraform scripts directly. This approach facilitates updates to the entire infrastructure and the `userdata` according to the requirements. Consider the example values given below.

```sh
#################################################
# Provider Details & Project Name
#################################################

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true

}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true

}

variable "aws_region" {
  default = "us-east-2"

}

variable "project" {
  default = "Terraform"

}

#################################################
# VPC Requiremnet
#################################################

variable "vpc_cidr" {
  default = "172.16.0.0/16"

}

variable "aws_route_table" {
  description = "Public & Private Route-table"
  default     = "0.0.0.0/0"

}

#################################################
# EC2 Requirement 
#################################################

variable "image_id" {
  default = "ami-04e5276ebb8451442"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "asg_count" {
  default = 3
}
```

# Terraform Outputs

This section explains the Terraform output configurations, which are essential for referencing the generated values of various AWS resources within your Terraform infrastructure.

### Outputs Defined

- #### Availability Zones:
  -  The following outputs provide the names of the availability zones being used. These are fetched dynamically using the data.aws_availability_zones data source.
  - `az-1`,`az-2`,`az-3`: This outputs the name of the first availability zone.
   ```sh
    output "az-1" {
  value = data.aws_availability_zones.az.names[0]
  }

   output "az-2" {
  value = data.aws_availability_zones.az.names[1]
  }

   output "az-3" {
  value = data.aws_availability_zones.az.names[2]
   ```

- ### VPC ID:

    - The vpc_id output provides the ID of the created VPC. This is useful for referencing the VPC in other parts of your Terraform configuration or in different Terraform modules.
    ```sh
    output "vpc_id" {
    value = aws_vpc.vpc.id
    }
    ```

- ### Security Group ID:
   - The `sg_web_id` output provides the ID of the security group named `sgweb`. This is essential for applying security group rules to instances or other AWS services that require network access control.
   ```sh
   output "sg_web_id" {
   value = aws_security_group.sgweb.id
   }
   ```


 # User Instructions

- After completing these, initialize the working directory for Terraform configuration using the below command

```sh
terraform init
```
- Validate the terraform file using the command given below.
```sh
terraform validate
```
- After successful validation, plan the build architecture
```sh
terraform plan 
```

```sh
data.aws_availability_zones.az: Reading...
data.aws_availability_zones.az: Read complete after 2s [id=us-east-1]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_autoscaling_group.asg-one will be created
  + resource "aws_autoscaling_group" "asg-one" {
      + arn                              = (known after apply)
      + availability_zones               = (known after apply)
      + default_cooldown                 = (known after apply)
      + desired_capacity                 = 3
      + force_delete                     = false
      + force_delete_warm_pool           = false
      + health_check_grace_period        = 300
      + health_check_type                = "EC2"
      + id                               = (known after apply)
      + ignore_failed_scaling_activities = false
      + launch_configuration             = (known after apply)
      + load_balancers                   = (known after apply)
      + max_size                         = 3
      + metrics_granularity              = "1Minute"
      + min_size                         = 3
      + name                             = (known after apply)
      + name_prefix                      = (known after apply)
      + predicted_capacity               = (known after apply)
      + protect_from_scale_in            = false
      + service_linked_role_arn          = (known after apply)
      + target_group_arns                = (known after apply)
      + vpc_zone_identifier              = (known after apply)
      + wait_for_capacity_timeout        = "10m"
      + warm_pool_size                   = (known after apply)

      + tag {
          + key                 = "Name"
          + propagate_at_launch = true
          + value               = "asg-one"
        }
    }

  # aws_eip.eip will be created
  + resource "aws_eip" "eip" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + tags                 = {
          + "Name"    = "Terraform-nat-eip"
          + "project" = "Terraform"
        }
      + tags_all             = {
          + "Name"    = "Terraform-nat-eip"
          + "project" = "Terraform"
        }
      + vpc                  = (known after apply)
    }

  # aws_internet_gateway.igw will be created
  + resource "aws_internet_gateway" "igw" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name"    = "Terraform-igw"
          + "project" = "Terraform"
        }
      + tags_all = {
          + "Name"    = "Terraform-igw"
          + "project" = "Terraform"
        }
      + vpc_id   = (known after apply)
    }

  # aws_launch_configuration.launch-one will be created
  + resource "aws_launch_configuration" "launch-one" {
      + arn                         = (known after apply)
      + associate_public_ip_address = (known after apply)
      + ebs_optimized               = (known after apply)
      + enable_monitoring           = true
      + id                          = (known after apply)
      + image_id                    = "ami-04e5276ebb8451442"
      + instance_type               = "t2.micro"
      + key_name                    = (known after apply)
      + name                        = (known after apply)
      + name_prefix                 = (known after apply)
      + security_groups             = (known after apply)
      + user_data                   = "8a49b034b2152b48171cad7e838eafd1e7bc435b"
    }

  # aws_lb.lb will be created
  + resource "aws_lb" "lb" {
      + arn                                                          = (known after apply)
      + arn_suffix                                                   = (known after apply)
      + client_keep_alive                                            = 3600
      + desync_mitigation_mode                                       = "defensive"
      + dns_name                                                     = (known after apply)
      + drop_invalid_header_fields                                   = false
      + enable_deletion_protection                                   = false
      + enable_http2                                                 = true
      + enable_tls_version_and_cipher_suite_headers                  = false
      + enable_waf_fail_open                                         = false
      + enable_xff_client_port                                       = false
      + enforce_security_group_inbound_rules_on_private_link_traffic = (known after apply)
      + id                                                           = (known after apply)
      + idle_timeout                                                 = 60
      + internal                                                     = false
      + ip_address_type                                              = (known after apply)
      + load_balancer_type                                           = "application"
      + name                                                         = "lb"
      + name_prefix                                                  = (known after apply)
      + preserve_host_header                                         = false
      + security_groups                                              = (known after apply)
      + subnets                                                      = (known after apply)
      + tags                                                         = {
          + "Name"    = "Terraform-lb"
          + "project" = "Terraform"
        }
      + tags_all                                                     = {
          + "Name"    = "Terraform-lb"
          + "project" = "Terraform"
        }
      + vpc_id                                                       = (known after apply)
      + xff_header_processing_mode                                   = "append"
      + zone_id                                                      = (known after apply)
    }

  # aws_lb_listener.listener will be created
  + resource "aws_lb_listener" "listener" {
      + arn               = (known after apply)
      + id                = (known after apply)
      + load_balancer_arn = (known after apply)
      + port              = 80
      + protocol          = "HTTP"
      + ssl_policy        = (known after apply)
      + tags              = {
          + "Name"    = "Terraform-listener"
          + "project" = "Terraform"
        }
      + tags_all          = {
          + "Name"    = "Terraform-listener"
          + "project" = "Terraform"
        }

      + default_action {
          + order            = (known after apply)
          + target_group_arn = (known after apply)
          + type             = "forward"
        }
    }

  # aws_lb_listener_rule.rule-one will be created
  + resource "aws_lb_listener_rule" "rule-one" {
      + arn          = (known after apply)
      + id           = (known after apply)
      + listener_arn = (known after apply)
      + priority     = 1
      + tags_all     = (known after apply)

      + action {
          + order            = (known after apply)
          + target_group_arn = (known after apply)
          + type             = "forward"
        }

      + condition {
          + host_header {
              + values = [
                  + "first-host-name.example.com",
                ]
            }
        }
    }

  # aws_lb_target_group.tg-one will be created
  + resource "aws_lb_target_group" "tg-one" {
      + arn                                = (known after apply)
      + arn_suffix                         = (known after apply)
      + connection_termination             = (known after apply)
      + deregistration_delay               = "60"
      + id                                 = (known after apply)
      + ip_address_type                    = (known after apply)
      + lambda_multi_value_headers_enabled = false
      + load_balancer_arns                 = (known after apply)
      + load_balancing_algorithm_type      = "round_robin"
      + load_balancing_anomaly_mitigation  = (known after apply)
      + load_balancing_cross_zone_enabled  = (known after apply)
      + name                               = "lb-tg-one"
      + name_prefix                        = (known after apply)
      + port                               = 80
      + preserve_client_ip                 = (known after apply)
      + protocol                           = "HTTP"
      + protocol_version                   = (known after apply)
      + proxy_protocol_v2                  = false
      + slow_start                         = 0
      + tags                               = {
          + "Name"    = "Terraform-lb-tg-one"
          + "project" = "Terraform"
        }
      + tags_all                           = {
          + "Name"    = "Terraform-lb-tg-one"
          + "project" = "Terraform"
        }
      + target_type                        = "instance"
      + vpc_id                             = (known after apply)

      + health_check {
          + enabled             = true
          + healthy_threshold   = 2
          + interval            = 30
          + matcher             = "200"
          + path                = "/"
          + port                = "traffic-port"
          + protocol            = "HTTP"
          + timeout             = (known after apply)
          + unhealthy_threshold = 2
        }

      + stickiness {
          + cookie_duration = 60
          + enabled         = false
          + type            = "lb_cookie"
        }
    }

  # aws_nat_gateway.nat will be created
  + resource "aws_nat_gateway" "nat" {
      + allocation_id                      = (known after apply)
      + association_id                     = (known after apply)
      + connectivity_type                  = "public"
      + id                                 = (known after apply)
      + network_interface_id               = (known after apply)
      + private_ip                         = (known after apply)
      + public_ip                          = (known after apply)
      + secondary_private_ip_address_count = (known after apply)
      + secondary_private_ip_addresses     = (known after apply)
      + subnet_id                          = (known after apply)
      + tags                               = {
          + "Name"    = "Terraform-nat"
          + "project" = "Terraform"
        }
      + tags_all                           = {
          + "Name"    = "Terraform-nat"
          + "project" = "Terraform"
        }
    }

  # aws_route_table.private will be created
  + resource "aws_route_table" "private" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + carrier_gateway_id         = ""
              + cidr_block                 = "0.0.0.0/0"
              + core_network_arn           = ""
              + destination_prefix_list_id = ""
              + egress_only_gateway_id     = ""
              + gateway_id                 = ""
              + ipv6_cidr_block            = ""
              + local_gateway_id           = ""
              + nat_gateway_id             = (known after apply)
              + network_interface_id       = ""
              + transit_gateway_id         = ""
              + vpc_endpoint_id            = ""
              + vpc_peering_connection_id  = ""
            },
        ]
      + tags             = {
          + "Name"    = "Terraform-route-private"
          + "project" = "Terraform"
        }
      + tags_all         = {
          + "Name"    = "Terraform-route-private"
          + "project" = "Terraform"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table.public will be created
  + resource "aws_route_table" "public" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + carrier_gateway_id         = ""
              + cidr_block                 = "0.0.0.0/0"
              + core_network_arn           = ""
              + destination_prefix_list_id = ""
              + egress_only_gateway_id     = ""
              + gateway_id                 = (known after apply)
              + ipv6_cidr_block            = ""
              + local_gateway_id           = ""
              + nat_gateway_id             = ""
              + network_interface_id       = ""
              + transit_gateway_id         = ""
              + vpc_endpoint_id            = ""
              + vpc_peering_connection_id  = ""
            },
        ]
      + tags             = {
          + "Name"    = "Terraform-route-public"
          + "project" = "Terraform"
        }
      + tags_all         = {
          + "Name"    = "Terraform-route-public"
          + "project" = "Terraform"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.private1 will be created
  + resource "aws_route_table_association" "private1" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_route_table_association.private2 will be created
  + resource "aws_route_table_association" "private2" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_route_table_association.private3 will be created
  + resource "aws_route_table_association" "private3" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_route_table_association.public1 will be created
  + resource "aws_route_table_association" "public1" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_route_table_association.public2 will be created
  + resource "aws_route_table_association" "public2" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_route_table_association.public3 will be created
  + resource "aws_route_table_association" "public3" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_security_group.sgweb will be created
  + resource "aws_security_group" "sgweb" {
      + arn                    = (known after apply)
      + description            = "Allow 80,443,22"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = ""
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTP"
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTPS"
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "SSH"
              + from_port        = 22
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 22
            },
        ]
      + name                   = "sgweb"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name"    = "webserver"
          + "project" = "Terraform"
        }
      + tags_all               = {
          + "Name"    = "webserver"
          + "project" = "Terraform"
        }
      + vpc_id                 = (known after apply)
    }

  # aws_subnet.Private-1 will be created
  + resource "aws_subnet" "Private-1" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.96.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-private-1"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-private-1"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_subnet.Private-2 will be created
  + resource "aws_subnet" "Private-2" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.160.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-private-2"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-private-2"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_subnet.Private-3 will be created
  + resource "aws_subnet" "Private-3" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.192.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-private-3"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-private-3"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_subnet.Public-1 will be created
  + resource "aws_subnet" "Public-1" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.0.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-public-1"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-public-1"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_subnet.Public-2 will be created
  + resource "aws_subnet" "Public-2" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.32.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-public-2"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-public-2"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_subnet.Public-3 will be created
  + resource "aws_subnet" "Public-3" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "172.16.64.0/19"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name"    = "Terraform-public-3"
          + "project" = "Terraform"
        }
      + tags_all                                       = {
          + "Name"    = "Terraform-public-3"
          + "project" = "Terraform"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_vpc.vpc will be created
  + resource "aws_vpc" "vpc" {
      + arn                                  = (known after apply)
      + cidr_block                           = "172.16.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + tags                                 = {
          + "Name"    = "Terraform-vpc"
          + "project" = "Terraform"
        }
      + tags_all                             = {
          + "Name"    = "Terraform-vpc"
          + "project" = "Terraform"
        }
    }

Plan: 25 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb-endpoint      = (known after apply)
  + az-1              = "us-east-1a"
  + az-2              = "us-east-1b"
  + az-3              = "us-east-1c"
  + sg_web_id         = (known after apply)
  + subnet_Public1_id = (known after apply)
  + vpc_id            = (known after apply)

```
- Listing the Created items
```sh
terraform state list
```
```sh
data.aws_availability_zones.az
aws_autoscaling_group.asg-one
aws_eip.eip
aws_internet_gateway.igw
aws_launch_configuration.launch-one
aws_lb.lb
aws_lb_listener.listener
aws_lb_listener_rule.rule-one
aws_lb_target_group.tg-one
aws_nat_gateway.nat
aws_route_table.private
aws_route_table.public
aws_route_table_association.private1
aws_route_table_association.private2
aws_route_table_association.private3
aws_route_table_association.public1
aws_route_table_association.public2
aws_route_table_association.public3
aws_security_group.sgweb
aws_subnet.Private-1
aws_subnet.Private-2
aws_subnet.Private-3
aws_subnet.Public-1
aws_subnet.Public-2
aws_subnet.Public-3
aws_vpc.vpc
```



## OUTPUT SNAPSHOTS

<img width="787" alt="Resource-map" src="https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/4f321a36-d097-4b81-a388-eed6be94f6b4">

<img width="905" alt="Screenshot_1" src="https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/8cbf5cdc-2919-4401-a840-8fe282890a40">

<img width="811" alt="Screenshot_2" src="https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/9809f22a-dc3d-4bb5-a0cc-9e44246dbfb9">

<img width="799" alt="Screenshot_3" src="https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/b1b0cf0b-710c-4886-9cc1-c6d29f5fa48b">


<img width="737" alt="Screenshot_4" src="https://github.com/syamsankarlv/Terraform-AWS_ALB-ASG/assets/37361340/e7289793-c883-403f-a467-d0e19c73015c">



### ⚙️ Connect with Me

<p align="center">
    <a href="mailto:sankarlvsyam@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white" alt="Gmail"/></a>
    <a href="https://www.linkedin.com/in/syam-sankar-l-v-06bb68119/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"/></a>
</p>
