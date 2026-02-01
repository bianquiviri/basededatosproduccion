-- siseacad.Cursos_Programados_Periodo_243 source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`Cursos_Programados_Periodo_243` AS
select
    `siseacad`.`cursos_programados`.`id` AS `cursos_id`
from
    `siseacad`.`cursos_programados`
where
    ((`siseacad`.`cursos_programados`.`id_periodo` = 303)
        and (`siseacad`.`cursos_programados`.`estado` = '1')
            and (`siseacad`.`cursos_programados`.`id` = `siseacad`.`cursos_programados`.`id_padre`));


-- siseacad.ViewgetDatosCarreraByEmailAlumno source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`ViewgetDatosCarreraByEmailAlumno` AS
select
    `m`.`id` AS `idAlumno`,
    `u`.`name` AS `alumno`,
    `u`.`email` AS `email`,
    `u3`.`descripcion` AS `escuela`,
    `u2`.`descripcion` AS `carrera`,
    `s`.`desc_larga` AS `sede`
from
    (((((((`siseacad`.`users` `u`
join `siseacad`.`alumnos` `a` on
    ((`a`.`id_user` = `u`.`id`)))
join `siseacad`.`matricula` `m` on
    ((`m`.`id_alumno` = `a`.`id`)))
join `siseacad`.`alumno_sesion_lect` `asl` on
    (((`asl`.`id_matricula` = `m`.`id`)
        and (`asl`.`id_periodo` = `m`.`id_periodo`))))
join `siseacad`.`admisiones` `a2` on
    ((`a2`.`id` = `asl`.`id_admision`)))
join `siseacad`.`unidad` `u2` on
    ((`u2`.`id` = `a2`.`id_unidad`)))
join `siseacad`.`unidad` `u3` on
    ((`u3`.`id` = `u2`.`id_padre`)))
join `siseacad`.`sedes` `s` on
    ((`s`.`id` = `a2`.`id_local`)));


-- siseacad.alumnoporclases source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`alumnoporclases` AS
select
    distinct `asl`.`id_alumno` AS `id_alumno`,
    `cp`.`id_padre` AS `id_padre`,
    `cp`.`id` AS `idclase`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `nombre`,
    `s2`.`desc_larga` AS `sede`,
    `u2`.`descripcion` AS `especialidad`,
    `cl`.`desc_larga` AS `ciclo`,
    `p2`.`desc_larga` AS `perido`,
    `c`.`descripcion` AS `curso`,
    `s2`.`id` AS `idsede`,
    `getHorario`(`cp`.`id_padre`,
    0) AS `horario`
