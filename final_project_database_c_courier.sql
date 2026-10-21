create schema c_courier

set search_path to c_courier
create extension "uuid-ossp"

create table courier(
    id uuid DEFAULT exts.uuid_generate_v4() PRIMARY KEY,
    from_place varchar(330), --откуда 
    where_place varchar(330), --куда 
    _name varchar (330), --название документа 
    account_id uuid references account(id), --id контрагента 
    contact_id uuid references contact(id), --id контакта  
    description text, --описание 
    user_id uuid references _user(id), --id сотрудника отправителя 
    status for_status default 'В очереди',-- статусы 'В очереди', 'Выполняется', 'Выполнено', 'Отменен'. По умолчанию - 'В очереди' 
    created_date date default now()--дата создания заявки, значение по умолчанию now() 
)

create table account(
    id uuid DEFAULT exts.uuid_generate_v4() PRIMARY KEY,
    _name varchar (330) --название контрагента 
)

create table contact(
    id uuid DEFAULT exts.uuid_generate_v4() PRIMARY KEY, 
    last_name varchar(330), --фамилия контакта 
    first_name varchar(330), --имя контакта 
    account_id uuid references account(id) --id контрагента 
)

create table _user(
    id uuid DEFAULT exts.uuid_generate_v4() PRIMARY KEY, 
    last_name varchar(330), --фамилия сотрудника 
    first_name varchar(330), --имя сотрудника 
    dismissed boolean default False --уволен или нет, значение по умолчанию "нет" 
)

create type for_status as enum ('В очереди', 'Выполняется', 'Выполнено', 'Отменен')

create schema exts

--Создание пользователя
create role courier with login password 'NetoSQL2022'

grant connect on database postgres to courier;
grant usage on schema c_courier, information_schema, pg_catalog, exts to courier;
grant select on all tables in schema information_schema, pg_catalog, exts to courier;
grant all privileges on all tables in schema c_courier to courier


--Создание функций проверки
create function for_random_varchar() returns varchar(330) as $$
begin
    return repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1,(random()*33)::integer),(random()*10)::integer)::varchar(330);
end;
$$ language plpgsql


