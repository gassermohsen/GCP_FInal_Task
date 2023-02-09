resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "management" {
  name          = var.management-subnet-name
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1" 
}
 
resource "google_compute_subnetwork" "restricted" {
  name          = var.restricted-subnet-name
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1" 
  private_ip_google_access = true
}

#Nat & Router


resource "google_compute_router" "router" {
  name    = "managment-router"
  region  = google_compute_subnetwork.management.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat_ip" {
  name = "nat-ip"
  region = "us-central1"
}


resource "google_compute_router_nat" "nat" {
  name                               = "managment-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat_ip.*.self_link
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.management.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}



#Create firewall rule to allow ssh access to the private vm with the targets
resource "google_compute_firewall" "management_subnet_firewall" {
  name    = "management-subnet-firewall"
  network = google_compute_network.vpc.id
  direction = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags = ["vm-management"]
  priority = 100
  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }
}

#Create service account for the vm

resource "google_service_account" "private-vm-service-account" {
  project = "seventh-fact-375708"
  account_id = "vm-service-account"
  display_name = "vm-service-account"
}

resource "google_project_iam_member" "role_binding" {
  project = "seventh-fact-375708"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.private-vm-service-account.email}"
}




#Create private Vm

resource "google_compute_instance" "private-management-vm" {
  name         = "private-vm"
  machine_type = "f1-micro"
  zone         = "us-central1-a"
 
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }
  metadata = {
  enable-oslogin = "TRUE"
  }
  tags = ["vm-management"]
  network_interface {
    subnetwork = google_compute_subnetwork.management.id
    # access_config {
    #   nat_ip = google_compute_address.nat_ip.address
    # }
  }
  service_account {
    email = google_service_account.private-vm-service-account.email
    scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  metadata_startup_script = <<-EOF
    sudo apt-get install  -y apt-transport-https ca-certificates gnupg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud -y
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    kubectl version --client
    sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
    # sudo USE_GKE_GCLOUD_AUTH_PLUGIN: True
    # gcloud container clusters get-credentials private-cluster --zone asia-east2-a --project iti-makarios
  EOF
}