from
    (((((((((((((`siseacad`.`alumno_sesion_lect` `asl`
join `siseacad`.`alumnos` `a2` on
    ((`asl`.`id_alumno` = `a2`.`id`)))
join `siseacad`.`persona` `p` on
    ((`a2`.`id_persona` = `p`.`id`)))
join `siseacad`.`sedes` `s2` on
    ((`asl`.`id_local` = `s2`.`id`)))
join `siseacad`.`unidad` `u2` on
    ((`asl`.`id_unidad` = `u2`.`id`)))
join `siseacad`.`ciclo_lectivo` `cl` on
    ((`asl`.`id_ciclo_lectivo` = `cl`.`id`)))
join `siseacad`.`periodos` `p2` on
    ((`asl`.`id_periodo` = `p2`.`id`)))
join `siseacad`.`matricula` `m2` on
    ((`asl`.`id_matricula` = `m2`.`id`)))
join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_matricula` = `m2`.`id`)))
join `siseacad`.`cursos_programados` `cp` on
    ((`md`.`id_cursoprogramado` = `cp`.`id`)))
join `siseacad`.`mallas_det` `mad` on
    ((`cp`.`id_malla_det` = `mad`.`id`)))
join `siseacad`.`cursos` `c` on
    ((`mad`.`id_curso` = `c`.`id`)))
join `siseacad`.`admisiones` `a3` on
    ((`asl`.`id_admision` = `a3`.`id`)))
join `siseacad`.`tipo_admision` `ta` on
    ((`a3`.`id_tipo_admision` = `ta`.`id`)))
where
    (`asl`.`id_unidad` in (90, 91, 92, 93, 94, 113, 1197, 1198))
order by
    `cp`.`id`;


-- siseacad.carreras_equivalentes source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`carreras_equivalentes` AS
select
    `u`.`descripcion` AS `ca_pa`,
    `u`.`id` AS `idc_pa`,
    `c`.`descripcion` AS `cu_padre`,
    `c`.`id` AS `cu_id_pa`,
    `md`.`id` AS `md_id_pa`,
    `m`.`id` AS `id_malla_pa`,
    `u2`.`descripcion` AS `ca_eq`,
    `u2`.`id` AS `idc_eq`,
    `c2`.`descripcion` AS `cu_eq`,
    `c2`.`id` AS `cu_id_eq`,
    `md2`.`id` AS `md_id_eq`,
    `m2`.`id` AS `id_malla_eq`
from
    ((((((((`siseacad`.`tb_cursos_equivalentes` `tce`
join `siseacad`.`mallas_det` `md` on
    ((`md`.`id` = `tce`.`id_malla_det_p`)))
join `siseacad`.`mallas` `m` on
    ((`m`.`id` = `md`.`id_malla`)))
join `siseacad`.`unidad` `u` on
    ((`u`.`id` = `m`.`id_unidad`)))
join `siseacad`.`cursos` `c` on
    ((`c`.`id` = `md`.`id_curso`)))
join `siseacad`.`mallas_det` `md2` on
    ((`md2`.`id` = `tce`.`id_malla_det_e`)))
join `siseacad`.`mallas` `m2` on
    ((`m2`.`id` = `md2`.`id_malla`)))
join `siseacad`.`unidad` `u2` on
    ((`u2`.`id` = `m2`.`id_unidad`)))
join `siseacad`.`cursos` `c2` on
    ((`c2`.`id` = `md2`.`id_curso`)))
where
    (`tce`.`activo` = 1);


-- siseacad.sede_users source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`sede_users` AS
select
    `u`.`id` AS `id_users`,
    `siseacad`.`seg_sedes_1`.`id` AS `id_seg_sedes_1`,
    `siseacad`.`sedes`.`desc_larga` AS `desc_larga`,
    `siseacad`.`sedes`.`id` AS `id_sede`
from
    ((`siseacad`.`seg_sedes_1`
join `siseacad`.`sedes` on
    ((`siseacad`.`seg_sedes_1`.`id_sede` = `siseacad`.`sedes`.`id`)))
join `siseacad`.`users` `u` on
    ((`siseacad`.`seg_sedes_1`.`id_users` = `u`.`id`)));


-- siseacad.v_admisiones source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`v_admisiones` AS
select
    `d`.`id` AS `idAdmision`,
    `s`.`desc_larga` AS `sede`,
    `a`.`id` AS `id`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `alumno`,
    `u`.`descripcion` AS `unidad`,
    `u`.`id` AS `idUnidad`,
    `d`.`id_tipo_admision` AS `id_tipo_admision`,
    `ta`.`descripcion` AS `tipo_admision`,
    `s`.`id` AS `id_local`,
    `d`.`id_malla` AS `id_malla`,
    `d`.`estado` AS `estado`,
    `me`.`descripcion` AS `estadoMat`
from
    ((((((`siseacad`.`admisiones` `d`
join `siseacad`.`alumnos` `a` on
    ((`d`.`id_alumno` = `a`.`id`)))
join `siseacad`.`persona` `p` on
    ((`a`.`id_persona` = `p`.`id`)))
join `siseacad`.`unidad` `u` on
    ((`d`.`id_unidad` = `u`.`id`)))
join `siseacad`.`sedes` `s` on
    ((`d`.`id_local` = `s`.`id`)))
join `siseacad`.`tipo_admision` `ta` on
    ((`d`.`id_tipo_admision` = `ta`.`id`)))
join `siseacad`.`matricula_est` `me` on
    ((`d`.`id_matricula_est` = `me`.`id`)))
where
    (`d`.`estado` = 1)
order by
    `p`.`paterno`,
    `p`.`materno`,
    `p`.`nombres`;


-- siseacad.v_notas_alumno source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`v_notas_alumno` AS
select
    `a`.`id_alumno` AS `id_alumno`,
    `c`.`id_malla` AS `id_malla`,
    `md`.`id_curso` AS `id_curso`,
    `md`.`id` AS `id_malla_det`,
    `cd`.`nota` AS `nota`,
    `p`.`fec_ini` AS `fec_ini`,
    `md`.`nota_min` AS `nota_min`
from
    (((((`siseacad`.`convalidaciones` `c`
join `siseacad`.`convalidaciones_det` `cd` on
    ((`c`.`id` = `cd`.`id_convalidacion`)))
join `siseacad`.`admisiones` `a` on
    ((`a`.`id` = `c`.`id_admision`)))
join `siseacad`.`mallas` `m` on
    ((`m`.`id` = `c`.`id_malla`)))
join `siseacad`.`mallas_det` `md` on
    (((`md`.`id_malla` = `m`.`id`)
        and (`cd`.`id_malla_det_des` = `md`.`id`))))
join `siseacad`.`periodos` `p` on
    ((`a`.`id_periodo` = `p`.`id`)))
union
select
    `m`.`id_alumno` AS `id_alumno`,
    `md`.`id_malla` AS `id_malla`,
    `md`.`id_curso` AS `id_curso`,
    `md`.`id` AS `id_malla_det`,
    `mad`.`promedio_final` AS `promedio_final`,
    `p`.`fec_ini` AS `fec_ini`,
    `md`.`nota_min` AS `nota_min`
from
    ((((`siseacad`.`matricula` `m`
join `siseacad`.`matricula_det` `mad` on
    ((`m`.`id` = `mad`.`id_matricula`)))
join `siseacad`.`cursos_programados` `cp` on
    (((`mad`.`id_cursoprogramado` = `cp`.`id_padre`)
        and (`cp`.`id_unidad` = `m`.`id_unidad`))))
join `siseacad`.`mallas_det` `md` on
    ((`cp`.`id_malla_det` = `md`.`id`)))
join `siseacad`.`periodos` `p` on
    ((`m`.`id_periodo` = `p`.`id`)));


-- siseacad.v_ultimas_admisiones source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`v_ultimas_admisiones` AS
select
    `s`.`desc_larga` AS `sede`,
    `a`.`id` AS `id`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `alumno`,
    `u`.`descripcion` AS `unidad`,
    `u`.`id` AS `idUnidad`,
    `d`.`id_tipo_admision` AS `id_tipo_admision`,
    `ta`.`descripcion` AS `tipo_admision`,
    `d`.`id_local` AS `id_local`,
    `d`.`id_malla` AS `id_malla`,
    `d`.`id_turno` AS `id_turno`
from
    (((((`siseacad`.`admisiones` `d`
join `siseacad`.`alumnos` `a` on
    ((`d`.`id_alumno` = `a`.`id`)))
join `siseacad`.`persona` `p` on
    ((`a`.`id_persona` = `p`.`id`)))
join `siseacad`.`unidad` `u` on
    ((`d`.`id_unidad` = `u`.`id`)))
join `siseacad`.`sedes` `s` on
    ((`d`.`id_local` = `s`.`id`)))
join `siseacad`.`tipo_admision` `ta` on
    ((`d`.`id_tipo_admision` = `ta`.`id`)))
where
    (`d`.`estado` = 1)
order by
    `p`.`paterno`,
    `p`.`materno`,
    `p`.`nombres`;


-- siseacad.viewUserTmpRole source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`viewUserTmpRole` AS
select
    `u`.`id` AS `id`,
    `u`.`name` AS `name`,
    `u`.`email` AS `email`,
    `u`.`username` AS `username`,
    `tp`.`key` AS `pass`,
    `r`.`name` AS `roleName`
from
    (((`siseacad`.`model_has_roles` `mr`
join `siseacad`.`roles` `r` on
    ((`mr`.`role_id` = `r`.`id`)))
join `siseacad`.`users` `u` on
    ((`mr`.`model_id` = `u`.`id`)))
join `siseacad`.`tmp` `tp` on
    ((`u`.`id` = `tp`.`id`)));


-- siseacad.view_cursos source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`view_cursos` AS
select
    distinct `cp`.`id` AS `id`,
    `cu`.`descripcion` AS `descripcion`,
    concat(`prd`.`paterno`, ' ', `prd`.`materno`, ' ', `prd`.`nombres`) AS `docente`
from
    ((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`mallas_det` `mdt` on
    ((`cp`.`id_malla_det` = `mdt`.`id`)))
join `siseacad`.`cursos` `cu` on
    ((`mdt`.`id_curso` = `cu`.`id`)))
join `siseacad`.`horarios` `ho` on
    ((`cp`.`id` = `ho`.`id_cursoprogramado`)))
join `siseacad`.`docentes` `do` on
    ((`ho`.`id_docente` = `do`.`id`)))
join `siseacad`.`persona` `prd` on
    ((`do`.`id_persona` = `prd`.`id`)))
where
    ((`ho`.`activo` = 1)
        and (`ho`.`estado` = 1));


-- siseacad.view_cursos_polls source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`view_cursos_polls` AS
select
    distinct `cp`.`id` AS `id`,
    `cu`.`descripcion` AS `descripcion`,
    concat(`prd`.`paterno`, ' ', `prd`.`materno`, ' ', `prd`.`nombres`) AS `docente`
from
    ((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`mallas_det` `mdt` on
    ((`cp`.`id_malla_det` = `mdt`.`id`)))
join `siseacad`.`cursos` `cu` on
    ((`mdt`.`id_curso` = `cu`.`id`)))
join `siseacad`.`horarios` `ho` on
    ((`cp`.`id` = `ho`.`id_cursoprogramado`)))
join `siseacad`.`docentes` `do` on
    ((`ho`.`id_docente` = `do`.`id`)))
join `siseacad`.`persona` `prd` on
    ((`do`.`id_persona` = `prd`.`id`)));


-- siseacad.view_polls_cursos_studies source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`view_polls_cursos_studies` AS
select
    distinct `cp`.`id` AS `id`,
    `al`.`id` AS `idalumno`,
    `fn_GetLocal`(`al`.`id`,
    `fn_GetIdCarreraAlumno`(`al`.`id`,
    2)) AS `sede`,
    `fn_GetIdEscuela`(`fn_GetIdCarreraAlumno`(`al`.`id`,
    2)) AS `idEscuela`,
    `fn_GetEscuela`(`fn_GetIdCarreraAlumno`(`al`.`id`,
    2)) AS `Escuela`,
    `fn_GetIdCarreraAlumno`(`al`.`id`,
    2) AS `idCarrera`,
    `fn_GetCarreraAlumno`(`al`.`id`,
    2) AS `carrera`,
    `fn_GetCicloMaximo`(`al`.`id`,
    `fn_GetIdCarreraAlumno`(`al`.`id`,
    2)) AS `ciclo`,
    `fn_GetTurno`(`al`.`id`,
    `fn_GetIdCarreraAlumno`(`al`.`id`,
    2),
    `cp`.`id_periodo`) AS `turno`,
    `us`.`email` AS `email`,
    `us`.`id` AS `users_id`,
    concat(`pe`.`paterno`, ' ', `pe`.`materno`, ' ', `pe`.`nombres`) AS `alumno`
from
    ((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`matricula` `ma` on
    ((`md`.`id_matricula` = `ma`.`id`)))
join `siseacad`.`alumnos` `al` on
    ((`ma`.`id_alumno` = `al`.`id`)))
join `siseacad`.`users` `us` on
    ((`al`.`id_user` = `us`.`id`)))
join `siseacad`.`persona` `pe` on
    ((`al`.`id_persona` = `pe`.`id`)))
join `siseacad`.`horarios` `ho` on
    ((`cp`.`id` = `ho`.`id_cursoprogramado`)));


-- siseacad.view_polls_cursos_studies2 source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`view_polls_cursos_studies2` AS
select
    distinct `cp`.`id` AS `id`,
    `al`.`id` AS `idalumno`,
    `fn_GetTurno`(`al`.`id`,
    `fn_GetIdCarreraAlumno`(`al`.`id`,
    2),
    `cp`.`id_periodo`) AS `turno`
from
    ((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`matricula` `ma` on
    ((`md`.`id_matricula` = `ma`.`id`)))
join `siseacad`.`alumnos` `al` on
    ((`ma`.`id_alumno` = `al`.`id`)))
join `siseacad`.`users` `us` on
    ((`al`.`id_user` = `us`.`id`)))
join `siseacad`.`persona` `pe` on
    ((`al`.`id_persona` = `pe`.`id`)))
join `siseacad`.`horarios` `ho` on
    ((`cp`.`id` = `ho`.`id_cursoprogramado`)));


-- siseacad.view_search_alumno source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`view_search_alumno` AS
select
    `al`.`id` AS `idalumno`,
    `siseacad`.`users`.`name` AS `nombres`,
    `siseacad`.`users`.`email` AS `email`
from
    (`siseacad`.`users`
join `siseacad`.`alumnos` `al` on
    ((`siseacad`.`users`.`id` = `al`.`id_user`)))
order by
    `siseacad`.`users`.`id`;


-- siseacad.viewalumnoporclasescarrera source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`viewalumnoporclasescarrera` AS
select
    distinct `asl`.`id_alumno` AS `id_alumno`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `nombre`,
    `s2`.`desc_larga` AS `sede`,
    `s2`.`id` AS `idsede`,
    `u2`.`descripcion` AS `especialidad`,
    `cl`.`id` AS `idciclo`,
    `cl`.`desc_larga` AS `ciclo`,
    `p2`.`desc_corta` AS `periodo`,
    `p2`.`id` AS `idperiodo`,
    `fn_GetInicioMatriculado`(`m2`.`id_unidad`,
    `m2`.`id`) AS `inicio`,
    `c`.`descripcion` AS `curso`,
    `getHorario`(`cp`.`id_padre`,
    0) AS `horario`,
    `cp`.`id_padre` AS `id_padre`,
    `md`.`id_cursoprogramado` AS `idclase`,
    `doc`.`name` AS `docente`
from
    ((((((((((((((`siseacad`.`alumno_sesion_lect` `asl`
join `siseacad`.`alumnos` `a2` on
    ((`asl`.`id_alumno` = `a2`.`id`)))
join `siseacad`.`persona` `p` on
    ((`a2`.`id_persona` = `p`.`id`)))
join `siseacad`.`sedes` `s2` on
    ((`asl`.`id_local` = `s2`.`id`)))
join `siseacad`.`unidad` `u2` on
    ((`asl`.`id_unidad` = `u2`.`id`)))
join `siseacad`.`ciclo_lectivo` `cl` on
    ((`asl`.`id_ciclo_lectivo` = `cl`.`id`)))
join `siseacad`.`periodos` `p2` on
    ((`asl`.`id_periodo` = `p2`.`id`)))
join `siseacad`.`matricula` `m2` on
    ((`asl`.`id_matricula` = `m2`.`id`)))
join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_matricula` = `m2`.`id`)))
join `siseacad`.`cursos_programados` `cp` on
    ((`md`.`id_cursoprogramado` = `cp`.`id`)))
join `siseacad`.`mallas_det` `mad` on
    ((`cp`.`id_malla_det` = `mad`.`id`)))
join `siseacad`.`cursos` `c` on
    ((`mad`.`id_curso` = `c`.`id`)))
