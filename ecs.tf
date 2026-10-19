resource "aws_ecs_cluster" "main" {
  name = "vaultwarden-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/vaultwarden"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app" {
  family                   = "vaultwarden-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "vaultwarden"
      image     = "vaultwarden/server:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_user}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
        },
        {
          name  = "WEBSOCKET_ENABLED"
          value = "true"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vaultwarden"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "vaultwarden-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "vaultwarden"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_db_instance.postgres
  ]
}
