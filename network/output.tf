output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "restricted-subnet-id" {
  value = google_compute_subnetwork.restricted.id
}

output "restricted-subnet-name" {
  value = google_compute_subnetwork.restricted.name
}