join `siseacad`.`admisiones` `a3` on
    ((`asl`.`id_admision` = `a3`.`id`)))
join `siseacad`.`tipo_admision` `ta` on
    ((`a3`.`id_tipo_admision` = `ta`.`id`)))
join `siseacad`.`viewdocentes_cursos_horarios` `doc` on
    ((`cp`.`id` = `doc`.`id_curso`)))
order by
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`);


-- siseacad.viewdocentes_cursos_horarios source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`viewdocentes_cursos_horarios` AS
select
    `cr`.`desc_corta` AS `desc_corta`,
    `h`.`id_cursoprogramado` AS `id_curso`,
    `u`.`name` AS `name`,
    `h`.`id_docente` AS `id_docente`
from
    (((`siseacad`.`horarios` `h`
join `siseacad`.`cursos` `cr` on
    ((`h`.`id_cursoprogramado` = `cr`.`id`)))
join `siseacad`.`docentes` `doc` on
    ((`h`.`id_docente` = `doc`.`id`)))
join `siseacad`.`users` `u` on
    ((`doc`.`id_user` = `u`.`id`)));


-- siseacad.viewuser source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`viewuser` AS
select
    `u`.`id` AS `id`,
    `u`.`name` AS `name`,
    `u`.`username` AS `username`,
    `u`.`email` AS `email`,
    `r`.`name` AS `role`
from
    ((`siseacad`.`model_has_roles` `mr`
join `siseacad`.`roles` `r` on
    ((`mr`.`role_id` = `r`.`id`)))
join `siseacad`.`users` `u` on
    ((`mr`.`model_id` = `u`.`id`)));


-- siseacad.viewuserturno source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`viewuserturno` AS
select
    distinct `vw`.`id` AS `id`,
    `vw`.`name` AS `name`,
    `vw`.`email` AS `email`,
    `vw`.`role` AS `role`,
    `st`.`turno` AS `turno`,
    `st`.`descripcion` AS `descripcion`
from
    (((`siseacad`.`viewuser` `vw`
join `tickets`.`subcategories_roles_users` `t` on
    ((`t`.`users_id` = `vw`.`id`)))
join `siseacad`.`turno_trabajador` `stt` on
    ((`stt`.`users_id` = `vw`.`id`)))
join `siseacad`.`turno` `st` on
    ((`stt`.`turno_id` = `st`.`id`)));


-- siseacad.vw_En_EnviaAlumnos source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_En_EnviaAlumnos` AS
select
    distinct `us`.`id` AS `users_id`,
    `us`.`email` AS `email`,
    `cp`.`id` AS `id`,
    concat(`pe`.`paterno`, ' ', `pe`.`materno`, ' ', `pe`.`nombres`) AS `alumno`,
    `al`.`id` AS `idalumno`,
    `cu`.`descripcion` AS `descripcion`,
    concat(`prd`.`paterno`, ' ', `prd`.`materno`, ' ', `prd`.`nombres`) AS `docente`,
    `cp`.`id_periodo` AS `id_periodo`,
    `ma`.`id_unidad` AS `idCarrera`
