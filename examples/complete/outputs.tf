output "id" {
  description = "ID of the created imagebuilder"
  value       = module.imagebuilder.id
}

output "imagebuilder" {
  value     = module.imagebuilder
  sensitive = true
}

#output "aws_imagebuilder_image" {
#  value = module.imagebuilder.aws_imagebuilder_image
#}
#
#output "aws_imagebuilder_amis" {
#  value = module.imagebuilder.aws_imagebuilder_image.output_resources[0].amis
#}

#output "aws_ami_pcluster" {
#  value = module.imagebuilder.aws_ami_pcluster
#}
output "prefix" {
  value = module.imagebuilder.prefix
}
