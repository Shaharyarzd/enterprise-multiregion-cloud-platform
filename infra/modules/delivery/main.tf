resource "aws_ecr_repository" "careflow" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.repository_force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "careflow" {
  repository = aws_ecr_repository.careflow.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent 20 published images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
