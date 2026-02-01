create view viewuser as
select u.id, u.name, u.username, u.email, r.name as role
from model_has_roles  mr
         inner join roles r on mr.role_id = r.id
         inner join users u on mr.model_id =  u.id;



create definer = siseclustermysql@`%` view viewuser as
select `siseacad`.`users`.`id`       AS `id`,
       `siseacad`.`users`.`name`     AS `name`,
       `siseacad`.`users`.`email`    AS `email`,
       `siseacad`.`users`.`username` AS `username`,
       `r2`.`name`                   AS `role`
from (((`siseacad`.`users`
    join `siseacad`.`model_has_roles` `r` on ((`r`.`model_id` = `siseacad`.`users`.`id`)))
    join `siseacad`.`roles` `r2` on ((`r`.`role_id` = `r2`.`id`)))
         join `siseacad`.`sedes` `s` on (`siseacad`.`users`.`id`));



drop view sede_users;

create definer = siseclustermysql@`%` view sede_users as
select `u`.`id`                        AS `id_users`,
       `siseacad`.`seg_sedes_1`.`id`   AS `id_seg_sedes_1`,
       `siseacad`.`sedes`.`desc_larga` AS `desc_larga`,
       `siseacad`.`sedes`.`id` AS `id_sede`
from ((`siseacad`.`seg_sedes_1` join `siseacad`.`sedes` on ((`siseacad`.`seg_sedes_1`.`id_sede` = `siseacad`.`sedes`.`id`)))
         join `siseacad`.`users` `u` on ((`siseacad`.`seg_sedes_1`.`id_users` = `u`.`id`)));
#version en produccion
create definer = sisezend@`%` view siseacad.viewuser as
select `u`.`id`       AS `id`,
       `u`.`name`     AS `name`,
       `u`.`username` AS `username`,
       `u`.`email`    AS `email`,
       `r`.`name`     AS `role`
from ((`siseacad`.`model_has_roles` `mr` join `siseacad`.`roles` `r` on ((`mr`.`role_id` = `r`.`id`)))
         join `siseacad`.`users` `u` on ((`mr`.`model_id` = `u`.`id`)));
