resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Масштабування за рівнем завантаження CPU (>70%)
resource "aws_appautoscaling_policy" "cpu" {
  name               = "vaultwarden-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 15.0 # 70.0 - for production
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Масштабування за рівнем завантаження оперативної пам'яті (>80%)
resource "aws_appautoscaling_policy" "memory" {
  name               = "vaultwarden-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# 1. Оновлене правило EventBridge: відстежуємо події дій ECS Сервісу
resource "aws_cloudwatch_event_rule" "autoscaling_events" {
  name        = "vaultwarden-autoscaling-events"
  description = "Capture ECS Service scaling actions"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Service Action"]
    detail = {
      clusterArn = [aws_ecs_cluster.main.arn]
    }
  })
}

# 2. Перенаправлення подій EventBridge у SNS Topic з cloudwatch.tf
resource "aws_cloudwatch_event_target" "autoscaling_sns" {
  rule      = aws_cloudwatch_event_rule.autoscaling_events.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

# 3. Політика доступу: дозволяємо EventBridge надсилати повідомлення в SNS Topic
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid     = "AllowEventBridgeToPublishToSNS"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.alerts.arn]
  }
}

