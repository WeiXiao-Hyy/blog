create table test.t1
(
    id     int auto_increment
        primary key,
    name   varchar(10) not null,
    id_nbr varchar(19) null,
    age    int         not null,
    constraint idx_uk_id_nbr
        unique (id_nbr)
) charset = utf8mb4;

create index idx_name
    on test.t1 (name);

insert into t1
values (3, '刘备', '110101193007282815', 93),
       (5, '孙权', '110101194007281016', 93),
       (6, '曹操', '110101191807288714', 95),
       (9, '王朗', '110101190007287516', 123);