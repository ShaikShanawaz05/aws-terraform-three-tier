\# Three-Tier Web Architecture on AWS using Terraform



This repository contains the complete Infrastructure as Code (IaC) configuration to deploy a high-availability, fault-tolerant Three-Tier Web Application on AWS using Terraform.



\## Architecture Overview

\- \*\*Networking:\*\* Custom VPC (`10.0.0.0/16`) in `ap-south-1` across 2 Availability Zones with 6 subnets (2 Public, 2 Private App, 2 Private DB).

\- \*\*Public Tier:\*\* Application Load Balancer (ALB) routing incoming HTTP traffic.

\- \*\*App Tier:\*\* EC2 instances (`t3.micro`) running Amazon Linux 2023 with Apache web servers in private subnets.

\- \*\*Database Tier:\*\* Amazon RDS MySQL database in isolated DB subnet group.

\- \*\*Security:\*\* Layered Security Groups enforcing principle of least privilege (ALB -> App -> RDS).



\## Deployment \& Cleanup

```bash

\# Initialize Terraform

terraform init



\# Plan Infrastructure

terraform plan



\# Deploy Infrastructure

terraform apply -auto-approve



\# Destroy Infrastructure

terraform destroy -auto-approve

