resource "openstack_compute_instance_v2" "bastion" {
  name        = "${local.prefix}-bastion"
  image_name  = var.openstack_image_name
  flavor_name = var.openstack_flavours.bastion
  key_pair    = openstack_compute_keypair_v2.local_ssh_key.name

  security_groups = concat(
    [openstack_networking_secgroup_v2.nodes.name],
    openstack_networking_secgroup_v2.bastion.name,
  )

  network {
    access_network = true
    name           = data.openstack_networking_network_v2.default_network.name
  }

  connection {
    host        = self.access_ip_v4
    type        = "ssh"
    user        = "centos"
    private_key = file(var.ssh_key_pair.private_key)
  }

  # Provision scripts for remote-execution
  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/home/centos/scripts"
  }

  provisioner "remote-exec" {
    inline = ["chmod -R +x /home/centos/scripts"]
  }
}

locals {
  bastion_ip = openstack_compute_instance_v2.bastion.access_ip_v4
}
