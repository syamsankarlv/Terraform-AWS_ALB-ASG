
output "az-1" {
  value = data.aws_availability_zones.az.names[0]

}

output "az-2" {
  value = data.aws_availability_zones.az.names[1]

}

output "az-3" {
  value = data.aws_availability_zones.az.names[2]

}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_Public1_id" {
  value = aws_subnet.Public-1.id

}

output "sg_web_id" {
  value = aws_security_group.sgweb.id
}

