output "cluster_id" {
  value = aws_eks_cluster.bankops.id
}

output "node_group_id" {
  value = aws_eks_node_group.bankops.id
}

output "vpc_id" {
  value = aws_vpc.bankops_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bankops_subnet[*].id
}

