# Домашнее задание 11.04 «Очереди RabbitMQ» — Колесникова Анастасия

## Задание 1. Установка RabbitMQ

![Веб-интерфейс RabbitMQ Management на rmq01](01_rabbitmq_management.jpg)

## Задание 2. Отправка и получение сообщений

![Очередь hello с сообщением после запуска producer.py](02_queue_hello.jpg)

![Сообщение Hello Netology получено через consumer.py](03_consumer_rmq01.png)

## Задание 3. Подготовка HA-кластера

![Два доступных узла RabbitMQ](04_cluster_nodes.jpg)

![Политика ha-all для всех очередей](05_policy_ha_all.jpg)

Вывод `rabbitmqctl cluster_status` с обоих узлов — [rmq01](06_cluster_status_rmq01.txt) и [rmq02](07_cluster_status_rmq02.txt).

![Чтение очереди hello через rabbitmqadmin на rmq01](08_rabbitmqadmin_rmq01.png)

![Чтение очереди hello через rabbitmqadmin на rmq02](09_rabbitmqadmin_rmq02.png)

![Consumer получил сообщение на rmq02 после отключения rmq01](10_consumer_failover.png)

## Задание 4*. Ansible playbook

[Плейбук установки RabbitMQ, сборки кластера и применения политики ha-all](ansible/rabbitmq.yml) · [Инвентарь](ansible/inventory.yml)
