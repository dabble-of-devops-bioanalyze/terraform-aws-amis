data "aws_region" "current" {}
data "aws_partition" "current" {}

################################################
# SSH Key
################################################
locals {
  create_aws_key_pair = var.aws_key_pair_id != "" ? true : false
}

resource "tls_private_key" "global_key" {
  #  count     = var.aws_key_pair_id != "" ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 2048
}


output "tls_private_key" {
  value = tls_private_key.global_key
}

resource "null_resource" "mkdirs" {
  # Removing always triggers from the main module.
  provisioner "local-exec" {
    command = "mkdir -p files/user-data/key-pair"
  }
}

resource "local_sensitive_file" "ssh_private_key_pem" {
  depends_on = [
    null_resource.mkdirs,
  ]
  filename        = "files/user-data/key-pair/id_rsa"
  content         = tls_private_key.global_key.private_key_pem
  file_permission = "0600"
}

resource "local_file" "ssh_public_key_openssh" {
  depends_on = [
    null_resource.mkdirs,
  ]
  filename = "files/user-data/key-pair/id_rsa.pub"
  content  = tls_private_key.global_key.public_key_openssh
}

resource "aws_key_pair" "this" {
  depends_on = [
    null_resource.mkdirs,
  ]
  key_name_prefix = "${module.this.id}-keypair"
  public_key      = tls_private_key.global_key.public_key_openssh
}

output "aws_key_pair" {
  value = aws_key_pair.this
}
output "aws_key_pair_private" {
  value = abspath("files/user-data/key-pair/id_rsa")
}

output "aws_key_pair_public" {
  value = abspath("files/user-data/key-pair/id_rsa.pub")
}

locals {
  aws_key_pair_id = var.aws_key_pair_id != "" ? var.aws_key_pair_id : aws_key_pair.this.key_pair_id
}

################################################
# Security Group
################################################

locals {
  create_aws_security_group = var.aws_security_group_id != "" ? true : false
}

resource "aws_security_group" "ssh" {
  name        = "${module.this.id}-ssh"
  description = "Web Traffic - ${module.this.id}"

  vpc_id = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = module.this.tags
}

output "aws_security_group" {
  value = aws_security_group.ssh
}

locals {
  aws_security_group_id = var.aws_security_group_id != "" ? var.aws_security_group_id : aws_security_group.ssh.id
}

################################################
# AMI
# TODO We should have a build matrix of amis
################################################

