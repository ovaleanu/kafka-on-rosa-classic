output "cluster_id" {
  value = rhcs_cluster_rosa_classic.rosa_kafka_cluster.id
}

output "api_url" {
  value = rhcs_cluster_rosa_classic.rosa_kafka_cluster.api_url
}

output "oidc_endpoint_url" {
  value = rhcs_cluster_rosa_classic.rosa_kafka_cluster.sts.oidc_endpoint_url
}

output "console_url" {
  value = rhcs_cluster_rosa_classic.rosa_kafka_cluster.console_url
}

output "rosa_admin_password_secret_name" {
  description = "Cluster admin password secret name"
  value       = aws_secretsmanager_secret.rosa_kafka.name
}
