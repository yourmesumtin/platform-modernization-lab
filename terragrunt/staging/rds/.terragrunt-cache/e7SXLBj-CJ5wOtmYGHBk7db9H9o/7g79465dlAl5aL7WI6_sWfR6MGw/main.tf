# ── Subnet Group ────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.env}-rds-subnet-group"
  })
}

# ── Security Group ───────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.env}-rds-sg"
  description = "Allow PostgreSQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from EKS nodes"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.env}-rds-sg"
  })
}

# ── RDS Instance ─────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = "${var.env}-postgres"
  engine            = "postgres"
  engine_version    = "15.17"
  instance_class    = var.instance_class
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Lab: single AZ to keep costs down
  # Production: set multi_az = true for failover
  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true # set to false in production

  storage_encrypted = true

  tags = merge(var.tags, {
    Name = "${var.env}-postgres"
  })
}