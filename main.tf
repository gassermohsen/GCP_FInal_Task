
module "Network_module" {
  source="./network"
  vpc_name = "gke-vpc"
  management-subnet-name = "management-subnet"
  restricted-subnet-name = "restricted-subnet"
}
module "gke-cluster" {
    source = "./cluster"
    network_vpc_name = module.Network_module.vpc_name
    sub_network_name = module.Network_module.restricted-subnet-id
}