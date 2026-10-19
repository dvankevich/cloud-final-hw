# Лог-група для ECS Fargate
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/vaultwarden"
  retention_in_days = 14 # Зберігати логи 14 днів для економії

  tags = { Name = "vaultwarden-ecs-logs" }
}

resource "aws_sns_topic" "alerts" {
  name = "vaultwarden-cloudwatch-alerts"
}

# Підписка на отримання листів (замініть email на свій)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "dvankevich@gmail.com" 
}

# 1. Завантаження CPU у контейнерах ECS (> 85% протягом 5 хвилин)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "vaultwarden-ecs-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization on Vaultwarden ECS service is above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
}

# 2. Помилки 5xx на Load Balancer (більше 5 помилок за 1 хвилину)
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "vaultwarden-alb-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Target Group is returning 5XX HTTP errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

# 3. Закінчення вільного місця на диску RDS (< 5 ГБ)
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "vaultwarden-rds-low-storage"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB в байтах
  alarm_description   = "RDS Free Storage Space is less than 5 GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Vaultwarden-System-Monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # Виджет 1: ECS CPU та Memory Utilization
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Vaultwarden Utilization (%)"
        }
      },

      # Виджет 2: Кількість активних тасок (TaskCount)
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "TaskCount", "ClusterName", aws_ecs_cluster.main.name, { "color" = "#2ca02c", "stat" = "Average" }]
          ]
          period = 60
          region = var.aws_region
          title  = "ECS Running Task Count"
          view   = "timeSeries"
          stacked = false
          yAxis  = {
            left = {
              min = 0
            }
          }
        }
      },

      # Виджет 3: Запити та Помилки ALB
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Traffic & Errors"
        }
      },

      # Виджет 4: Метрики RDS (CPU & Connections)
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.postgres.identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.postgres.identifier]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Database Metrics"
        }
      }
    ]
  })
}