from
    ((((((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`matricula` `ma` on
    ((`md`.`id_matricula` = `ma`.`id`)))
join `siseacad`.`alumnos` `al` on
    ((`ma`.`id_alumno` = `al`.`id`)))
join `siseacad`.`users` `us` on
    ((`al`.`id_user` = `us`.`id`)))
join `siseacad`.`persona` `pe` on
    ((`al`.`id_persona` = `pe`.`id`)))
join `siseacad`.`mallas_det` `mdt` on
    ((`cp`.`id_malla_det` = `mdt`.`id`)))
join `siseacad`.`cursos` `cu` on
    ((`mdt`.`id_curso` = `cu`.`id`)))
join `siseacad`.`horarios` `ho` on
    ((`cp`.`id` = `ho`.`id_cursoprogramado`)))
join `siseacad`.`docentes` `do` on
    ((`ho`.`id_docente` = `do`.`id`)))
join `siseacad`.`persona` `prd` on
    ((`do`.`id_persona` = `prd`.`id`)))
where
    ((`cu`.`id` not in (14, 28, 43, 876, 1342, 1343))
        and (`ho`.`estado` = 1)
            and (`ho`.`activo` = 1)
                and (`do`.`id` <> 556));


-- siseacad.vw_RptAlumnos_xCarrera source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_RptAlumnos_xCarrera` AS
select
    distinct `vm`.`Id_alumno` AS `Id_alumno`,
    `vm`.`Usuario` AS `Usuario`,
    `vm`.`Nombre` AS `Nombre`,
    `vm`.`Est` AS `Est`,
    `vm`.`Sede` AS `Sede`,
    `vm`.`Escuela` AS `Escuela`,
    `vm`.`Carrera` AS `Carrera`,
    `fn_GetCiclo`(`vm`.`Id_alumno`,
    `vm`.`id_periodo`) AS `Ciclo`,
    `fn_GetTurno`(`vm`.`Id_alumno`,
    `vm`.`id_periodo`) AS `Turno`
from
    `siseacad`.`vw_matriculados` `vm`;


-- siseacad.vw_RptAlumnos_xCurso source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_RptAlumnos_xCurso` AS
select
    distinct `vm`.`Id_alumno` AS `Id_alumno`,
    `vm`.`Usuario` AS `Usuario`,
    `vm`.`Nombre` AS `Nombre`,
    `vm`.`Est` AS `Est`,
    `vm`.`Sede` AS `Sede`,
    `vm`.`Escuela` AS `Escuela`,
    `vm`.`Carrera` AS `Carrera`,
    `fn_GetInicioMatriculado`(`vm`.`id_unidad`,
    `vm`.`id_Matricula`) AS `Grupo_Inicio`,
    `vm`.`Curso` AS `Curso`,
    `getHorario`(`vm`.`id_padre`,
    0) AS `Horario`,
    `fn_GetDocente`(`vm`.`id_padre`) AS `Docente`,
    `vm`.`id_padre` AS `id_padre`,
    `vm`.`idclase` AS `idclase`
