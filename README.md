# Vaultwarden AWS Deployment Guide (ECS Fargate + RDS PostgreSQL + Terraform)

Цей репозиторій містить кофігурацію Terraform для автоматизованого розгортання захищеного, високодоступного та масштабованого середовища для менеджера паролів **Vaultwarden** у хмарі AWS (регіон `eu-central-1`).

---

## 🛠 Попередні вимоги (Prerequisites)

Перед початком розгортання переконайтеся, що на вашому робочому ПК встановлено та налаштовано наступні інструменти:

1. **AWS CLI** (версії `>= 2.0`) з налаштованим профілем (наприклад, `zd-admin` для регіону `eu-central-1`).
2. **Terraform** (версії `>= 1.5.0`).
3. **Docker Engine** (запущений локальний Docker daemon).
4. **Git**.

### Перевірка авторизації в AWS
```bash
aws sts get-caller-identity --profile zd-admin
```

---

## 🚀 Покрокова інструкція з деплою

### Крок 1: Створення ECR репозиторію та завантаження образу

Щоб уникнути помилки `CannotPullContainerError` під час першого запуску ECS, розгортання виконується покроково: спочатку створюється ECR репозиторій, куди завантажується Docker-образ, після чого розгортається решта інфраструктури.

1. **Ініціалізація Terraform та створення ECR:**
   ```bash
   terraform init
   terraform apply -target=aws_ecr_repository.vaultwarden -auto-approve
   ```

2. **Авторизація в ECR, викачування офіційного образу та його push:**
   ```bash
   # 1. Отримання ID акаунту AWS та визначення змінних
   ACCOUNT_ID=$(aws sts get-caller-identity --profile zd-admin --query Account --output text)
   REGION="eu-central-1"
   ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/vaultwarden-app"

   # 2. Логін у Docker Registry AWS ECR
   aws ecr get-login-password --region ${REGION} --profile zd-admin | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

   # 3. Pull офіційного образу Vaultwarden з Docker Hub
   docker pull vaultwarden/server:latest

   # 4. Тегування та відправка в ECR
   docker tag vaultwarden/server:latest ${ECR_URL}:latest
   docker push ${ECR_URL}:latest
   ```

---

### Крок 2: Повне розгортання інфраструктури через Terraform

Після того, як образ завантажено в ECR, виконуємо розгортання всієї інфраструктури (VPC, RDS, ALB, ECS Service, Auto Scaling, CloudWatch):

```bash
terraform apply -auto-approve
```

Після завершення виконання команди Terraform виведе адреси створених ресурсів:
```bash
Outputs:

alb_dns_name = "vaultwarden-alb-484877630.eu-central-1.elb.amazonaws.com"
rds_endpoint = "vaultwarden-postgres.c...eu-central-1.rds.amazonaws.com:5432"
admin_token  = <sensitive>
```

Щоб переглянути згенерований токен адміністратора Vaultwarden:
```bash
terraform output -raw admin_token
```

---

### Крок 3: Первинне налаштування та перевірка доступності

1. **Підтвердження SNS-підписки:**
   * Відкрийте вказаний у конфігурації e-mail (наприклад, `dvankevich@gmail.com`).
   * Знайдіть лист від AWS SNS з темою *AWS Notification - Subscription Confirmation*.
   * Натисніть на посилання **Confirm subscription** для активації сповіщень.

2. **Перший вхід у веб-інтерфейс Vaultwarden:**
   * Перейдіть у браузері за адресою: `https://<alb_dns_name>` (наприклад, `https://vaultwarden-alb-484877630.eu-central-1.elb.amazonaws.com`).
   * Оскільки використовується самопідписаний TLS-сертифікат, прийміть попередження безпеки браузера (*Advanced -> Proceed to site*).
   * Натисніть **Create Account**, вкажіть свій Email та створіть **Master Password**.

3. **Доступ до адмін-панелі:**
   * Перейдіть за адресою: `https://<alb_dns_name>/admin`.
   * Введіть токен, отриманий командою `terraform output -raw admin_token`.

---

### Крок 4: Перевірка моніторингу та тестування Auto Scaling

1. **Перегляд дашборду:**
   * Відкрийте консоль AWS → **CloudWatch** → **Dashboards** → **Vaultwarden-System-Monitoring**.
   * Переконайтеся у наявності активних графіків:
     * *ECS Vaultwarden Utilization (%)*
     * *ECS Running Task Count*
     * *ALB Traffic & Errors*
     * *RDS Database Metrics*

2. **Запуск стрес-тесту для симуляції навантаження:**
   Запустіть скрипт генерування POST-запитів аутентифікації за допомогою Docker-образу `k6`:
   ```bash
   docker run --rm -i grafana/k6 run - <<EOF
   import http from 'k6/http';

   export const options = {
     insecureSkipTLSVerify: true,
     vus: 100,
     duration: '5m',
   };

   export default function () {
     const url = 'https://<alb_dns_name>/api/accounts/prelogin';
     const payload = JSON.stringify({ email: 'test_' + Math.random() + '@test.com' });
     const params = { headers: { 'Content-Type': 'application/json' } };
     http.post(url, payload, params);
   }
   EOF
   ```

3. **Очікуваний результат:**
   * Графік *CPUUtilization* перетне поріг автоскейлінгу (`15%`).
   * Через 1–2 хвилини графік *ECS Running Task Count* покаже зростання кількості контейнерів з `1` до `2` (або більше).
   * На E-mail надійде лист-сповіщення від EventBridge/SNS про подію масштабування `ECS Service Action`.

---

## 🧹 Видалення ресурсів (Teardown)

Для повного видалення всіх створених ресурсів AWS після завершення тестування виконайте команду:

```bash
terraform destroy -auto-approve
```

> **Примітка:** Завдяки параметру `skip_final_snapshot = true` у конфігурації `rds.tf`, база даних видаляється оперативно та без створення підсумкового снепшота.