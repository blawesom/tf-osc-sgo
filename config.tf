provider "outscale" {
    access_key_id = "${var.access_key_id}"
    secret_key_id = "${var.secret_key_id}"
    region     = "eu-west-2"
}

provider "scalingo" {
    api_token = "${var.api_token}"
}