from
    `siseacad`.`vw_matriculados` `vm`;


-- siseacad.vw_RptClases source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_RptClases` AS
select
    distinct `vw_cursos_programados`.`Escuela` AS `Escuela`,
    `vw_cursos_programados`.`Carrera` AS `Carrera`,
    `vw_cursos_programados`.`Curso` AS `Curso`,
    `vw_cursos_programados`.`id_cp` AS `id_cp`,
    `vw_cursos_programados`.`id_pa` AS `id_pa`,
    `getHorario`(`vw_cursos_programados`.`id_pa`,
    0) AS `Horario`,
    `vw_cursos_programados`.`fec_ini` AS `fec_ini`,
    `vw_cursos_programados`.`fec_fin` AS `fec_fin`,
    `fn_GetDocente`(`vw_cursos_programados`.`id_pa`) AS `Docente`,
    `vw_cursos_programados`.`Cant_Alumnos` AS `Cant_Alumnos`,
    `fn_GetInicio`(`vw_cursos_programados`.`id_unidad`,
    `vw_cursos_programados`.`id_pa`) AS `Grupo_Inicio`
from
    `siseacad`.`vw_cursos_programados`;


-- siseacad.vw_admisiones_unidad_alumno_user source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_admisiones_unidad_alumno_user` AS
select
    `d`.`id` AS `admision_id`,
    `s`.`desc_larga` AS `sede`,
    `s`.`id` AS `sede_id`,
    `a`.`id` AS `alumno_id`,
    `a`.`id_user` AS `user_id`,
    `u`.`descripcion` AS `unidad`,
    `u`.`id` AS `unidad_id`,
    `us`.`email` AS `email_user`
from
    ((((((`siseacad`.`admisiones` `d`
join `siseacad`.`alumnos` `a` on
    ((`d`.`id_alumno` = `a`.`id`)))
join `siseacad`.`unidad` `u` on
    ((`d`.`id_unidad` = `u`.`id`)))
join `siseacad`.`sedes` `s` on
    ((`d`.`id_local` = `s`.`id`)))
join `siseacad`.`tipo_admision` `ta` on
    ((`d`.`id_tipo_admision` = `ta`.`id`)))
join `siseacad`.`matricula_est` `me` on
    ((`d`.`id_matricula_est` = `me`.`id`)))
join `siseacad`.`users` `us` on
    ((`us`.`id` = `a`.`id_user`)))
where
    (`d`.`estado` = 1);


-- siseacad.vw_asistencia_alumnos source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_asistencia_alumnos` AS
select
    `h`.`id_cursoprogramado` AS `id_cp`,
    `h`.`activo` AS `activo`,
    `s`.`fecha` AS `fecha`,
    `aa`.`estado` AS `estado`,
    `al`.`id` AS `id_alumno`,
    concat(`pe`.`paterno`, ' ', `pe`.`materno`, ' ', `pe`.`nombres`) AS `Alumno`,
    `se`.`desc_larga` AS `Sede`,
    `ad`.`estado` AS `estadoAdmi`
from
    (((((((`siseacad`.`sesiones` `s`
join `siseacad`.`horarios` `h` on
    ((`s`.`id_horario` = `h`.`id`)))
left join `siseacad`.`asistencia_alumnos` `aa` on
    ((`s`.`id` = `aa`.`id_sesion`)))
left join `siseacad`.`alumnos` `al` on
    ((`aa`.`id_alumno` = `al`.`id`)))
left join `siseacad`.`persona` `pe` on
    ((`al`.`id_persona` = `pe`.`id`)))
left join `siseacad`.`alumno_sesion_lect` `asl` on
    ((`al`.`id` = `asl`.`id_alumno`)))
left join `siseacad`.`sedes` `se` on
    ((`asl`.`id_local` = `se`.`id`)))
left join `siseacad`.`admisiones` `ad` on
    ((`al`.`id` = `ad`.`id_alumno`)));


-- siseacad.vw_cantidad_alumnos_clase source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_cantidad_alumnos_clase` AS
select
    `a`.`id_local` AS `id_sede`,
    `s`.`desc_larga` AS `sede`,
    `u2`.`id` AS `id`,
    `u2`.`descripcion` AS `escuela`,
    `cp`.`id` AS `id_curso_programado`,
    count(distinct `m`.`id_alumno`) AS `cant_alumnos_sede`