create or replace procedure insert_test_data(value integer) as $$
declare val_acc uuid;
begin
	
    for i in 1..value 
    loop
    insert into account("name")
       values ((select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330));
    end loop;
    
    for i in 1..(value*2)
    loop
    insert into contact(last_name, first_name, account_id)
        values ((select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330), 
                (select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330),
                (select id from account order by random() limit 1));
    end loop;

    for i in 1..value 
    loop
    insert into "user"(last_name, first_name, dismissed)
        values ((select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330), 
                (select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330),
                (SELECT random() < 0.5));
    end loop;

    for i in 1..(value*5) 
    loop
    val_acc := (select acc.id from account acc join contact con on con.account_id = acc.id order by random() limit 1);
	insert into courier(from_place, where_place, "name", account_id, contact_id,  description, user_id, status, created_date)
        values ((select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330),
                (select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330),
                (select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::varchar(330),
                 val_acc,
                (select id from contact where account_id = val_acc order by RANDOM() limit 1),
                (select repeat(substring('абвгдеёжзийклмнопрстуфхцчшщьыъэюя', 1, (floor(random()*33+1))::integer),(floor(random()*10+1))::integer))::text,
                (select id from "user" order by random() limit 1),
                (select value_en from unnest(enum_range(null::for_status)) as value_en order by random() limit 1),
                (select (now() - interval '1 day' * round(random() * 1000))::timestamp));
    end loop;
end;
$$ language plpgsql


CREATE OR replace procedure erase_test_data() as $$
begin
    TRUNCATE TABLE account CASCADE;
    DELETE FROM "user";
end;
$$ language plpgsql

create or replace procedure add_courier(from_place varchar(330), where_place varchar(330), "name" varchar(330), account_id uuid, 
contact_id uuid, description text, user_id uuid) as $$
begin
    insert into courier(from_place, where_place, "name", account_id, contact_id, description, user_id)
        values  (from_place, where_place, "name", account_id, contact_id, description, user_id);
end;
$$ language plpgsql


--функции типа 'get'
create or replace function get_courier() returns table(id uuid, from_place varchar(330), where_place varchar(330), "name" varchar(330), account_id uuid, 
account varchar(330), contact_id uuid, contact varchar(665), description text, user_id uuid, "user" varchar(665), status for_status, created_date date) as $$
begin
    return query (select courier.id, courier.from_place, courier.where_place, courier."name" AS "name", courier.account_id, account."name" as "account", 
    courier.contact_id, concat(contact.last_name, ' ', contact.first_name)::varchar(665) as "contact", courier.description, courier.user_id, concat("user".last_name, ' ', "user".first_name)::varchar(665) as "user", 
    courier.status, courier.created_date
    from courier 
    join account on account.id = courier.account_id
    join contact on contact.id = courier.contact_id
    join "user" on "user".id = courier.user_id
    order by status, created_date desc);
end;
$$ language plpgsql
create or replace procedure add_courier(from_place varchar(330), where_place varchar(330), "name" varchar(330), account_id uuid, 
contact_id uuid, description text, user_id uuid) as $$
begin
    if account_id not in (select id from account) then
        raise exception 'id контрагента отсутствует в перечне контрагентов';
    end if;
    
    if contact_id not in (select id from contact) then
        raise exception 'id контакта отсутствует в перечне контактов';
    end if;
    
    if user_id not in (select id from _user) then
        raise exception 'id сотрудника отсутствует в перечне сотрудников';
    end if;
    insert into courier(from_place, where_place, _name, account_id, contact_id, description, user_id)
        values  (from_place, where_place, _name, account_id, contact_id, description, user_id);
end;
$$ language plpgsql


create or replace function get_courier() returns table(id uuid, from_place varchar(330), where_place varchar(330), "name" varchar(330), account_id uuid, 
account varchar(330), contact_id uuid, contact varchar(330), description text, user_id uuid, "user" varchar(330), status for_status, created_date date) as $$
begin
    return query (select id, from_place, where_place, courier._name AS "name", account_id, account._name as "account", 
    contact_id, concat(contact.last_name, ' ', contact.first_name) as "contact", description, user_id, concat(_user.last_name, ' ', _user.first_name) as "user", 
    status, created_date
    from courier 
    join account on account.id = courier.account_id
    join contact on contact.id = courier.contact_id
    join _user on _user.id = courier.user_id
    order by status, created_date);
end;
$$ language plpgsql


create or replace procedure change_status(status for_status, id uuid) as $$
begin
   update courier
   set status = change_status.status
   where courier.id = change_status.id;
end;
$$ language plpgsql

create or replace function  get_users() returns table("user" varchar(330)) as $$
begin
    return query 
        (select concat(last_name, ' ', first_name) as "user"
        from _user
        where dismissed is False
        order by last_name);
end;
$$ language plpgsql

create or replace function  get_accounts() returns table(account varchar(330)) as $$
begin
    return query 
        (select _name as "account"
        from account
        order by _name);
end;
$$ language plpgsql


create or replace function  get_contacts(account_id uuid) returns table("contact" varchar(330)) as $$
begin
    if account_id is null then
        return query select 'Выберите контрагента'::varchar(330);
    else
        return query 
            (select concat(last_name, ' ', first_name) as "contact"
            from contact
            where contact.id = account_id
            order by last_name);
   end if;    
end;
$$ language plpgsql

--Создание view
create view courier_statistic as
    select acc.id as account_id, --идентификатор контрагента
    acc."name" as account,  --название контрагента
    count(cou.id)::integer as count_courier, --количество заказов на курьера для каждого контрагента
    count(cou.id) FILTER (WHERE cou.status = 'Выполнено')::integer as count_complete, --количество завершенных заказов для каждого контрагента
    count(cou_can.id)::integer AS count_canceled, --количество отмененных заказов для каждого контрагента
    (CASE WHEN count(cou.id) FILTER (WHERE date_trunc('month', created_date) = (date_trunc('month', now()) - INTERVAL '1 month')) = 0 THEN 0 ELSE 
    ((count(cou.id) FILTER (WHERE date_trunc('month', created_date) = date_trunc('month', now()))
    /(count(cou.id) FILTER (WHERE date_trunc('month', created_date) = (date_trunc('month', now()) - INTERVAL '1 month')))*100-100)::numeric(12, 2)) END) AS percent_relative_prev_month, -- процентное изменение количества заказов
    count(DISTINCT cou.where_place)::integer AS count_where_place,  --количество мест доставки для каждого контрагента
    count(DISTINCT cou.contact_id) FILTER (WHERE cou.status = 'Выполняется')::integer AS count_contact,  --количество контактов по контрагенту, которым доставляются документы
    array_agg(cou_can.user_id) AS cansel_user_array --массив с идентификаторами сотрудников, по которым были заказы
    from account acc
    left join courier cou on cou.account_id = acc.id
    left join (select id, account_id, user_id
         from courier
         where  status = 'Отменен') cou_can on cou_can.account_id = acc.id
    group by acc.id, acc."name"