# TODO Add in a check to make sure that they versions match the pcluster ami
data "aws_ami" "pcluster" {
  count       = length(var.pcluster_versions)
  most_recent = true
  owners      = ["247102896272"]

  filter {
    name   = "name"
    #    "image_location": "amazon/aws-parallelcluster-3.2.0b1-amzn2-hvm-x86_64-202202031828 2022-02-03T18-31-57.025Z",
    values = ["aws-parallelcluster-${var.pcluster_versions[count.index]}-amzn2-hvm-x86_64*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

output "aws_ami_pcluster" {
  value = data.aws_ami.pcluster
}

data "aws_ami" "amazon_linux_2_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

output "aws_ami_amazon_linux_2" {
  value = data.aws_ami.amazon_linux_2_ami
}

# Local variables used to reduce repetition
locals {
  ami_id        = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2_ami.image_id
  node_username = "ec2-user"
}


module "s3_bucket" {
  source             = "cloudposse/s3-bucket/aws"
  # Cloud Posse recommends pinning every module to a specific version
  # version = "x.x.x"
  acl                = "private"
  enabled            = true
  user_enabled       = true
  versioning_enabled = true
  context            = module.this.context
}


data "aws_iam_policy_document" "image_builder" {
  statement {
    sid     = "ImageBuilderAllow"
    effect  = "Allow"
    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
      "imagebuilder:GetComponent",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ImageBuilderS3List"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ImageBuilderS3Put"
    effect  = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::${module.s3_bucket.bucket_id}/image-builder/*"]
  }

  statement {
    sid     = "ImageBuilderLogStream"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/imagebuilder/*"]
  }

  statement {
    sid     = "ImageBuilderKMS"
    effect  = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:EncryptionContextKeys"

      values = [
        "aws:imagebuilder:arn"
      ]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"

      values = [
        "imagebuilder.amazonaws.com"
      ]
    }
  }
}

output "aws_iam_policy_document_image_builder" {
  value = data.aws_iam_policy_document.image_builder.json
}

resource "aws_iam_role" "imagebuilder" {
  name = "${module.this.id}-imagebuilder-role"
  inline_policy {
    name   = "${module.this.id}-imagebuilder-policy"
    policy = data.aws_iam_policy_document.image_builder.json
  }
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSImageBuilderFullAccess"]
  tags                = module.this.tags
}

output "aws_iam_role_imagebuilder" {
  value = aws_iam_role.imagebuilder
}

resource "aws_iam_instance_profile" "imagebuilder" {
  name = module.this.id
  role = aws_iam_role.imagebuilder.name
  tags = module.this.tags
}

output "aws_iam_instance_profile_imagebuilder" {
  value = aws_iam_instance_profile.imagebuilder
}

################################################
# EC2 Image Builder
# TODO We should have a build matrix of amis
################################################

locals {
  aws_imagebuilder_components = [
    { name : "python-3-linux", version : "1.0.1" },
    { name : "amazon-cloudwatch-agent-linux", version : "1.0.1" },
    { name : "aws-cli-version-2-linux", version : "1.0.3" }
  ]
}

data "aws_imagebuilder_component" "aws_imagebuilder_components" {
  count = length(local.aws_imagebuilder_components)
  arn   = "arn:aws:imagebuilder:${var.region}:aws:component/${local.aws_imagebuilder_components[count.index].name}/${local.aws_imagebuilder_components[count.index].version}"
}

data "local_file" "scientific_stack" {
  filename = "${path.module}/files/image-builder/scipy-bootstrap.yml"
}

locals {
  scientific_stack = yamldecode(data.local_file.scientific_stack.content)
}

resource "aws_imagebuilder_component" "scientific_stack" {
  name     = "scientific-stack"
  platform = "Linux"
  version  = "1.0.0"
  data     = data.local_file.scientific_stack.content
  tags     = module.this.tags
}

output "scientific_stack" {
  value = local.scientific_stack
}


resource "aws_imagebuilder_image_recipe" "this" {
  depends_on = [
    data.aws_ami.amazon_linux_2_ami,
    module.s3_bucket,
    aws_imagebuilder_component.scientific_stack,
  ]

  name = replace(join("-", [
    module.this.id,
    "recipe"
  ]), ".", "")
  parent_image = local.ami_id
  version      = "1.0.0"

  block_device_mapping {
    device_name = "/dev/xvdb"

    ebs {
      delete_on_termination = true
      volume_size           = var.ebs_root_vol_size
      volume_type           = "gp3"
    }
  }

  dynamic "component" {
    for_each = data.aws_imagebuilder_component.aws_imagebuilder_components
    content {
      component_arn = component.value["arn"]
    }
  }
  component {
    component_arn = aws_imagebuilder_component.scientific_stack.arn
  }
  tags = module.this.tags
}


resource "aws_imagebuilder_infrastructure_configuration" "this" {
  depends_on = [
    module.s3_bucket,
    aws_iam_role.imagebuilder,
    aws_key_pair.this,
    aws_security_group.ssh,
  ]
  description           = "BioAnalyze infrastructure configuration for alinux2 base and pcluster v3"
  instance_profile_name = aws_iam_instance_profile.imagebuilder.name
  instance_types        = ["t3a.medium"]
  key_pair              = aws_key_pair.this.id
  name                  = "${module.this.id}-infra-config"
  security_group_ids    = [aws_security_group.ssh.id]

  subnet_id                     = var.subnet_id
  terminate_instance_on_failure = true

  logging {
    s3_logs {
      s3_bucket_name = module.s3_bucket.bucket_id
      s3_key_prefix  = "image-builder"
    }
  }

  tags = module.this.tags
}

resource "aws_imagebuilder_image_pipeline" "this" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  name                             = replace(join("-", [
    module.this.id,
    "imagebuilder-pipeline"
  ]), ".", "")

  status      = "ENABLED"
  description = join(" ", [
    "AMI: ",
    module.this.id,
    "imagebuilder-pipeline"
  ])

  schedule {
    schedule_expression                = "cron(0 8 ? * tue)"
    # This cron expressions states every Tuesday at 8 AM.
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  }

  # Test the image after build
  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 60
  }

  tags = module.this.tags
}

resource "aws_imagebuilder_distribution_configuration" "this" {

  name = replace(join("-", [
    module.this.id,
    "dist-config"
  ]), ".", "")

  distribution {
    ami_distribution_configuration {
      name = replace(join("-", [
        module.this.id,
        "{{ imagebuilder:buildDate }}"
      ]), ".", "")

      launch_permission {
      }
    }
    region = var.region
  }
}

resource "aws_imagebuilder_image" "this" {
  depends_on = [
    data.aws_iam_policy_document.image_builder,
    aws_iam_role.imagebuilder,
    aws_imagebuilder_distribution_configuration.this,
    aws_imagebuilder_image_recipe.this,
    aws_imagebuilder_infrastructure_configuration.this,
  ]
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
}

output "aws_imagebuilder_image" {
  value = aws_imagebuilder_image.this
}

output "install_jupyterhub" {
  value = <<EOF
# In order to install jupyterhub with conda run the following -
source /opt/conda/etc/profile.d/conda.sh
conda install -y -c conda-forge jupyterlab jupyter-rsession-proxy nodejs r-base r-essentials
  EOF
}
