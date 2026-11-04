# Домашнее задание 13.01 «Уязвимости и атаки на информационные системы» — Колесникова Анастасия

Сканирование выполнено в отдельной внутренней сети VirtualBox. Сканер Debian получил адрес `192.168.91.31`, учебный образ Metasploitable 2 — `192.168.91.80`. [Исходный образ Metasploitable](https://sourceforge.net/projects/metasploitable/)

## Задание 1. Службы и уязвимости

Сначала проверил все TCP-порты командой `sudo nmap -n -Pn -sS -p- -T4 192.168.91.80`. Затем запустил `nmap -sV` по списку открытых портов. Обнаружено **29 открытых TCP-портов**.

| Порты TCP | Службы |
|---|---|
| 21, 2121 | FTP — vsftpd 2.3.4 и ProFTPD 1.3.1 |
| 22, 23, 512–514 | OpenSSH 4.7p1, Telnet, rexec, rlogin, rsh |
| 25, 53 | Postfix SMTP и ISC BIND 9.4.2 |
| 80, 8180 | Apache HTTP 2.2.8 и Apache Tomcat/Coyote |
| 111, 2049, 34561, 39713, 56591 | RPCbind, NFS, nlockmgr, mountd и RPC status |
| 139, 445 | Samba 3.0.20-Debian по результату SMB-запроса |
| 1099, 43569, 8787 | Java RMI и Ruby DRb |
| 1524 | Nmap определил службу как Metasploitable root shell |
| 3306, 5432 | MySQL 5.0.51a и PostgreSQL 8.3.x |
| 3632, 5900, 6000 | distccd, VNC и X11 |
| 6667, 6697 | UnrealIRCd |

[Сканирование TCP-портов](meta-proof/01_tcp_all.txt) · [Службы и версии](meta-proof/02_service_versions.txt) · [Точная версия Samba](meta-proof/03_samba_version.txt)

**Три уязвимости по обнаруженным службам**

1. **vsftpd 2.3.4, 21/tcp — CVE-2011-2523.** В скомпрометированный архив этой версии добавили бэкдор, который позволяет выполнить команды удалённо. Версию сопоставил с описанием учебного образа. [Exploit-DB № 17491](https://www.exploit-db.com/exploits/17491)
2. **Samba 3.0.20-Debian, 139/445 tcp — CVE-2007-2447.** При использовании уязвимой настройки `username map script` специально сформированное имя может привести к удалённому исполнению команд. Версия подтверждена запросом `smb-os-discovery`. [Exploit-DB № 16320](https://www.exploit-db.com/exploits/16320)
3. **distccd, 3632/tcp — CVE-2004-2687.** Доступный по сети демон распределённой компиляции при небезопасной настройке допускает исполнение команд без аутентификации. Такой демон описан в руководстве именно для Metasploitable 2. [Exploit-DB № 9915](https://www.exploit-db.com/exploits/9915) · [Руководство Rapid7](https://docs.rapid7.com/metasploit/metasploitable-2-exploitability-guide/)

Вывод основан на обнаруженных службах, версиях и документации учебного образа.

## Задание 2. Режимы SYN, FIN, Xmas и UDP

Захваты сделаны через TShark, консольную версию Wireshark. TCP-режимы проверены на портах `21,22,80,9999`, UDP — на `53,69,137,161,9999`.

| Режим | Что отправляет сканер | Ответы в захвате |
|---|---|---|
| SYN, `-sS` | TCP SYN, флаг `0x0002`. | Открытые `21/22/80` вернули SYN+ACK (`0x0012`), после чего сканер отправил RST. Закрытый `9999/tcp` вернул RST+ACK (`0x0014`). |
| FIN, `-sF` | TCP FIN, флаг `0x0001`. | На `21/22/80` ответа не было, поэтому Nmap вывел `open\|filtered`. `9999/tcp` вернул RST+ACK и отмечен как `closed`. |
| Xmas, `-sX` | TCP FIN+PSH+URG, флаги `0x0029`. | Результат такой же, как при FIN. На `21/22/80` ответа не было. `9999/tcp` вернул RST+ACK. |
| UDP, `-sU` | UDP-датаграммы. Для известных служб Nmap может подбирать содержимое пробы. | `53/137 udp` отправили UDP-ответы и отмечены `open`. `161/9999 udp` вернули ICMP Type 3 Code 3 и отмечены `closed`. На `69/udp` ответа не было, итог — `open\|filtered`. |

| Режим | Захват Wireshark | Вывод Nmap | Поля пакетов |
|---|---|---|---|
| SYN | [SYN.pcapng](meta-proof/SYN.pcapng) | [Nmap](meta-proof/SYN.nmap.txt) | [CSV](meta-proof/SYN.packets.csv) |
| FIN | [FIN.pcapng](meta-proof/FIN.pcapng) | [Nmap](meta-proof/FIN.nmap.txt) | [CSV](meta-proof/FIN.packets.csv) |
| Xmas | [Xmas.pcapng](meta-proof/Xmas.pcapng) | [Nmap](meta-proof/Xmas.nmap.txt) | [CSV](meta-proof/Xmas.packets.csv) |
| UDP | [UDP.pcapng](meta-proof/UDP.pcapng) | [Nmap](meta-proof/UDP.nmap.txt) | [CSV](meta-proof/UDP.packets.csv) |

[Nmap — режимы сканирования](https://nmap.org/book/man-port-scanning-techniques.html)