from
    (((((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_cursoprogramado` = `cp`.`id`)))
join `siseacad`.`matricula` `m` on
    ((`m`.`id` = `md`.`id_matricula`)))
join `siseacad`.`alumno_sesion_lect` `asl` on
    ((`asl`.`id_matricula` = `m`.`id`)))
join `siseacad`.`admisiones` `a` on
    ((`a`.`id` = `asl`.`id_admision`)))
join `siseacad`.`sedes` `s` on
    ((`s`.`id` = `a`.`id_local`)))
join `siseacad`.`alumnos` `a2` on
    ((`a2`.`id` = `m`.`id_alumno`)))
join `siseacad`.`persona` `p` on
    ((`p`.`id` = `a2`.`id_persona`)))
join `siseacad`.`unidad` `u` on
    ((`u`.`id` = `asl`.`id_unidad`)))
join `siseacad`.`unidad` `u2` on
    ((`u2`.`id` = `u`.`id_padre`)))
where
    (`md`.`id_matricula_est` = 1)
group by
    `cp`.`id`,
    `a`.`id_local`,
    `u2`.`id`;


-- siseacad.vw_cursos_programados source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_cursos_programados` AS
select
    distinct `cl`.`id` AS `id_cicloLectivo`,
    `pe`.`id` AS `id_periodo`,
    `cl`.`desc_larga` AS `Ciclo_Lectivo`,
    `pe`.`desc_larga` AS `Sesion_Lectiva`,
    `esc`.`id` AS `idEscuela`,
    `esc`.`descripcion` AS `Escuela`,
    `car`.`id` AS `idCarrera`,
    `car`.`descripcion` AS `Carrera`,
    `cu`.`descripcion` AS `Curso`,
    `cp`.`id_unidad` AS `id_unidad`,
    `cp`.`id` AS `id_cp`,
    `cp`.`id_padre` AS `id_pa`,
    date_format(`ho`.`fecha_ini`, '%d/%m/%Y') AS `fec_ini`,
    date_format(`ho`.`fecha_fin`, '%d/%m/%Y') AS `fec_fin`,
    if((`cp`.`estado` = 1),
    'A',
    'I') AS `estado`,
    (
    select
        count(1)
    from
        `siseacad`.`matricula_det`
    where
        ((`siseacad`.`matricula_det`.`id_cursoprogramado` = `cp`.`id`)
            and (`siseacad`.`matricula_det`.`estado` = 1))) AS `Cant_Alumnos`
from
    (((((((`siseacad`.`cursos_programados` `cp`
join `siseacad`.`periodos` `pe` on
    ((`cp`.`id_periodo` = `pe`.`id`)))
join `siseacad`.`ciclo_lectivo` `cl` on
    ((`pe`.`id_ciclo_lectivo` = `cl`.`id`)))
join `siseacad`.`unidad` `car` on
    ((`cp`.`id_unidad` = `car`.`id`)))
join `siseacad`.`unidad` `esc` on
    ((`car`.`id_padre` = `esc`.`id`)))
join `siseacad`.`mallas_det` `md` on
    ((`cp`.`id_malla_det` = `md`.`id`)))
join `siseacad`.`cursos` `cu` on
    ((`md`.`id_curso` = `cu`.`id`)))
left join `siseacad`.`horarios` `ho` on
    ((`cp`.`id_padre` = `ho`.`id_cursoprogramado`)));


-- siseacad.vw_cursos_virtuales source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_cursos_virtuales` AS
select
    `c`.`id` AS `id`,
    `c`.`codigo` AS `codigo`
from
    `siseacad`.`cursos` `c`
where
    ((`c`.`estado` = 1)
        and (`c`.`descripcion` like '%(VIRTUAL)'));


-- siseacad.vw_listacursos_asistencias source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_listacursos_asistencias` AS
select
    count(`m`.`id_alumno`) AS `cant_alumnos`,
    `md`.`id_cursoprogramado` AS `id_cursoprogramado`,
    `u2`.`descripcion` AS `escuela`,
    `u`.`descripcion` AS `carrera`,
    `c`.`descripcion` AS `descripcion`,
    group_concat(`s`.`fecha` order by `s`.`fecha` ASC separator ',') AS `GROUP_CONCAT(s.fecha ORDER BY s.fecha)`,
    `md2`.`ciclo` AS `ciclo`,
    group_concat(`aa`.`estado` order by `s`.`fecha` ASC separator ',') AS `estado`,
    `m`.`id_periodo` AS `id_periodo`,
    `u2`.`id` AS `id_escuela`,
    `u2`.`id` AS `id_carrera`
from
    ((((((((((((`siseacad`.`matricula` `m`
join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_matricula` = `m`.`id`)))
join `siseacad`.`sesiones` `s` on
    ((`s`.`id_curso_programado` = `md`.`id_cursoprogramado`)))
join `siseacad`.`asistencia_alumnos` `aa` on
    (((`aa`.`id_sesion` = `s`.`id`)
        and (`aa`.`id_alumno` = `m`.`id_alumno`))))
join `siseacad`.`cursos_programados` `cp` on
    ((`cp`.`id` = `md`.`id_cursoprogramado`)))
join `siseacad`.`periodos` `p` on
    ((`p`.`id` = `cp`.`id_periodo`)))
join `siseacad`.`ciclo_lectivo` `cl` on
    ((`cl`.`id` = `p`.`id_ciclo_lectivo`)))
join `siseacad`.`mallas_det` `md2` on
    ((`md2`.`id` = `cp`.`id_malla_det`)))
join `siseacad`.`cursos` `c` on
    ((`c`.`id` = `md2`.`id_curso`)))
join `siseacad`.`alumnos` `a` on
    ((`a`.`id` = `m`.`id_alumno`)))
join `siseacad`.`persona` `p2` on
    ((`p2`.`id` = `a`.`id_persona`)))
join `siseacad`.`unidad` `u` on
    ((`u`.`id` = `cp`.`id_unidad`)))
join `siseacad`.`unidad` `u2` on
    ((`u2`.`id` = `u`.`id_padre`)))
group by
    `md`.`id_cursoprogramado`,
    `u2`.`descripcion`,
    `u`.`descripcion`,
    `c`.`descripcion`,
    `md2`.`ciclo`,
    `m`.`id_periodo`;


-- siseacad.vw_matricula_max source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_matricula_max` AS
select
    `md`.`id_matricula` AS `id_matricula`,
    `md`.`id_alumno` AS `id_alumno`,
    `ma`.`id_periodo` AS `id_periodo`,
    max(`md`.`id`) AS `idMax`
from
    (((`siseacad`.`matricula_det` `md`
join `siseacad`.`matricula` `ma` on
    ((`md`.`id_matricula` = `ma`.`id`)))
join `siseacad`.`alumno_sesion_lect` `asl` on
    ((`ma`.`id` = `asl`.`id_matricula`)))
join `siseacad`.`admisiones` `ad` on
    ((`ad`.`id` = `asl`.`id_admision`)))
where
    (`ad`.`estado` = 1)
group by
    `md`.`id_matricula`,
    `md`.`id_alumno`,
    `ma`.`id_periodo`;


-- siseacad.vw_matriculados source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_matriculados` AS
select
    distinct `asl`.`id_alumno` AS `Id_alumno`,
    concat('u', lpad(cast(`asl`.`id_alumno` as char charset utf8mb4), 8, '0')) AS `Usuario`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `Nombre`,
    concat(`p`.`paterno`, ' ', `p`.`materno`) AS `SoloApellidos`,
    `p`.`nombres` AS `SoloNombres`,
    `p`.`nro_documento` AS `dni`,
    `p`.`fecnac` AS `fecnac`,
    `p`.`sexo` AS `sexo`,
    substr(`me`.`descripcion`, 1, 1) AS `Est`,
    `s2`.`desc_larga` AS `Sede`,
    `cl`.`desc_larga` AS `Ciclo_Lectivo`,
    `p2`.`desc_larga` AS `Sesion_Lectiva`,
    `esc`.`descripcion` AS `Escuela`,
    `u2`.`descripcion` AS `Carrera`,
    `c`.`descripcion` AS `Curso`,
    `cp`.`id_padre` AS `id_padre`,
    `md`.`id_cursoprogramado` AS `idclase`,
    `m2`.`id` AS `id_Matricula`,
    `esc`.`id` AS `id_escuela`,
    `m2`.`id_unidad` AS `id_unidad`,
    `s2`.`id` AS `id_sede`,
    `cl`.`id` AS `id_cicloLectivo`,
    `p2`.`id` AS `id_periodo`,
    `us`.`username` AS `UsuReg`,
    `ro`.`name` AS `Perfil`,
    `m2`.`created_at` AS `fecMatricula`,
    `m2`.`estado` AS `EstMatricula`,
    `ma`.`descripcion` AS `NombreMalla`
from
    (((((((((((((((((((`siseacad`.`alumno_sesion_lect` `asl`
join `siseacad`.`alumnos` `a2` on
    ((`asl`.`id_alumno` = `a2`.`id`)))
join `siseacad`.`persona` `p` on
    ((`a2`.`id_persona` = `p`.`id`)))
join `siseacad`.`sedes` `s2` on
    ((`asl`.`id_local` = `s2`.`id`)))
join `siseacad`.`unidad` `u2` on
    ((`asl`.`id_unidad` = `u2`.`id`)))
join `siseacad`.`ciclo_lectivo` `cl` on
    ((`asl`.`id_ciclo_lectivo` = `cl`.`id`)))
join `siseacad`.`periodos` `p2` on
    ((`asl`.`id_periodo` = `p2`.`id`)))
join `siseacad`.`matricula` `m2` on
    ((`asl`.`id_matricula` = `m2`.`id`)))
left join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_matricula` = `m2`.`id`)))
left join `siseacad`.`cursos_programados` `cp` on
    ((`md`.`id_cursoprogramado` = `cp`.`id`)))
left join `siseacad`.`mallas_det` `mad` on
    ((`cp`.`id_malla_det` = `mad`.`id`)))
left join `siseacad`.`mallas` `ma` on
    ((`m2`.`id_unidad` = `ma`.`id_unidad`)))
left join `siseacad`.`cursos` `c` on
    ((`mad`.`id_curso` = `c`.`id`)))
left join `siseacad`.`admisiones` `a3` on
    ((`asl`.`id_admision` = `a3`.`id`)))
left join `siseacad`.`tipo_admision` `ta` on
    ((`a3`.`id_tipo_admision` = `ta`.`id`)))
left join `siseacad`.`unidad` `esc` on
    ((`u2`.`id_padre` = `esc`.`id`)))
left join `siseacad`.`matricula_est` `me` on
    ((`asl`.`id_matricula_est` = `me`.`id`)))
left join `siseacad`.`users` `us` on
    ((`md`.`created_by` = `us`.`id`)))
left join `siseacad`.`model_has_roles` `mhr` on
    ((`us`.`id` = `mhr`.`model_id`)))
left join `siseacad`.`roles` `ro` on
    ((`mhr`.`role_id` = `ro`.`id`)))
where
    (`a3`.`estado` = 1);


-- siseacad.vw_matriculados_usuarios source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_matriculados_usuarios` AS
select
    distinct `ma`.`id_alumno` AS `id_alumno`,
    `ma`.`id_unidad` AS `id_unidad`,
    `ma`.`id_periodo` AS `id_periodo`,
    `us`.`username` AS `username`,
    `ro`.`name` AS `rol`
from
    (((((`siseacad`.`matricula_det` `md`
join `siseacad`.`matricula` `ma` on
    ((`ma`.`id` = `md`.`id_matricula`)))
join `siseacad`.`users` `us` on
    ((`md`.`created_by` = `us`.`id`)))
join `siseacad`.`model_has_roles` `mhr` on
    ((`us`.`id` = `mhr`.`model_id`)))
join `siseacad`.`roles` `ro` on
    ((`mhr`.`role_id` = `ro`.`id`)))
join `siseacad`.`vw_matricula_max` `mm` on
    ((`md`.`id` = `mm`.`idMax`)));


-- siseacad.vw_tar_proceso_calc_4_sede_escuela source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_tar_proceso_calc_4_sede_escuela` AS
select
    `tpc3`.`id` AS `tpc3_id`,
    `tpc3`.`id_periodo_laboral` AS `id_periodo_laboral`,
    `tpc3`.`periodo_lab` AS `periodo_lab`,
    `tpc3`.`id_curso` AS `id_curso`,
    `tpc3`.`curso` AS `curso`,
    `tpc3`.`id_cursos_programado` AS `id_cursos_programado`,
    `tpc3`.`desc_docente` AS `desc_docente`,
    `tpc3`.`id_docente` AS `id_docente`,
    `vcac`.`sede` AS `sede`,
    `vcac`.`id_sede` AS `id_sede`,
    `vcac`.`escuela` AS `escuela`,
    `tpc3`.`cant_alumnos` AS `cant_alumnos_total`,
    `tpc3`.`monto` AS `monto_total`,
    `vcac`.`cant_alumnos_sede` AS `cantidad_alumnos_por_sede`,
    ((`tpc3`.`monto` * `vcac`.`cant_alumnos_sede`) / `tpc3`.`cant_alumnos`) AS `monto_total_sede`
from
    (`siseacad`.`tar_proceso_calculo_3` `tpc3`
join `siseacad`.`vw_cantidad_alumnos_clase` `vcac` on
    ((`vcac`.`id_curso_programado` = `tpc3`.`id_cursos_programado`)));


-- siseacad.vw_tareo_calc_por_curso_docente_pl source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_tareo_calc_por_curso_docente_pl` AS
select
    distinct `tpc`.`id` AS `tpc_id`,
    `tpc`.`id_periodo_laboral` AS `id_periodo_laboral`,
    `tpc`.`id_cursos_programado` AS `id_cursos_programado`,
    `tpc`.`id_docente` AS `id_docente`,
    `md`.`id` AS `matd_id`,
    `md`.`id_alumno` AS `id_alumno`,
    concat(`p`.`paterno`, ' ', `p`.`materno`, ' ', `p`.`nombres`) AS `alumno`
from
    ((((((`siseacad`.`tar_proceso_calculo_3` `tpc`
join `siseacad`.`periodo_laboral` `pl` on
    ((`pl`.`id` = `tpc`.`id_periodo_laboral`)))
join `siseacad`.`cursos_programados` `cp` on
    ((`cp`.`id` = `tpc`.`id_cursos_programado`)))
join `siseacad`.`matricula_det` `md` on
    ((`md`.`id_cursoprogramado` = `cp`.`id`)))
join `siseacad`.`horarios` `h` on
    (((`h`.`id_cursoprogramado` = `md`.`id_cursoprogramado`)
        and (`h`.`id_docente` = `tpc`.`id_docente`))))
join `siseacad`.`alumnos` `a` on
    ((`a`.`id` = `md`.`id_alumno`)))
join `siseacad`.`persona` `p` on
    ((`p`.`id` = `a`.`id_persona`)))
where
    ((`md`.`id_matricula_est` = 1)
        and (`h`.`estado` = 1)
            and (`h`.`activo` = 1));


-- siseacad.vw_tareo_calc_por_curso_id_curso_prog source

CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `siseacad`.`vw_tareo_calc_por_curso_id_curso_prog` AS
select
    `tpc1`.`id_periodo_laboral` AS `id_periodo_laboral`,
    concat(`tpc1`.`anio_lab`, '-', `tpc1`.`mes_lab`) AS `periodo_lab`,
    `u3`.`id` AS `id_programa`,
    `u3`.`descripcion` AS `programa`,
    `c`.`id` AS `id_curso`,
    `c`.`descripcion` AS `curso`,
    `tpc`.`id_cursoprogramado` AS `id_cursos_programado`,
    `tpc`.`id_docente` AS `id_docente`,
    `tpc`.`desc_docente` AS `desc_docente`,
    sum(`tpc`.`cant_horas`) AS `cant_horas`,
    sum(`tpc`.`hrs_efec_pagar`) AS `hrs_efec_pagar`,
    sum(`tpc`.`min_tardanza`) AS `min_tardanza`,
    avg(`tpc`.`tarifa`) AS `tarifa`,
    sum(`tpc`.`monto`) AS `monto`,
    `fn_CantidadAlumnosCursoProgramado`(`tpc1`.`id_periodo_laboral`,
    `tpc`.`id_cursoprogramado`,
    `tpc`.`id_docente`) AS `cant_alumnos`
from
    (((((((`siseacad`.`tar_proceso_calculo_2` `tpc`
join `siseacad`.`tar_proceso_calculo_1` `tpc1` on
    ((`tpc1`.`id` = `tpc`.`id_tar_proceso_calculo_1`)))
join `siseacad`.`cursos_programados` `cp` on
    ((`cp`.`id` = `tpc`.`id_cursoprogramado`)))
join `siseacad`.`mallas_det` `md` on
    ((`md`.`id` = `cp`.`id_malla_det`)))
join `siseacad`.`cursos` `c` on
    ((`c`.`id` = `md`.`id_curso`)))
join `siseacad`.`unidad` `u` on
    ((`u`.`id` = `cp`.`id_unidad`)))
join `siseacad`.`unidad` `u2` on
    ((`u2`.`id` = `u`.`id_padre`)))
join `siseacad`.`unidad` `u3` on
    ((`u3`.`id` = `u2`.`id_padre`)))
group by
    `tpc1`.`id_periodo_laboral`,
    concat(`tpc1`.`anio_lab`, '-', `tpc1`.`mes_lab`),
    `u3`.`id`,
    `u3`.`descripcion`,
    `c`.`id`,
    `tpc`.`id_cursoprogramado`,
    `tpc`.`desc_docente`,
    `tpc`.`id_docente`;