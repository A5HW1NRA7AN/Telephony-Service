#!/bin/bash
# Script to import all running FreeSWITCH resources into Terraform state
set -e

echo "[+] Importing VPC resources..."
terraform import module.vpc.aws_vpc.this[0] vpc-0faa9baa8b2600a27
terraform import module.vpc.aws_subnet.public[0] subnet-01a3e2109040f74c1
terraform import module.vpc.aws_subnet.public[1] subnet-093e0bcc62a7af594
terraform import module.vpc.aws_subnet.private[0] subnet-05a4b9aafa93b138b
terraform import module.vpc.aws_subnet.private[1] subnet-0350e2be2fa8e348a
terraform import module.vpc.aws_internet_gateway.this[0] igw-01a4a6c94c37a2f3c
terraform import module.vpc.aws_nat_gateway.this[0] nat-07edc9bd5d8b128a9
terraform import module.vpc.aws_eip.nat[0] eipalloc-03779c96eb0d5ed9e
terraform import module.vpc.aws_route_table.public[0] rtb-089a4c9724b726920
terraform import module.vpc.aws_route_table.private[0] rtb-02a6a45dcedacd20c

echo "[+] Importing Route Table Associations..."
terraform import module.vpc.aws_route_table_association.public[0] subnet-01a3e2109040f74c1/rtb-089a4c9724b726920
terraform import module.vpc.aws_route_table_association.public[1] subnet-093e0bcc62a7af594/rtb-089a4c9724b726920
terraform import module.vpc.aws_route_table_association.private[0] subnet-05a4b9aafa93b138b/rtb-02a6a45dcedacd20c
terraform import module.vpc.aws_route_table_association.private[1] subnet-0350e2be2fa8e348a/rtb-02a6a45dcedacd20c

echo "[+] Importing Routes..."
terraform import module.vpc.aws_route.public_internet_gateway[0] rtb-089a4c9724b726920_0.0.0.0/0
terraform import module.vpc.aws_route.private_nat_gateway[0] rtb-02a6a45dcedacd20c_0.0.0.0/0

echo "[+] Importing Security Groups..."
terraform import aws_security_group.bastion_sg sg-01e959649402d5eb7
terraform import aws_security_group.proxy_sg sg-0522f1be19e76eff1
terraform import aws_security_group.freeswitch_sg sg-080342fb1ae3a2eb2

echo "[+] Importing Key Pair..."
terraform import aws_key_pair.freeswitch_key_pair freeswitch-key-pair

echo "[+] Importing EC2 Instances & Elastic IP..."
terraform import aws_instance.bastion i-004b48efcfc67a266
terraform import aws_instance.proxy i-015adbdc7a37fca50
terraform import aws_instance.freeswitch i-02780277cc21e2824
terraform import aws_eip.proxy_eip eipalloc-0820bd7bd8730c7ba

echo "[+] All imports completed successfully!"
