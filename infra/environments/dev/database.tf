# 1. Allocate an IP range for Private Service Access (PSA)
# This prevents IP conflicts between your VPC and Google's managed services
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}
# 2. Create the VPC Peering connection
# This "connects" the Google-managed network (where Cloud SQL lives) to your VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# 3. The Random ID for the instance name abhinav
# Cloud SQL instance names cannot be reused immediately after deletion. 
# This saves the headaches during "terraform destroy/apply" cycles.
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

# 4. The Cloud SQL Instance
resource "google_sql_database_instance" "main" {
  name             = "video-db-${random_id.db_name_suffix.hex}"
  region           = "us-central1"
  database_version = "POSTGRES_15"

  # Depends on the network peering being established first!
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    # "db-f1-micro" is the cheapest (shared core), but often OOMs with heavy writes.
    # "db-custom-1-3840" (1 vCPU, 3.75GB RAM) is the minimum for a reliable portfolio.
    tier = "db-f1-micro" 
    
    # Cost Optimization: Storage auto-scaling
    disk_autoresize = true
    disk_size       = 10
    disk_type       = "PD_SSD"

    # Availability: Single zone for dev/portfolio cost savings
    availability_type = "ZONAL" 

    ip_configuration {
      ipv4_enabled    = false # STRICTLY NO PUBLIC IP
      private_network = google_compute_network.vpc.id
    }
    
    # Backup configuration (Good practice to show, even if dev)
    backup_configuration {
      enabled = true
      start_time = "04:00"
    }
  }
  
  # Prevent accidental deletion by Terraform (Safety)
  deletion_protection = false # Set to true for Prod
}

# 5. The Database & User
resource "google_sql_database" "database" {
  name     = "videodb"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "users" {
  name     = "video_user"
  instance = google_sql_database_instance.main.name
  password = "CHANGE_ME_IN_PROD_OR_USE_SECRET_MANAGER" # We will fix this later with K8s Secrets
}