# ------------------ General Network Setup ------------------ #
resource "outscale_net" "demo_net" {
    ip_range = "10.0.0.0/16"
}

# ------------------ Public Network Setup ------------------ #
resource "outscale_subnet" "subnet_pub" {
    # subregion_name = "${var.region}a"
    cidr_block     = "10.1.0.0/24"
    # ip_range       = "10.1.0.0/24"
    vpc_id         = "${outscale_net.demo_net.id}"
    # net_id         = "${outscale_net.demo_net.id}"
}

resource "outscale_security_group" "security_group_pub" {
    description         = "public security group"
    security_group_name = "sg_pub"
    net_id              = "${outscale_net.demo_net.id}"
}

resource "outscale_internet_service" "demo_internet_service" {
}

resource "outscale_internet_service_link" "demo_internet_service_link" {
    internet_service_id = "${outscale_internet_service.demo_internet_service.internet_service_id}" 
    net_id              = "${outscale_net.demo_net.net_id}"
}

resource "outscale_route_table" "rt_pub" {
    vpc_id = "${outscale_net.demo_net.net_id}"
    # net_id = "${outscale_net.demo_net.net_id}"
}

resource "outscale_route_table_link" "rt_pub_link" {
    subnet_id      = "${outscale_subnet.subnet_pub.subnet_id}"
    route_table_id = "${outscale_route_table.rt_pub.id}"
}

resource "outscale_route" "route_internet_pub" {
    destination_cidr_block = "0.0.0.0/0"
    # destination_ip_range = "0.0.0.0/0"
    gateway_id           = "${outscale_internet_service.demo_internet_service.internet_service_id}"
    route_table_id       = "${outscale_route_table.rt_pub.route_table_id}"
}

# ------------------ Private Network Setup ------------------ #
resource "outscale_subnet" "subnet_priv" {
    # subregion_name = "${var.region}b"
    cidr_block     = "10.2.0.0/24"
    # ip_range       = "10.2.0.0/24"
    vpc_id         = "${outscale_net.demo_net.net_id}"
    # net_id         = "${outscale_net.demo_net.net_id}"
}

resource "outscale_security_group" "security_group_priv" {
    description         = "private security group"
    security_group_name = "sg_priv"
    net_id              = "${outscale_net.demo_net.net_id}"
}

resource "outscale_route_table" "rt_priv" {
    vpc_id = "${outscale_net.demo_net.net_id}"
    # net_id = "${outscale_net.demo_net.net_id}"
}

resource "outscale_public_ip" "ip_nat" {
}

resource "outscale_nat_service" "demo_nat_service" {
    depends_on   = ["outscale_route.route_internet_pub"]
    subnet_id    = "${outscale_subnet.subnet_pub.subnet_id}"
    allocation_id = "${outscale_public_ip.ip_nat.id}"
    # public_ip_id = "${outscale_public_ip.ip_nat.id}"
}

resource "outscale_route_table_link" "rt_priv_link" {
    subnet_id      = "${outscale_subnet.subnet_priv.subnet_id}"
    route_table_id = "${outscale_route_table.rt_priv.id}"
}

resource "outscale_route" "route_internet_priv" {
    destination_cidr_block = "0.0.0.0/0"
    # destination_ip_range = "0.0.0.0/0"
    # gateway_id           = "${outscale_nat_service.demo_nat_service.nat_service_id}"
    gateway_id           = "${outscale_nat_service.demo_nat_service.nat_gateway_id}"
    route_table_id       = "${outscale_route_table.rt_priv.route_table_id}"
}

# ------------------ Infra Setup ------------------ #

resource "outscale_vm" "vm_front" {
    image_id                 = "${var.image_id}"
    # vm_type                  = "${var.vm_type}"
    instance_type            = "${var.vm_type}"
    # keypair_name             = "${var.keypair_name}"
    # security_group_ids       = ["${outscale_security_group.security_group_pub.security_group_id}"]
    # placement_subregion_name = "${var.region}a"
    # placement_tenancy        = "default"
    # is_source_dest_checked   = true
    subnet_id                = "${outscale_subnet.subnet_pub.subnet_id}"
}

resource "outscale_public_ip" "ip_vm_front" {
}

resource "outscale_public_ip_link" "ip_pub_link" {
    # vm_id     = "${outscale_vm.vm_front.vm_id}"
    public_ip = "${outscale_public_ip.ip_vm_front.public_ip}"
}

resource "outscale_volume" "vol_vm_pub" {
    # subregion_name = "${var.region}a"
    availability_zone = "${var.region}a"
    size            = 10
    # iops            = 100
    volume_type     = "gp2"
    # snapshot_id     = "${var.snapshot_id}"
}

resource "outscale_volumes_link" "vol_vm_pub_link" {
    device = "/dev/xvdb"
    volume_id   = "${outscale_volume.vol_vm_pub.id}"
    # vm_id       = "${outscale_vm.vm_front.id}"
}

# ------------------ Scalingo ------------------ #

resource "scalingo_app" "test_app" {
  name = "terraform-testapp"
}

resource "scalingo_app" "test_app_fr" {
  name = "terraform-testapp-fr"

  environment {
    MY_DB = "${lookup(scalingo_app.test_app.all_environment, "SCALINGO_MYSQL_URL", "n/c")}"
  }
}

# resource "scalingo_domain" "wwwtestappcom" {
#   common_name = "www.testapp.com"
#   app         = "${scalingo_app.test_app.id}"
# }

resource "scalingo_addon" "test_mysql" {
  provider_id = "scalingo-mysql"
  plan        = "free"
  app         = "${scalingo_app.test_app.id}"
}

resource "scalingo_collaborator" "customer" {
  app   = "${scalingo_app.test_app.id}"
  email = "customer@scalingo.com"
}