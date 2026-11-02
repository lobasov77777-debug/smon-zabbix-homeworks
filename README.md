# Домашнее задание к занятию 1 «Disaster recovery и Keepalived» — Колесникова Анастасия

[Условие домашнего задания](https://github.com/netology-code/sflt-homeworks/blob/main/1.md)

## Задание 1. Отслеживание Gi0/0 для первой группы HSRP

Использована исходная схема `hsrp_advanced.pkt` из задания. На обоих маршрутизаторах на интерфейсе Gi0/1 настроено отслеживание Gi0/0 для группы 1.

На схеме устройства называются **Router1** и **Router2**, а их исходные имена в приглашении IOS — `Router0` и `Router1` соответственно.

На Router1 выполнены команды:

```text
enable
configure terminal
interface gigabitethernet0/1
standby 1 track gigabitethernet0/0
standby 1 priority 95
standby 1 preempt
end
write memory
```

На Router2 выполнены команды:

```text
enable
configure terminal
interface gigabitethernet0/1
standby 1 track gigabitethernet0/0
end
write memory
```

В установленном Packet Tracer команда отслеживания интерфейса использует уменьшение приоритета на 10 и не принимает отдельное значение уменьшения. Поэтому для группы 1 на резервном Router1 установлен приоритет 95 и включён `preempt`. У Router2 приоритет равен 100. При обрыве Gi0/0 его приоритет становится 90, и Router1 с приоритетом 95 принимает активную роль. Механизм описан в [документации Cisco по preempt и track](https://www.cisco.com/c/en/us/support/docs/ip/hot-standby-router-protocol-hsrp/13780-6.html).

**Готовая схема:** [01_HSRP_Gi0-0.pkt](01_HSRP_Gi0-0.pkt).

Процесс настройки Router2 и результат команды `show standby gigabitethernet0/1`:

![Настройка отслеживания Gi0/0 на Router2](02_HSRP_Настройка_Router2.png)

Для проверки удалён кабель между Router2 и Switch0. С PC0 (`192.168.0.250`) выполнен `ping 192.168.1.50` на Server0. Первый запуск получил три ответа из четырёх; повторный — четыре ответа из четырёх, потерь 0%. На скриншоте одновременно видны разорванное соединение и результат ping.

![Ping PC0—Server0 при разорванном кабеле Router2—Switch0](03_HSRP_Ping_при_обрыве.png)

На Router2 команда `show standby gigabitethernet0/1` показывает состояние `Standby`, приоритет 90 и активный маршрутизатор `192.168.1.2` с приоритетом 95. Команда `show ip interface brief` подтверждает состояние `down/down` у Gi0/0.

![Переключение первой группы HSRP после обрыва Gi0/0](04_HSRP_Переключение_группы_1.png)

После проверки кабель восстановлен, итоговый файл `.pkt` сохранён с рабочими соединениями и настроенным отслеживанием.

## Задание 2. Keepalived и проверка веб-сервера

Развёрнуты две локальные ВМ Ubuntu 18.04.6 LTS на основе одного образа. На обеих установлены nginx 1.14.0 и Keepalived 1.3.9.

| Параметр | ka-node1 | ka-node2 |
| --- | --- | --- |
| Постоянный адрес | `192.168.56.41/24` | `192.168.56.42/24` |
| Интерфейс локальной сети | `enp0s8` | `enp0s8` |
| Исходное состояние Keepalived | `MASTER` | `BACKUP` |
| Приоритет | `255` | `200` |
| Корневая директория nginx | `/var/www/html` | `/var/www/html` |

Общий виртуальный IP — **`192.168.56.45/24`**, `virtual_router_id` — **15**. Конфигурации подготовлены на основе [примера из лекции](https://github.com/netology-code/sflt-homeworks/blob/main/1/keepalived-simple.conf). В `index.html` каждого узла указано его имя, поэтому HTTP-ответ позволяет определить обслуживающий сервер.

### Bash-скрипт

Файл [05_check_web.sh](05_check_web.sh) установлен на обеих ВМ как `/usr/local/bin/check_web.sh`, принадлежит `root` и имеет права `0755`.

```bash
#!/bin/bash

[[ -f /var/www/html/index.html ]] || exit 1

/usr/bin/timeout 1 /bin/bash -c 'exec 3<>/dev/tcp/127.0.0.1/80' \
    >/dev/null 2>&1 || exit 1

exit 0
```

Скрипт проверяет наличие `index.html` и устанавливает TCP-соединение с портом 80 локального nginx. При любой неудачной проверке он возвращает код 1, при успехе — 0.

### Конфигурации Keepalived

- [06_keepalived_node1.conf](06_keepalived_node1.conf) — конфигурация основного сервера.
- [07_keepalived_node2.conf](07_keepalived_node2.conf) — конфигурация резервного сервера.

Каждый файл установлен на соответствующей ВМ по пути `/etc/keepalived/keepalived.conf`. Проверка подключена через `vrrp_script` и `track_script`:

```text
vrrp_script check_web {
    script "/usr/local/bin/check_web.sh"
    interval 3
    timeout 2
    fall 1
    rise 1
    weight 0
}
```

Интервал запуска — 3 секунды. При ненулевом коде проверки узел переходит в `FAULT` и освобождает виртуальный IP. Для возврата к работе достаточно одной успешной проверки. Обе службы включены в автозагрузку.

### Проверка отказа порта nginx

До отказа VIP принадлежал `ka-node1`, HTTP-запрос по VIP возвращал страницу `ka-node1`. На первом сервере выполнена команда `systemctl stop nginx`. Скрипт завершился с кодом 1, Keepalived перешёл в `FAULT`, адрес исчез с первого сервера. Через семь секунд HTTP-запрос к тому же VIP вернул страницу `ka-node2`.

![Отказ nginx на ka-node1: состояние до отказа и после него](08_Keepalived_Отказ_порта_node1.png)

На втором сервере подтверждены наличие VIP `192.168.56.45/24`, успешная проверка веб-сервера и переход в `MASTER`.

![Резервный сервер принял VIP после отказа порта](09_Keepalived_Приём_VIP_node2.png)

### Проверка отсутствия index.html

После запуска nginx и возврата VIP на первый сервер файл `/var/www/html/index.html` временно переименован в `index.html.hw-backup`. Порт 80 при этом оставался открыт. Проверочный скрипт вернул код 1, первый сервер перешёл в `FAULT`, а запрос по VIP стал обслуживать второй сервер.

![Отсутствует index.html: порт открыт, VIP освобождён](10_Keepalived_Отсутствие_index_node1.png)

На `ka-node2` повторно подтверждены виртуальный IP, состояние `MASTER` и доступность сайта.

![Резервный сервер принял VIP при отсутствии index.html](11_Keepalived_Приём_VIP_без_index_node2.png)

После проверок восстановлены nginx и исходный `index.html`. VIP вернулся на `ka-node1`, сайт снова отдаёт его страницу. По завершении работы обе учебные ВМ выключены.

## Дополнительное задание 3*

Не выполнялось. Выполнены обязательные задания 1 и 2.
