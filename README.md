
#  Дипломная работа по профессии «Системный администратор» Распутин Е.В. SYS-44

Содержание
==========
* [Задача](#Задача)
* [Инфраструктура](#Инфраструктура)
    * [Сайт](#Сайт)
    * [Мониторинг](#Мониторинг)
    * [Логи](#Логи)
    * [Сеть](#Сеть)
    * [Резервное копирование](#Резервное-копирование)
* [Выполнение работы](#Выполнение-работы)

---------

## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/) и отвечать минимальным стандартам безопасности: запрещается выкладывать токен от облака в git. Используйте [инструкцию](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#get-credentials).

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible.  

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Виртуальные машины не должны обладать внешним Ip-адресом, те находится во внутренней сети. Доступ к ВМ по ssh через бастион-сервер. Доступ к web-порту ВМ через балансировщик yandex cloud.

Настройка балансировщика:

1. Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

2. Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

3. Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

4. Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

### Мониторинг
Создайте ВМ, разверните на ней Zabbix. На каждую ВМ установите Zabbix Agent, настройте агенты на отправление метрик в Zabbix. 

Настройте дешборды с отображением метрик, минимальный набор — по принципу USE (Utilization, Saturation, Errors) для CPU, RAM, диски, сеть, http запросов к веб-серверам. Добавьте необходимые tresholds на соответствующие графики.

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

### Сеть
Разверните один VPC. Сервера web, Elasticsearch поместите в приватные подсети. Сервера Zabbix, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh.  Эта вм будет реализовывать концепцию  [bastion host]( https://cloud.yandex.ru/docs/tutorials/routing/bastion) . Синоним "bastion host" - "Jump host". Подключение  ansible к серверам web и Elasticsearch через данный bastion host можно сделать с помощью  [ProxyCommand](https://docs.ansible.com/ansible/latest/network/user_guide/network_debug_troubleshooting.html#network-delegate-to-vs-proxycommand) . Допускается установка и запуск ansible непосредственно на bastion host.(Этот вариант легче в настройке)

Исходящий доступ в интернет для ВМ внутреннего контура через [NAT-шлюз](https://yandex.cloud/ru/docs/vpc/operations/create-nat-gateway).

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.

# Выполнение работы

## Развертывание инфраструктуры
Устанавливаю terraform и ansible: 
![screen](/img/1.png)

Создаю необходимую конфигурацию terraform и плейбуки для ansible. 
Начинаю деплой инфраструктуры. 
![screen](/img/2.png)

Инфраструктура развернута в соответствии с требованиями дипломного проекта: 
![screen](/img/3.png)
Диски:
![screen](/img/4.png)
Расписание снимков:
![screen](/img/5.png)
target group:
![screen](/img/target-group.png)
backend group:
![screen](/img/backend-group.png)
http-роутер:
![screen](/img/http-router.png)
Балансировщик:
![screen](/img/ballancer.png)
Облачные сети:
![screen](/img/cloud-net.png)
Шлюзы:
![screen](/img/gateway-net.png)
Таблицы маршрутизации:
![screen](/img/route-table.png)
Группы безопасности:
![screen](/img/sec-group.png)
Дашборд каталога:
![screen](/img/dashboard1.png)

    Нет внешних IP у приватных ВМ ✅  
    NAT для исходящего трафика ✅  
    ALB с health check ✅  
    Снапшоты настроены ✅  
    Безопасность: ключи, SG, bastion ✅  
    PostgreSQL готов к использованию Zabbix ✅

✅ Все ресурсы созданные через terraform готовы и развернуты.


## Подготвка и установка Ansible-playbooks для конфигурирования необходимых сервисов:

Проверяю плейбуки и версию Ansible на vm-bastion. Установка будет осуществлятся с vm-bastion.
![screen](/img/ansver.png)

Проверяю доступность других машин для установки плейбуков 
![screen](/img/ansping.png)

Установка осуществляется в следующем порядке: 
1. Веб-серверы: Nginx (основа для сайта и логов)
2. Zabbix Server: мониторинговая система
3. Elasticsearch: приёмник логов
4. Kibana: визуализация (требует Elasticsearch)
5. Zabbix Agent: отправка метрик на уже работающий сервер
6. Filebeat: отправка логов в уже работающий Elasticsearch

Установка site-nginx на vm-web1, vm-web2
![screen](/img/nginx.png)
Тестирование сайта curl -v <публичный IP балансера>:80
![screen](/img/curl.png)
Доступ в браузере через адрес балансировщика: http://158.160.204.254/
![screen](/img/site.png)

Установка Zabbix-server на vm-zabbix
![screen](/img/zsplay.png)

Установка Elasticsearsh на vm-elastic
![screen](/img/elasticpb.png)

Установка Kibana на vm-kibana
![screen](/img/kibanapb.png)

Установка Zabbix Agent на все созданные vm
![screen](/img/zagetpb.png)

Установка Filebeat на на vm-web1, vm-web2
![screen](/img/fbpb.png)

✅ Все необходимые сервисы установлены 

## Мониторинг, настройка Zabbix

Проверка работы Zabbix. Перехожу на страницу Zabbix с http://130.193.36.133/zabbix
Логин Admin
Пароль zabbix
![screen](/img/Zabbix1.png)
![screen](/img/Zabbix2.png)
![screen](/img/Zabbix3.png)
Добавляю хосты
![screen](/img/Zabbix4.png)
Настроенный Dashboard
![screen](/img/Zabbix5.png)

Доступ к Zabbix:
Логин: Admin
Пароль: zabbix

✅ Zabbix Server и Zabbix Agentd установлены, настроены, дэшборд создан, доступ предоставлен.

## Логи, настройка Elasticsearch в Kibana

Захожу в Kibana http://51.250.9.153:5601
![screen](/img/Kib1.png)
Создаю Index patterns
![screen](/img/Kib2.png)
Логи отправляются
![screen](/img/Kib3.png)

✅ Elasticsearch, Kibana, Filebeat функционируют. Логи отправляются. Доступ предоставлен. 

## Резервное копирование

![screen](/img/bckp.png)
![screen](/img/bckp1.png)

✅ Резервное копирование настроено. Первый снимок сделан.

 


 










