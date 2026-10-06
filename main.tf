terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------
# 1. The four VPCs (custom mode = we create the subnets ourselves)
# ------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  for_each                = var.vpcs
  name                    = "vpc-${each.key}"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# ------------------------------------------------------------------
# 2. One subnet per VPC in us-central1
# ------------------------------------------------------------------
resource "google_compute_subnetwork" "subnet" {
  for_each      = var.vpcs
  name          = "subnet-${each.key}"
  region        = var.region
  network       = google_compute_network.vpc[each.key].id
  ip_cidr_range = each.value
}

# ------------------------------------------------------------------
# 3. Firewall rules (GCP blocks all ingress by default)
#    - allow ping/SSH from every VPC range (so peered VMs can talk)
#    - allow SSH from Google IAP (so you can log in without public IPs)
# ------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  for_each      = var.vpcs
  name          = "allow-internal-${each.key}"
  network       = google_compute_network.vpc[each.key].name
  direction     = "INGRESS"
  source_ranges = values(var.vpcs)

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  for_each      = var.vpcs
  name          = "allow-iap-ssh-${each.key}"
  network       = google_compute_network.vpc[each.key].name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # Google IAP range

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ------------------------------------------------------------------
# 4. One VM per VPC (no external IP, reach it via IAP SSH)
# ------------------------------------------------------------------
resource "google_compute_instance" "vm" {
  for_each     = var.vpcs
  name         = "vm-${each.key}"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet[each.key].id
    # No access_config block = no public IP
  }
}

# ------------------------------------------------------------------
# 5. Hub-and-spoke VPC peering
#    Shared = hub. b3, b4, bsys = spokes.
#    A peering needs TWO halves (one from each side), and both halves
#    must exist before the connection becomes ACTIVE.
#
#    import_custom_routes = "I accept custom routes from the other side"
#    export_custom_routes = "I share my custom routes with the other side"
#
#    GCP can't create several peerings on the same VPC at the same
#    time, so each one depends_on the previous one to run in sequence.
# ------------------------------------------------------------------

# ---- Shared <-> B3 ----
resource "google_compute_network_peering" "shared_to_b3" {
  name                 = "peer-shared-to-b3"
  network              = google_compute_network.vpc["shared"].self_link
  peer_network         = google_compute_network.vpc["b3"].self_link
  import_custom_routes = true
  export_custom_routes = true
}

resource "google_compute_network_peering" "b3_to_shared" {
  name                 = "peer-b3-to-shared"
  network              = google_compute_network.vpc["b3"].self_link
  peer_network         = google_compute_network.vpc["shared"].self_link
  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network_peering.shared_to_b3]
}

# ---- Shared <-> B4 ----
resource "google_compute_network_peering" "shared_to_b4" {
  name                 = "peer-shared-to-b4"
  network              = google_compute_network.vpc["shared"].self_link
  peer_network         = google_compute_network.vpc["b4"].self_link
  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network_peering.b3_to_shared]
}

resource "google_compute_network_peering" "b4_to_shared" {
  name                 = "peer-b4-to-shared"
  network              = google_compute_network.vpc["b4"].self_link
  peer_network         = google_compute_network.vpc["shared"].self_link
  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network_peering.shared_to_b4]
}

# ---- Shared <-> BSYS ----
resource "google_compute_network_peering" "shared_to_bsys" {
  name                 = "peer-shared-to-bsys"
  network              = google_compute_network.vpc["shared"].self_link
  peer_network         = google_compute_network.vpc["bsys"].self_link
  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network_peering.b4_to_shared]
}

resource "google_compute_network_peering" "bsys_to_shared" {
  name                 = "peer-bsys-to-shared"
  network              = google_compute_network.vpc["bsys"].self_link
  peer_network         = google_compute_network.vpc["shared"].self_link
  import_custom_routes = true
  export_custom_routes = true

  depends_on = [google_compute_network_peering.shared_to_bsys]
}
