output "vm_internal_ips" {
  description = "Internal IP of the VM in each VPC"
  value = {
    for name, vm in google_compute_instance.vm :
    name => vm.network_interface[0].network_ip
  }
}

output "vpc_names" {
  value = [for v in google_compute_network.vpc : v.name]
}
