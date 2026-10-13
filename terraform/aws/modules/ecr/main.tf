# One repository per image. Tags are immutable, matching the cluster's rule that
# nothing runs from a moving tag; every push is scanned.
resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repositories)
  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Drop untagged layers after a week"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the last ${var.keep_tagged} tagged images"
        selection    = { tagStatus = "tagged", tagPatternList = ["v*"], countType = "imageCountMoreThan", countNumber = var.keep_tagged }
        action       = { type = "expire" }
      },
    ]
  })
}
