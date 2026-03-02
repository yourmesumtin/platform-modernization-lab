# ── SNS Topic for Alerts ─────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.env}-platform-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.env}-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Node CPU"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [[
            "ContainerInsights",
            "node_cpu_utilization",
            "ClusterName",
            var.eks_cluster_name
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS Node Memory"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [[
            "ContainerInsights",
            "node_memory_utilization",
            "ClusterName",
            var.eks_cluster_name
          ]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Pod Restarts"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [[
            "ContainerInsights",
            "pod_number_of_container_restarts",
            "ClusterName",
            var.eks_cluster_name
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [[
            "AWS/RDS",
            "CPUUtilization",
            "DBInstanceIdentifier",
            var.db_instance_identifier
          ]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS Free Storage"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [[
            "AWS/RDS",
            "FreeStorageSpace",
            "DBInstanceIdentifier",
            var.db_instance_identifier
          ]]
        }
      }
    ]
  })
}