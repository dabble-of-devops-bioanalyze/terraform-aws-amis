module "imagebuilder" {
  source = "../.."

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  region    = var.region

  image_recipe_version = "1.0.0"
  context              = module.this.context
}

