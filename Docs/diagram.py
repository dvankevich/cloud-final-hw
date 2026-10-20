# code for https://diagrams.mingrammer.com/playground/
from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import Fargate
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.network import ALB
from diagrams.aws.management import Cloudwatch, AutoScaling
from diagrams.aws.integration import Eventbridge, SimpleNotificationServiceSns
from diagrams.aws.general import User

# Створення горизонтальної діаграми (Left-to-Right)
with Diagram("Vaultwarden Architecture", show=False, filename="vaultwarden_architecture_v2", direction="LR"):
    
    client = User("Clients")

    # Основний блок VPC
    with Cluster("AWS VPC (10.0.0.0/16)"):
        
        with Cluster("Public Subnets"):
            alb = ALB("ALB (HTTPS :443)")

        with Cluster("Private Subnets"):
            with Cluster("ECS Cluster"):
                ecs_tasks = [
                    Fargate("Vaultwarden Task 1"),
                    Fargate("Vaultwarden Task 2")
                ]

        with Cluster("Isolated DB Subnets"):
            db = RDSPostgresqlInstance("RDS Postgres 16")

    # Окремий блок для моніторингу та алертингу
    with Cluster("Monitoring & Alerting"):
        cw = Cloudwatch("CloudWatch Logs")
        autoscaling = AutoScaling("Auto Scaling")
        events = Eventbridge("EventBridge Rule")
        sns = SimpleNotificationServiceSns("SNS Alerts")

    # 1. Основний потік трафіку
    client >> Edge(label="HTTPS", color="darkgreen") >> alb
    alb >> Edge(label="HTTP :80", color="darkgreen") >> ecs_tasks
    ecs_tasks >> Edge(label="Port 5432", color="darkblue") >> db

    # 2. Потік моніторингу та автоскейлінгу (пунктирні лінії)
    ecs_tasks >> Edge(color="firebrick", style="dashed", label="Logs & Metrics") >> cw
    cw >> Edge(color="firebrick", style="dashed") >> autoscaling
    autoscaling >> Edge(color="firebrick", style="dashed", label="Scale Task") >> ecs_tasks
    ecs_tasks >> Edge(color="firebrick", style="dashed", label="Service Action") >> events
    events >> Edge(color="firebrick", style="dashed") >> sns
