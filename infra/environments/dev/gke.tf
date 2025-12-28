resource "google_container_cluster" "primary" {
  name     = "video-cluster"
  location = "us-central1-a" 
  
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false 
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" 
      display_name = "Home Office"
    }
  }
  
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
    }
}

# The Spot Node Pool
resource "google_container_node_pool" "spot_nodes" {
  name       = "spot-pool"
  cluster    = google_container_cluster.primary.id
  location   = "us-central1-a"
  node_count = 1

  node_config {
    preemptible  = true 
    machine_type = "e2-standard-2" 
    
    # Google recommends spot: true over preemptible: true for new resources
    spot = true 

    # OAuth scopes required for nodes to write logs/monitoring
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Tags for firewall rules
    tags = ["gke-node"]
  }
  
  # Auto-scaling (Essential for Spot instances to recover capacity)
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}