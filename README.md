# Домашнее задание 11.03 «ELK» — Колесникова Анастасия

## Задание 1. Elasticsearch

![Ответ Elasticsearch с именем кластера elk-amber-finch-47](01_elasticsearch_cluster.png)

## Задание 2. Kibana

![Ответ на GET /_cluster/health?pretty в Kibana Dev Tools](02_kibana_dev_tools.jpg)

## Задание 3. Logstash

![Журнал доступа Nginx в индексе nginx-logstash](03_nginx_logstash.jpg)

## Задание 4. Filebeat

![Журнал доступа Nginx в индексе nginx-filebeat](04_nginx_filebeat.jpg)

## Задание 5*. Доставка данных

Отправляется журнал HTTP-сервиса на Python (`http.server`). Сервис записывает обращения в `logs/app/access.jsonl`. Filebeat читает файл и передаёт записи в Logstash. JSON-фильтр Logstash выделяет поля `app.service`, `app.method`, `app.path`, `app.status`, `app.client_ip` и `app.timestamp`. События поступают в индекс `python-app-logstash`.

![Журнал HTTP-сервиса на Python и поля, выделенные Logstash](05_python_filebeat_logstash.jpg)
