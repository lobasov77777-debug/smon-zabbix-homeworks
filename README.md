# Домашнее задание 13.03 «Защита сети» — Колесникова Анастасия

Стенд состоит из двух Debian-ВМ во внутренней сети VirtualBox. Сканер `192.168.91.31` использует Nmap 7.93 и Hydra 9.4. Защищаемая ВМ `192.168.91.32` использует Suricata 7.0.10 и Fail2Ban 1.0.2. Suricata наблюдает за лабораторным интерфейсом в режиме IDS. [Правила Suricata](network-proof/lab.rules) · [Настройка jail sshd](network-proof/sshd-lab.local)

## Задание 1. Разведка

| Команда | Результат | Файл |
|---|---|---|
| `sudo nmap -n -Pn -sA 192.168.91.32` | Все 1000 проверенных портов `unfiltered`. ACK-проба получила RST и показала, что пакеты доходят. | [Вывод -sA](network-proof/nmap-sA.txt) |
| `sudo nmap -n -Pn -sT 192.168.91.32` | Открыт `22/tcp` (SSH), ещё 999 проверенных портов закрыты. | [Вывод -sT](network-proof/nmap-sT.txt) |
| `sudo nmap -n -Pn -sS 192.168.91.32` | Открыт `22/tcp` (SSH), ещё 999 проверенных портов закрыты. | [Вывод -sS](network-proof/nmap-sS.txt) |
| `sudo nmap -n -Pn -sV 192.168.91.32` | На `22/tcp` определён OpenSSH 9.2p1 Debian 2+deb12u4. | [Вывод -sV](network-proof/nmap-sV.txt) |

**Suricata.** Локальные правила зарегистрировали всплески ACK и SYN от `192.168.91.31`. В `eve.json` зафиксированы `LAB TCP ACK burst` в 10:45:42.629 UTC и `LAB TCP SYN burst` в 10:45:42.902 UTC. Сигнатуры обнаруживают серии пакетов с заданными флагами. По одному событию нельзя однозначно определить конкретную команду Nmap. [События Suricata](network-proof/scan-suricata.jsonl)

**Fail2Ban.** Во время разведки jail `sshd` показывал 0 ошибок аутентификации и 0 блокировок. Nmap проверял порты и версию службы, поэтому оснований для бана по журналу аутентификации не появилось. [Статус jail после разведки](network-proof/scan-fail2ban-status.txt) · [Пустой фрагмент журнала за этот этап](network-proof/scan-fail2ban.log)

## Задание 2. Проверка защиты SSH

Включил jail `sshd` в локальном файле `/etc/fail2ban/jail.d/sec13.local`. Лимит — 3 совпадения фильтра за 60 секунд, блокировка — 120 секунд через nftables. Для теста разрешил парольный метод только для источника `192.168.91.31` на внутреннем адресе цели `192.168.91.32`. Hydra использовала вымышленного пользователя и пять тестовых строк.

```bash
hydra -t 2 -w 5 -L users.txt -P pass.txt 192.168.91.32 ssh
```

[users.txt](network-proof/users.txt) · [pass.txt](network-proof/pass.txt) · [Вывод Hydra](network-proof/hydra.txt) · [Журнал OpenSSH](network-proof/ssh-journal.log)

**Suricata.** Зарегистрированы SSH-соединения к порту 22 и событие `LAB Repeated SSH client banners` в 10:45:49.228 UTC. IDS видит подключения и открытый баннер SSH. Результат проверки пароля берётся из журнала OpenSSH, поскольку обмен после установления шифрования закрыт для сетевого датчика. [События Suricata](network-proof/ssh-suricata.jsonl)

**Fail2Ban.** В журнале есть события `Found` и `Ban 192.168.91.31` в 10:45:50.233 UTC. Статус jail показал пять совпадений фильтра и один заблокированный адрес. В выводе nftables адрес присутствует в наборе блокировки SSH. Hydra сообщила `0 valid password found`. [Журнал Fail2Ban](network-proof/ssh-fail2ban.log) · [Статус jail](network-proof/ssh-fail2ban-status.txt) · [Правила nftables](network-proof/ssh-firewall.txt)
