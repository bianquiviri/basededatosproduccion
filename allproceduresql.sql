CREATE DEFINER=`root`@`localhost` PROCEDURE `siseacad`.`crea_acta`(
    IN id_cursoprog INT,
	IN creado_por INT,
    OUT nro_acta INT(11)
)
BEGIN

	SELECT ifnull(max(nro_acta),0) + 1 INTO nro_acta
	FROM actas;

	INSERT INTO actas(id_cursoprogramado, nro_acta, version, estado, fecha_cierre, created_by)
	values(id_cursoprog, nro_acta, 1, 1, NOW(), creado_por);

	INSERT INTO actas_det(id_cursoprogramado, id_alumno, nota, created_by)
    SELECT md.id_cursoprogramado, md.id_alumno, md.promedio_final, creado_por
    FROM matricula_det AS md
    WHERE md.id_cursoprogramado = id_cursoprog and estado = 1;

END;

CREATE DEFINER=`sisedu`@`localhost` PROCEDURE `siseacad`.`debug_msg`(enabled INTEGER, msg VARCHAR(255))
BEGIN
  IF enabled THEN BEGIN
    select concat("** ", msg) AS '** DEBUG:';
  END; END IF;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_CantidadAlumnosCursoProgramado`(xidPeriodoLaboral int, xidCursoPro int, xidDocente int) RETURNS varchar(5) CHARSET latin1
BEGIN

	set @cantidad :=(select  count(DISTINCT md.id_alumno)
	from tar_proceso_calculo_2 tpc2
	inner join tar_proceso_calculo_1 tpc1 on tpc1.id = tpc2.id_tar_proceso_calculo_1
	inner join cursos_programados cp on
	    cp.id = tpc2.id_cursoprogramado
	join matricula_det md on
	    md.id_cursoprogramado = cp.id
	join horarios h on
	    h.id_cursoprogramado = md.id_cursoprogramado
	       and h.id_docente = tpc2.id_docente
	 inner join alumnos as a on a.id = md.id_alumno
	 where
	    md.id_matricula_est = 1
	    and h.activo=1  and tpc1.id_periodo_laboral =xidPeriodoLaboral
	    and tpc2.id_cursoprogramado =xidCursoPro and tpc2.id_docente =xidDocente);

	return @cantidad;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_CursoProgramadoExcedioCapacidad`(xidCursoProgramado int) RETURNS text CHARSET latin1
BEGIN
DECLARE countMats int;
	DECLARE limite int;
DECLARE capacidad varchar(10);
DECLARE permitido  varchar(15);

set countMats = (select count(m.id_alumno) from matricula m
inner join matricula_det md on md.id_matricula = m.id
inner join cursos_programados cp on cp.id = md.id_cursoprogramado
inner join alumnos a on a.id = m.id_alumno
where cp.id_padre = xidCursoProgramado and md.id_matricula_est=1);



set capacidad = (select a.capacidad from cursos_programados cp
inner join horarios h on h.id_cursoprogramado = cp.id
inner join aulas a on a.id = h.id_aula and a.id_local = h.id_local
where cp.id =xidCursoProgramado and cp.usar_capacidad =1 and h.estado =1 and h.activo =1
order by a.capacidad asc limit 1);

IF capacidad is null THEN
	set capacidad = (select mp.valor  from matricula_parametros mp
	where mp.clave ="MAXMAT" and estado =1);
	if capacidad is null then
		set limite = 0;
	else
		set limite = capacidad ;
	end if;
ELSE
	SET limite = capacidad ;
end if;

if limite > 0 then
	if countMats >= limite then
		set permitido = 'nodisponible';
	else
		set permitido = 'disponible';
	end if;
else
	set permitido = 'disponible';
end if;

return permitido ;
end;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_demo`(`xIdCursoProgramado` INT) RETURNS char(5) CHARSET latin1
BEGIN
	DECLARE v_horaIni char(5);

	set v_horaIni = (select distinct hora_ini from horarios where id_cursoprogramado = xIdCursoProgramado);

	return v_horaIni;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetAdmision`(xidAlumno int, xidCarrera int) RETURNS int(11)
BEGIN
	set @estado := (select estado
					from admisiones
					where id_alumno=xidAlumno and id_unidad=xidCarrera
					order by id desc
					limit 1);

	return @estado;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCarreraAlumno`(xidAlumno int, xidPrograma int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @carrera := (select ca.descripcion
						from admisiones ad
						inner join unidad ca on ad.id_unidad = ca.id
						inner join unidad es on ca.id_padre = es.id
						where ad.id_alumno=xidAlumno
						and ad.estado = 1
						and es.id_padre = xidPrograma
						order by ad.id desc
						limit 1);

	return @carrera;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCiclo`(xidalumno int, xidunidad int, xidPeriodo int) RETURNS int(11)
BEGIN
	set @ciclo := (select max(mdt.ciclo)
					from matricula ma
					inner join matricula_det md on md.id_matricula = ma.id
					inner join cursos_programados cp on md.id_cursoprogramado = cp.id
					inner join mallas_det mdt on cp.id_malla_det = mdt.id
					where ma.id_alumno=xidalumno and ma.id_unidad=xidunidad and ma.id_periodo=xidPeriodo);

	return @ciclo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCicloMatLinea`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @ciclo := 0;

	set @contar := (select count(*)
			from periodos pe
			inner join ciclo_lectivo cl on pe.id_ciclo_lectivo=cl.id
			where curdate() between pe.fec_ini_mat_l and pe.fec_fin_mat_l
			and mat_linea = 1
			and cl.id_unidad=2);

	if @contar > 1 then
		set @ciclo := -1;
	else
		set @CicloConvalidado :=
		(
			select max(md.ciclo)
			from convalidaciones co
			inner join admisiones ad on co.id_admision=ad.id
			inner join convalidaciones_det cd on co.id=cd.id_convalidacion
			inner join mallas_det md on cd.id_malla_det_des=md.id
			where ad.id_alumno = xidAlumno and ad.id_unidad = xidUnidad
		);

		set @cicloMatriculado :=
		(
			select max(md2.ciclo) as MaximoCiclo
			from matricula ma
			inner join matricula_det md on ma.id=md.id_matricula
			inner join cursos_programados cp on md.id_cursoprogramado=cp.id
			inner join mallas_det md2 on cp.id_malla_det=md2.id
			inner join periodos pe on cp.id_periodo=pe.id
			where ma.id_alumno = xidAlumno
				and ma.id_unidad = xidUnidad
				and pe.fec_fin <
				(select pe.fec_fin
				from periodos pe
				inner join ciclo_lectivo cl on pe.id_ciclo_lectivo=cl.id
				where curdate() between pe.fec_ini_mat_l and pe.fec_fin_mat_l
				and pe.mat_linea = 1
				and cl.id_unidad=2)
		);


		if @CicloConvalidado is null and @cicloMatriculado is null then
			set @ciclo := 0;
		else
			if @CicloConvalidado is null then
				set @ciclo := @cicloMatriculado;
			else
				if @cicloMatriculado >= @CicloConvalidado then
					set @ciclo := @cicloMatriculado;
				else
					set @ciclo := @CicloConvalidado;
				end if;
			end if;
		end if;
	end if;

	return @ciclo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCicloMatriculado`(xidAlumno int, xidUnidad int, xidPeriodo int) RETURNS int(11)
BEGIN
	set @ciclo := 0;

	set @contar := (select count(*)
					from matricula ma
					inner join matricula_det md on ma.id=md.id_matricula
					where ma.id_periodo=xidPeriodo
					and ma.id_alumno=xidAlumno
					and ma.id_unidad=xidUnidad);

	if @contar > 0 then
		set @ciclo := (select max(mt.ciclo)
				from matricula ma
				inner join matricula_det md on ma.id=md.id_matricula
				inner join cursos_programados cp on md.id_cursoprogramado=cp.id
				inner join mallas_det mt on cp.id_malla_det=mt.id
				where ma.id_periodo=xidPeriodo
				and ma.id_alumno=xidAlumno
				and ma.id_unidad=xidUnidad
				limit 1);
	end if;

	return @ciclo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCicloMaximo`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @ciclo := 0;

	set @CicloConvalidado :=
	(
		select max(ciclo)
		from mallas_det
		where id in
		(
			select distinct id_malla_det_des from convalidaciones_det
			where id_convalidacion in
				(select id from convalidaciones where id_admision in
					(select id from admisiones where id_alumno = xidAlumno and id_unidad=xidUnidad)
				)
		)
	);

	set @cicloMatriculado :=
	(
		select max(ciclo) as MaximoCiclo
		from mallas_det
			where id in (
			select id_malla_det from cursos_programados
			where id in (
				select id_cursoprogramado from matricula_det
				where id_matricula in (select id from matricula where id_alumno=xidAlumno and id_unidad=xidUnidad)
			)
		)
	);


	if @CicloConvalidado is null and @cicloMatriculado is null then
		set @ciclo := 0;
	else
		if @CicloConvalidado is null then
			set @ciclo := @cicloMatriculado;
		else
			if @cicloMatriculado >= @CicloConvalidado then
				set @ciclo := @cicloMatriculado;
			else
				set @ciclo := @CicloConvalidado;
			end if;
		end if;
	end if;

	return @ciclo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCondicionAlumno`(xidAlumno int, xidUnidad int) RETURNS varchar(10) CHARSET latin1
BEGIN
	set @condicion := "-";

	set @idMalla := (select distinct id
							from mallas
							where estado=1
							and id_unidad = xidUnidad
							order by 1 asc
							limit 1);

	set @CantCursosMalla := (select count(*)
							from mallas_det
							where estado=1
							and id_malla = @idMalla);

	set @CantCursosMatriculados := (select count(*)
								from (
									select distinct mdt.id_curso
									from matricula ma
									inner join matricula_det md on ma.id=md.id_matricula
									inner join cursos_programados cp on md.id_cursoprogramado=cp.id
									inner join mallas_det mdt on cp.id_malla_det=mdt.id
									where ma.estado=1
									and md.estado=1
									and ma.id_alumno=xidAlumno
									and ma.id_unidad=xidUnidad
									and md.promedio_final>=13
									) as A);

	set @CantCursosConvalidados := (select count(*)
								from (
									select md.id_curso
									from admisiones ad
									inner join convalidaciones co on ad.id=co.id_admision
									inner join convalidaciones_det cd on co.id=cd.id_convalidacion
									inner join mallas_det md on cd.id_malla_det_des=md.id
									where co.estado=1
									and cd.estado=1
									and ad.id_alumno=xidAlumno
									and ad.id_unidad=xidUnidad
									and cd.nota>=13
									) as A);

	set @TotalCursos := @CantCursosMatriculados + @CantCursosConvalidados;

	if @TotalCursos >= @CantCursosMalla then
		set @condicion := "Egresado";
	elseif @TotalCursos < @CantCursosMalla then
		set @condicion := "Retirado";
	end if;

	return @condicion;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCondicionCenso`(xidAlumno int, xidUnidad int, xidPeriodo1 int, xidPeriodo2 int) RETURNS varchar(50) CHARSET latin1
BEGIN
	set @condicion := (select fn_GetCondicionAlumno(xidAlumno, xidUnidad));
	set @promTotal := -1;

	if (@condicion = 'Retirado') then
		if (select count(1) from alumno_sesion_lect
		where id_alumno=xidAlumno and id_unidad=xidUnidad and id_periodo >= xidPeriodo2) > 0 then

			set @prom1 := (select avg(md.promedio_final)
				from matricula ma
				inner join matricula_det md on ma.id = md.id_matricula
				where ma.id_alumno=xidAlumno
				and (ma.id_periodo=xidPeriodo1 or ma.id_periodo=xidPeriodo2));

			set @prom2 := (select avg(cd.nota)
						from admisiones ad
						inner join convalidaciones co on ad.id = co.id_admision
						inner join convalidaciones_det cd on co.id = cd.id_convalidacion
						where ad.id_alumno=xidAlumno
						and (ad.id_periodo=xidPeriodo1 or ad.id_periodo=xidPeriodo2));

			if @prom1 is not null and @prom2 is not null then
				set @promTotal := round((@prom1 + @prom2)/2,0);
			else
				if @prom1 is not null then
					set @promTotal := @prom1;
				elseif @prom2 is not null then
					set @promTotal := @prom2;
				end if;
			end if;

			if @promTotal > -1 then
				if @promTotal > 12 then
					set @condicion := 'Aprobado';
				else
					set @condicion := 'Desaprobado';
				end if;
			end if;
		end if;
	end if;

	return @condicion;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCursosCant`(xidalumno int, xidUnidad int, xidPeriodo int, xidmatricula_est int) RETURNS int(11)
BEGIN

    IF xidmatricula_est = 1 or xidmatricula_est = 2 or xidmatricula_est = 4 THEN
		set @cursosCant := (select count(md.id)
					from  matricula_det md inner join matricula m on md.id_matricula=m.id
					where md.id_alumno=xidalumno and m.id_unidad=xidUnidad and m.id_periodo=xidPeriodo and md.id_matricula_est=xidmatricula_est);

	else
		set @cursosCant := -1;

    END IF;


	return @cursosCant;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetCursosCantMat`(xidPeriodo int, xidSede int, xidEscuela int, xidCarrera int, xCiclo int, xModulo int) RETURNS int(11)
BEGIN
	set @contar := (
		select count(id_padre)
		from vw_matriculados
		where id_periodo=xidPeriodo
		and id_sede=xidSede
		and id_escuela=xidEscuela
		and id_unidad=xidCarrera
		and fn_GetCicloMaximo(Id_alumno, id_unidad) = xCiclo
		and fn_GetModulo(Id_alumno, id_unidad) = xModulo
		and Perfil='alumno'
		);

	return @contar;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetDocente`(xidCurso_Programado int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @idDocente := (select distinct id_docente from horarios
					where id_cursoprogramado=xidCurso_Programado and estado=1 and activo=1
					limit 1
					);

	set @docente := (select concat(paterno,' ',materno,' ',nombres)
					 from persona
					 where id = (select id_persona from docentes where id=@idDocente));

	return @docente;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetEscuela`(xidCarrera int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @escuela := (select es.descripcion as escuela
					from unidad ca
					inner join unidad es on ca.id_padre=es.id
					where ca.id=xidCarrera limit 1);

	return @escuela;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdCarreraAlumno`(xidAlumno int, xidPrograma int) RETURNS int(11)
BEGIN
	set @idCarrera := (select ad.id_unidad
						from admisiones ad
						inner join unidad ca on ad.id_unidad = ca.id
						inner join unidad es on ca.id_padre = es.id
						where ad.id_alumno=xidAlumno
						and ad.estado = 1
						and es.id_padre = xidPrograma
						order by ad.id desc
						limit 1);

	return @idCarrera;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdEscuela`(xidCarrera int) RETURNS int(11)
BEGIN
	set @idEscuela := (select id_padre from unidad where id=xidCarrera);

	return @idEscuela;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdLocal`(xidAlumno int, xidCarrera int) RETURNS int(11)
BEGIN
	set @idLocal := (select asl.id_local
					from alumno_sesion_lect asl
					where asl.id_alumno=xidAlumno
					and asl.id_unidad=xidCarrera
					order by asl.id desc
					limit 1);

	if @idLocal is null then
		set @idLocal := '-1';
	end if;

	return @idLocal;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdPeriodoMatriculado_VN`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @idPeriodo := (select ma.id_periodo
					from matricula ma
					inner join periodos pe on ma.id_periodo=pe.id
					where ma.id_alumno=xidAlumno
					and ma.id_unidad=xidUnidad
					and ma.estado=1
					order by ma.id_periodo
					limit 1);

	if @idPeriodo is null then
		set @idPeriodo := 0;
	end if;

	return @idPeriodo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdTurno`(xidAlumno int, xidUnidad int, xidPeriodo int) RETURNS int(11)
BEGIN
	set @turno := (	select ghd.id_turno
					from matricula ma
					inner join matricula_det md on md.id_matricula = ma.id
					inner join cursos_programados cp on md.id_cursoprogramado = cp.id
					inner join horarios ho on cp.id = ho.id_cursoprogramado
					inner join grupo_hora_det ghd on ho.id_grupo_hora_det_i = ghd.id
					where ma.id_alumno = xidAlumno and ma.id_unidad=xidUnidad and ma.id_periodo = xidPeriodo
					order by ghd.id desc
					limit 1
				  );

	if @turno is null then
		set @turno := 0;
	end if;

	return @turno;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetIdTurnoActual`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @turno := 0;
	set @idPeriodo := (select max(id_periodo) from alumno_sesion_lect where id_alumno=xidAlumno and id_unidad=xidUnidad);

	if @idPeriodo is not null then
		set @turno := (select fn_GetIdTurno(xidAlumno,xidUnidad,@idPeriodo));
	end if;

	return @turno;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetInicio`(xidUnidad int, xidCursoProg int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @inicio := (select gi.descripcion
					from grupos_inicio gi inner join grupos_inicio_det gid
					on gi.id = gid.id_grupo_inicio
					where gi.id_unidad = xidUnidad
					and gid.id_curso_programado = xidCursoProg
					and gi.estado = 1);

	return @inicio;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetInicioMatriculado`(xidUnidad int, xidMatricula int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @cantCursos := (select count(*) from matricula_det where id_matricula = xidMatricula);

	set @idInicio := (select distinct id_grupo_inicio
					from grupos_inicio_det
					where id_grupo_inicio in (select id from grupos_inicio where id_unidad = xidUnidad)
					and id_curso_programado in (select id_cursoprogramado from matricula_det where id_matricula = xidMatricula)
					group by id_grupo_inicio
					having count(id_grupo_inicio) = @cantCursos);

	set @inicio := (select descripcion from grupos_inicio where id = @idInicio);

	return @inicio;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetLocal`(xidAlumno int, xidCarrera int) RETURNS varchar(50) CHARSET latin1
BEGIN
	set @descLocal := (select s.desc_larga
					from alumno_sesion_lect asl
					inner join sedes s on asl.id_local = s.id
					where asl.id_alumno=xidAlumno
					and asl.id_unidad=xidCarrera
					order by asl.id desc
					limit 1);

	if @descLocal is null then
		set @descLocal := '-';
	end if;

	return @descLocal;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetMatriculado`(xidAlumno int, xidCursoProg int) RETURNS varchar(5) CHARSET latin1
BEGIN
	set @contar := (select count(*)
					from matricula ma
					inner join matricula_det md
					on ma.id = md.id_matricula
					where ma.estado=1 and ma.id_alumno=xidAlumno and md.id_cursoprogramado=xidCursoProg);

	if @contar = 0 then
		set @rpta := 'No';
	else
		set @rpta := 'Si';
	end if;

	return @rpta;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetMatriculadosByClase`(xidCursoProgramado int) RETURNS int(11)
BEGIN
	set @countMats := (select count(m.id_alumno) from matricula m
inner join matricula_det md on md.id_matricula = m.id
inner join cursos_programados cp on cp.id = md.id_cursoprogramado
inner join alumnos a on a.id = m.id_alumno
where cp.id_padre = xidCursoProgramado and md.id_matricula_est=1);
	return @countMats;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetModulo`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @modulo := 1;
	set @ciclo := (select fn_GetCicloMaximo(xidAlumno, xidUnidad));

	if @ciclo is null then
		return null;
	end if;



	set @cantCursosConv :=
	(
		select count(*)
		from
		(
			select id
			from mallas_det
			where id in
			(
				select distinct id_malla_det_des from convalidaciones_det
				where id_convalidacion in
					(select id from convalidaciones where id_admision in
						(select id from admisiones where id_alumno = xidAlumno and id_unidad=xidUnidad)
					)
			)
			and ciclo = @ciclo
			group by id
			having count(id) > 1
		) as CursosConv
	);


	set @cantCursosMat :=
	(
		select count(*)
		from
		(
			select id
			from mallas_det
			where id in
				(
				select distinct id_malla_det from cursos_programados
				where id in
					(select id_cursoprogramado from matricula_det
					where id_matricula in (select id from matricula where id_alumno=xidAlumno and id_unidad=xidUnidad)
					)
				)
			and ciclo = @ciclo
			group by id
			having count(id) > 1
		) as CursosMat
	);

	set @suma := @cantCursosConv + @cantCursosMat;


	if (@suma = 0) then



		set @periodos :=
		(
			select count(*)
			from
			(
				select distinct ad.id_periodo
				from convalidaciones_det cd
				inner join convalidaciones co on cd.id_convalidacion = co.id
				inner join admisiones ad on co.id_admision = ad.id
				where ad.id_alumno=xidAlumno and ad.id_unidad=xidUnidad
				and cd.id_malla_det_des in
				(
					select id
					from mallas_det
					where id in
					(
						select distinct id_malla_det_des from convalidaciones_det
						where id_convalidacion in
							(select id from convalidaciones where id_admision in
								(select id from admisiones where id_alumno=xidAlumno and id_unidad=xidUnidad)
							)
					)
					and ciclo = @ciclo
				)
				UNION
				select distinct ma.id_periodo
				from mallas_det md
				inner join cursos_programados cp on md.id = cp.id_malla_det
				inner join matricula_det mtd on cp.id = mtd.id_cursoprogramado
				inner join matricula ma on mtd.id_matricula = ma.id
				where ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad
				and md.id in
				(
					select id
					from mallas_det
					where id in
					(
						select distinct id_malla_det from cursos_programados
						where id in
							(select id_cursoprogramado from matricula_det
								where id_matricula in (select id from matricula where id_alumno=xidAlumno and id_unidad=xidUnidad)
							)
					)
					and ciclo = @ciclo
				)
			) as Periodos
		);

		if @periodos > 1 then
			set @modulo := 2;
		end if;
	else
		set @modulo := 2;
	end if;

	return @modulo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetModuloMatLinea`(xidAlumno int, xidUnidad int) RETURNS int(11)
BEGIN
	set @modulo := 0;
	set @ciclo := (select fn_GetCicloMatLinea(xidAlumno, xidUnidad));

	if @ciclo is null or @ciclo = 0 then
		return 0;
	end if;



	set @cantCursosConv :=
	(
		select count(*)
		from
		(
			select id
			from mallas_det
			where id in
			(
				select distinct id_malla_det_des from convalidaciones_det
				where id_convalidacion in
					(select id from convalidaciones where id_admision in
						(select id from admisiones where id_alumno = xidAlumno and id_unidad=xidUnidad)
					)
			)
			and ciclo = @ciclo
			group by id
			having count(id) > 1
		) as CursosConv
	);


	set @cantCursosMat :=
	(
		select count(*)
		from
		(
			select md2.id
			from matricula ma
			inner join matricula_det md on ma.id=md.id_matricula
			inner join cursos_programados cp on md.id_cursoprogramado=cp.id
			inner join mallas_det md2 on cp.id_malla_det=md2.id
			inner join periodos pe on cp.id_periodo=pe.id
			and md2.ciclo = @ciclo and ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad
			and pe.fec_fin < (select pe.fec_fin
				from periodos pe
				inner join ciclo_lectivo cl on pe.id_ciclo_lectivo=cl.id
				where curdate() between pe.fec_ini_mat_l and pe.fec_fin_mat_l
				and pe.mat_linea = 1
				and cl.id_unidad=2)
			group by id
			having count(md2.id) > 1

		) as CursosMat
	);

	set @suma := @cantCursosConv + @cantCursosMat;

	if (@suma = 0) then
		set @periodos :=
		(
			select count(*)
			from
			(
				select distinct ad.id_periodo
				from convalidaciones_det cd
				inner join convalidaciones co on cd.id_convalidacion = co.id
				inner join admisiones ad on co.id_admision = ad.id
				where ad.id_alumno=xidAlumno and ad.id_unidad=xidUnidad
				and cd.id_malla_det_des in
				(
					select id
					from mallas_det
					where id in
					(
						select distinct id_malla_det_des from convalidaciones_det
						where id_convalidacion in
							(select id from convalidaciones where id_admision in
								(select id from admisiones where id_alumno=xidAlumno and id_unidad=xidUnidad)
							)
					)
					and ciclo = @ciclo
				)
				UNION
				select distinct ma.id_periodo
				from mallas_det md
				inner join cursos_programados cp on md.id = cp.id_malla_det
				inner join matricula_det mtd on cp.id = mtd.id_cursoprogramado
				inner join matricula ma on mtd.id_matricula = ma.id
				where ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad
				and md.id in
				(
					select md2.id
					from matricula ma
					inner join matricula_det md on ma.id=md.id_matricula
					inner join cursos_programados cp on md.id_cursoprogramado=cp.id
					inner join mallas_det md2 on cp.id_malla_det=md2.id
					inner join periodos pe on cp.id_periodo=pe.id
					and md2.ciclo = @ciclo and ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad
					and pe.fec_fin < (select pe.fec_fin
						from periodos pe
						inner join ciclo_lectivo cl on pe.id_ciclo_lectivo=cl.id
						where curdate() between pe.fec_ini_mat_l and pe.fec_fin_mat_l
						and pe.mat_linea = 1
						and cl.id_unidad=2)

				)
				and md.id not in (
				(
					select md2.id
					from matricula ma
					inner join matricula_det md on ma.id=md.id_matricula
					inner join cursos_programados cp on md.id_cursoprogramado=cp.id
					inner join mallas_det md2 on cp.id_malla_det=md2.id
					inner join periodos pe on cp.id_periodo=pe.id
					and md2.ciclo = @ciclo and ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad
					and pe.fec_fin > (select pe.fec_fin
						from periodos pe
						inner join ciclo_lectivo cl on pe.id_ciclo_lectivo=cl.id
						where curdate() between pe.fec_ini_mat_l and pe.fec_fin_mat_l
						and pe.mat_linea = 1
						and cl.id_unidad=2)

				)
			)
			)as Periodos
		);

		if @periodos = 1 then
			set @modulo := 1;
		elseif @periodos > 1 then
			set @modulo := 2;
		end if;
	else
		set @modulo := 2;
	end if;

	return @modulo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetModuloMatriculado`(xidAlumno int, xidUnidad int, xidPeriodo int) RETURNS int(11)
BEGIN
	set @modulo := 1;
	set @ciclo := (select fn_GetCicloMatriculado(xidAlumno, xidUnidad, xidPeriodo));

	if @ciclo is null then
		return null;
	elseif @ciclo = 0 then
		set @modulo := 0;
	else


		set @cantCursosConv :=
		(
			select count(*)
			from
			(
				select id
				from mallas_det
				where id in
				(
					select distinct id_malla_det_des from convalidaciones_det
					where id_convalidacion in
						(select id from convalidaciones where id_admision in
							(select id from admisiones where id_alumno = xidAlumno and id_unidad=xidUnidad and id_periodo<=xidPeriodo)
						)
				)
				and ciclo = @ciclo
				group by id
				having count(id) > 1
			) as CursosConv
		);


		set @cantCursosMat :=
		(
			select count(*)
			from
			(
				select id
				from mallas_det
				where id in
					(
					select distinct id_malla_det from cursos_programados
					where id in
						(select id_cursoprogramado from matricula_det
						where id_matricula in (select id from matricula where id_alumno=xidAlumno and id_unidad=xidUnidad and id_periodo<=xidPeriodo)
						)
					)
				and ciclo = @ciclo
				group by id
				having count(id) > 1
			) as CursosMat
		);

		set @suma := @cantCursosConv + @cantCursosMat;


		if (@suma = 0) then



			set @periodos :=
			(
				select count(*)
				from
				(
					select distinct ad.id_periodo
					from convalidaciones_det cd
					inner join convalidaciones co on cd.id_convalidacion = co.id
					inner join admisiones ad on co.id_admision = ad.id
					where ad.id_alumno=xidAlumno and ad.id_unidad=xidUnidad and ad.id_periodo<=xidPeriodo
					and cd.id_malla_det_des in
					(
						select id
						from mallas_det
						where id in
						(
							select distinct id_malla_det_des from convalidaciones_det
							where id_convalidacion in
								(select id from convalidaciones where id_admision in
									(select id from admisiones where id_alumno=xidAlumno and id_unidad=xidUnidad and id_periodo<=xidPeriodo)
								)
						)
						and ciclo = @ciclo
					)
					UNION
					select distinct ma.id_periodo
					from mallas_det md
					inner join cursos_programados cp on md.id = cp.id_malla_det
					inner join matricula_det mtd on cp.id = mtd.id_cursoprogramado
					inner join matricula ma on mtd.id_matricula = ma.id
					where ma.id_alumno=xidAlumno and ma.id_unidad=xidUnidad and ma.id_periodo<=xidPeriodo
					and md.id in
					(
						select id
						from mallas_det
						where id in
						(
							select distinct id_malla_det from cursos_programados
							where id in
								(select id_cursoprogramado from matricula_det
									where id_matricula in (select id from matricula where id_alumno=xidAlumno and id_unidad=xidUnidad and id_periodo<=xidPeriodo)
								)
						)
						and ciclo = @ciclo
					)
				) as Periodos
			);

			if @periodos > 1 then
				set @modulo := 2;
			end if;
		else
			set @modulo := 2;
		end if;
	end if;

	return @modulo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetNombreMes`(xMes int) RETURNS varchar(20) CHARSET latin1
BEGIN
	set @NomMes := '';

	if xMes = 1 then
		set @NomMes := 'Enero';
	elseif xMes = 2 then
		set @NomMes := 'Febrero';
	elseif xMes = 3 then
		set @NomMes := 'Marzo';
	elseif xMes = 4 then
		set @NomMes := 'Abril';
	elseif xMes = 5 then
		set @NomMes := 'Mayo';
	elseif xMes = 6 then
		set @NomMes := 'Junio';
	elseif xMes = 7 then
		set @NomMes := 'Julio';
	elseif xMes = 8 then
		set @NomMes := 'Agosto';
	elseif xMes = 9 then
		set @NomMes := 'Septiembre';
	elseif xMes = 10 then
		set @NomMes := 'Octubre';
	elseif xMes = 11 then
		set @NomMes := 'Noviembre';
	else
		set @NomMes := 'Diciembre';
	end if;

	return @NomMes;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetPeriodoMatriculado_VN`(xidAlumno int, xidUnidad int) RETURNS varchar(100) CHARSET latin1
BEGIN
	set @periodo := (select pe.desc_corta
					from matricula ma
					inner join periodos pe on ma.id_periodo=pe.id
					where ma.id_alumno=xidAlumno
					and ma.id_unidad=xidUnidad
					and ma.estado=1
					order by ma.id_periodo
					limit 1);

	if @periodo is null then
		set @periodo := 'No definido';
	end if;

	return @periodo;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetTurno`(xidAlumno int, xidUnidad int, xidPeriodo int) RETURNS varchar(5) CHARSET latin1
BEGIN
	set @turno := (	select ghd.turno
					from matricula ma
					inner join matricula_det md on md.id_matricula = ma.id
					inner join cursos_programados cp on md.id_cursoprogramado = cp.id
					inner join horarios ho on cp.id = ho.id_cursoprogramado
					inner join grupo_hora_det ghd on ho.id_grupo_hora_det_i = ghd.id
					where ma.id_alumno = xidAlumno and ma.id_unidad=xidUnidad and ma.id_periodo = xidPeriodo
					order by ghd.id desc
					limit 1
				  );

	if @turno is null then
		set @turno := '-';
	end if;

	return @turno;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`fn_GetTurnoActual`(xidAlumno int, xidUnidad int) RETURNS varchar(1) CHARSET latin1
BEGIN
	set @turno := 'X';
	set @idPeriodo := (select max(id_periodo) from alumno_sesion_lect where id_alumno=xidAlumno and id_unidad=xidUnidad);

	if @idPeriodo is not null then
		set @turno := (select fn_GetTurno(xidAlumno,xidUnidad,@idPeriodo));
	end if;

	return @turno;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetAsistencia`(`idCursoProgramado` INT, `idAlumno` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_faltas INTEGER DEFAULT 0;
  DECLARE v_estado varchar(2);
  DECLARE v_tardanzas INTEGER DEFAULT 0;
  DECLARE v_sesiones INTEGER DEFAULT 0;
  DECLARE v_asistencia varchar(10);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE asistencia_cursor CURSOR FOR
	select aa.estado
	from sesiones as s
	inner join horarios as h ON s.id_horario = h.id
	inner join diasemana as ds ON h.diasem = ds.id
	left join asistencia_alumnos as aa on s.id = aa.id_sesion and aa.id_alumno = idAlumno
	where h.id_cursoprogramado = idCursoProgramado
	order by s.fecha;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN asistencia_cursor;
	get_asistencia: LOOP
    FETCH asistencia_cursor INTO v_estado;
    IF fin = 1 THEN
       LEAVE get_asistencia;
    END IF;

	IF v_estado = 'F' THEN
       SET v_faltas = v_faltas + 1;
    END IF;
	IF v_estado = 'T' THEN
       SET v_tardanzas = v_tardanzas + 1;
    END IF;
	SET v_sesiones = v_sesiones + 1;

	END LOOP get_asistencia;
  CLOSE asistencia_cursor;

SET v_faltas = v_faltas + FLOOR(v_tardanzas/3);

IF v_sesiones > 0 then
		RETURN CAST(100 - ROUND((v_faltas*100)/v_sesiones,0) AS CHAR);
	end if;
RETURN 0;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetCompartido`(`idCursoProgramado` INT


) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_cprogramados  text default '';
  DECLARE v_cprogramado VARCHAR(100);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE cprogramado_cursor CURSOR FOR
	SELECT CONCAT(u.descripcion, (CASE WHEN h.id = h.id_padre THEN '(P)' ELSE '' END)) as descripcion
	FROM cursos_programados AS h
	INNER JOIN unidad u on h.id_unidad = u.id
	WHERE h.id_padre = idCursoProgramado and h.estado=1
	ORDER BY u.desc_corta;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN cprogramado_cursor;
	get_cprogramado: LOOP
    FETCH cprogramado_cursor INTO v_cprogramado;
    IF fin = 1 THEN
       LEAVE get_cprogramado;
    END IF;

	SET v_cprogramados = CONCAT(v_cprogramados, v_cprogramado, ' / ');

  END LOOP get_cprogramado;
  CLOSE cprogramado_cursor;

RETURN v_cprogramados;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetComponentesByCurso`(`idCurso` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Componentes varchar(500) default '';
  DECLARE v_Componente varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE curso_cursor CURSOR FOR
	SELECT CONCAT(CONVERT(cc.id,CHAR),'*',ctc.descripcion,'*',CONVERT(cc.principal,CHAR),'|')
	FROM cursos_componentes AS cc
	INNER JOIN cursos_tipo_componente ctc on cc.id_tipo_componente = ctc.id
	WHERE cc.id_curso = idCurso
    ORDER BY cc.principal desc, ctc.descripcion
	;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN curso_cursor;
	get_cursos: LOOP
    FETCH curso_cursor INTO v_Componente;
    IF fin = 1 THEN
       LEAVE get_cursos;
    END IF;

	SET v_Componentes = CONCAT(v_Componentes, v_Componente);

  END LOOP get_cursos;
  CLOSE curso_cursor;

RETURN SUBSTR(v_Componentes,1,LENGTH(v_Componentes)-1);
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetDocentes`(`idCursoProgramado` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Docentes varchar(500) default '';
  DECLARE v_Docente varchar(100);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE docentes_cursor CURSOR FOR
SELECT CONCAT(p.paterno, ' ',p.materno,' ',p.nombres, ' ')
FROM horarios AS h
INNER JOIN docentes d on h.id_docente = d.id
INNER JOIN persona p on d.id_persona = p.id
WHERE h.id_cursoprogramado = idCursoProgramado
    and h.estado = 1 and h.activo = 1
GROUP BY p.paterno, p.materno, p.nombres
ORDER BY p.paterno;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN docentes_cursor;
get_docente: LOOP
    FETCH docentes_cursor INTO v_Docente;
    IF fin = 1 THEN
       LEAVE get_docente;
    END IF;

SET v_Docentes = CONCAT(v_Docentes, v_Docente, ', ');

  END LOOP get_docente;
  CLOSE docentes_cursor;

RETURN SUBSTRING(v_Docentes,1,LENGTH(v_Docentes)-2);
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`getHorario`(`idCursoProgramado` INT, `conUbicacion` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Horarios text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE horario_cursor CURSOR FOR
SELECT CASE conUbicacion WHEN 0 THEN CONCAT(ds.dia_corto, ' ',g1.rotulo_hr,'-',g2.rotulo_hr, ' ') WHEN 1 THEN CONCAT(ds.dia_corto, ' ',g1.rotulo_hr,'-',g2.rotulo_hr, ' / ',s.desc_corta,' - ',a.descripcion,'<br/>') ELSE '' END
FROM horarios AS h
INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
LEFT JOIN aulas a on h.id_aula = a.id
LEFT JOIN sedes s on a.id_local = s.id
WHERE h.id_cursoprogramado = idCursoProgramado and h.activo=1 and h.estado=1
ORDER BY ds.id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN horario_cursor;
get_horario: LOOP
    FETCH horario_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;

SET v_Horarios = CONCAT(v_Horarios, v_Horario);

  END LOOP get_horario;
  CLOSE horario_cursor;

RETURN v_Horarios;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetHorarioJson`(`idCursoProgramado` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Horarios text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE horario_cursor CURSOR FOR
	SELECT CONCAT('{"id":"',CONVERT(h.id_cursoprogramado,CHAR),'","ini":"',CONVERT(DATE_ADD(h.fecha_ini, INTERVAL (CASE WHEN DAYOFWEEK(h.fecha_ini) > h.diasem + 1 THEN 7 ELSE 0 END + h.diasem + 1 - DAYOFWEEK(h.fecha_ini)) DAY),CHAR),' ',g1.rotulo_hr,'","fin":"', CONVERT(DATE_ADD(h.fecha_ini, INTERVAL (CASE WHEN DAYOFWEEK(h.fecha_ini) > h.diasem + 1 THEN 7 ELSE 0 END + h.diasem + 1 - DAYOFWEEK(h.fecha_ini)) DAY),CHAR),' ',g2.rotulo_hr,'"}') AS rango
	FROM horarios AS h
	INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
	WHERE h.id_cursoprogramado = idCursoProgramado and h.activo=1
	ORDER BY ds.id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN horario_cursor;
	get_horario: LOOP
    FETCH horario_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;

	SET v_Horarios = CONCAT(v_Horarios, v_Horario, ',');

  END LOOP get_horario;
  CLOSE horario_cursor;

RETURN CONCAT('[',SUBSTRING(v_Horarios,1,LENGTH(v_Horarios)-1),']');
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`getHorarioMatriculaAlumno`(idCursoProgramado INT, conUbicacion INT, idSede INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Horarios text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE horario_cursor CURSOR FOR
SELECT CASE conUbicacion WHEN 0 THEN CONCAT(ds.dia_corto, ' ',g1.rotulo_hr,'-',g2.rotulo_hr, ' ') WHEN 1 THEN CONCAT(ds.dia_corto, ' ',g1.rotulo_hr,'-',g2.rotulo_hr, ' / ',s.desc_corta,' - ',a.descripcion,'<br/>') ELSE '' END
FROM horarios AS h
INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
LEFT JOIN aulas a on h.id_aula = a.id
LEFT JOIN sedes s on a.id_local = s.id



WHERE h.id_cursoprogramado = idCursoProgramado
 and s.id_padre in (idSede ,15)
and h.activo=1 and h.estado=1



ORDER BY ds.id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN horario_cursor;
get_horario: LOOP
    FETCH horario_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;

SET v_Horarios = CONCAT(v_Horarios, v_Horario);

  END LOOP get_horario;
  CLOSE horario_cursor;

RETURN v_Horarios;
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`getLocalGI`(`idCursoProgramado` INT, `conUbicacion` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE Sedes_s text default '';
  DECLARE sede_verificar text default '';
  DECLARE f_sede varchar(500);
  DECLARE fin INTEGER DEFAULT 0;



  DECLARE sede_cursor CURSOR FOR
SELECT CASE conUbicacion WHEN 0 THEN CONCAT(ss.desc_corta) WHEN 1 THEN CONCAT(ss.desc_corta) ELSE '' END
FROM horarios AS h
INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
LEFT JOIN aulas a on h.id_aula = a.id
LEFT JOIN sedes s on a.id_local = s.id
LEFT JOIN sedes ss on ss.id = s.id_padre
WHERE h.id_cursoprogramado = idCursoProgramado and h.activo=1 and h.estado=1
ORDER BY ds.id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN sede_cursor;
get_horario: LOOP
    FETCH sede_cursor INTO f_sede;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;


  	IF length(Sedes_s)=0 then
   		set Sedes_s = f_sede;
   		set sede_verificar = f_sede;
   	else

   		if INSTR(Sedes_s , f_sede) <= 0 then
   	   		set Sedes_s = CONCAT(Sedes_s , ' / ', f_sede);
   	   	end if;
   	end if;


END LOOP get_horario;
  CLOSE sede_cursor;

RETURN Sedes_s;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetRequisitos`(`idMalla` INT, `idCurso` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Requisitos text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE curso_cursor CURSOR FOR
	SELECT CONCAT(c.descripcion, '<br>')
	FROM mallas_req AS m
	INNER JOIN cursos c on m.id_curso_req = c.id
	WHERE m.id_curso = idCurso and m.id_malla = idMalla
    ORDER BY c.descripcion
	;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN curso_cursor;
	get_cursos: LOOP
    FETCH curso_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_cursos;
    END IF;

	SET v_Requisitos = CONCAT(v_Requisitos, v_Horario);

  END LOOP get_cursos;
  CLOSE curso_cursor;

RETURN SUBSTR(v_Requisitos,1,LENGTH(v_Requisitos)-4);
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`getSedeHorarioMatriculaAlumno`(idCursoProgramado INT, idSede INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_sedes text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;
 declare sede text default '';


  DECLARE horario_cursor CURSOR FOR
SELECT CONCAT(s.desc_corta)
FROM horarios AS h
INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
LEFT JOIN aulas a on h.id_aula = a.id
LEFT JOIN sedes s on a.id_local = s.id



WHERE h.id_cursoprogramado = idCursoProgramado
 and s.id_padre in (idSede ,15)
and h.activo=1 and h.estado=1



ORDER BY ds.id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN horario_cursor;
get_horario: LOOP
    FETCH horario_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;

   if sede='' then
   	set v_sedes = v_Horario;
	else
		if sede <> v_Horario THEN
			SET v_sedes = CONCAT(v_sedes, v_Horario);
		end if;
	end if;


  END LOOP get_horario;
  CLOSE horario_cursor;

RETURN v_sedes;
END;

CREATE DEFINER=`root`@`localhost` FUNCTION `siseacad`.`GetSilabo`(`idCursoProgramado` INT, `idSesion` INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_Silabo text default '';
  DECLARE v_Temas varchar(500);
  DECLARE fin INTEGER DEFAULT 0;

  DECLARE silabo_cursor CURSOR FOR

	SELECT CONCAT(b.tema, '<br>')
	FROM sesiones s
	INNER JOIN cursos_programados c ON s.id_curso_programado = c.id
	INNER JOIN mallas_det d ON c.id_malla_det = d.id
	INNER JOIN cursos e ON d.id_curso = e.id
	INNER JOIN detalle_silabo a ON c.id_malla_det = a.id_malla_det
	INNER JOIN detalle_silabo_det b ON a.id = b.id_detalle_silabo
	WHERE c.id = idCursoProgramado AND s.id = idSesion AND s.semana = b.nro_semana
    ORDER BY s.fecha;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN silabo_cursor;
	get_cursos: LOOP
    FETCH silabo_cursor INTO v_Temas;
    IF fin = 1 THEN
       LEAVE get_cursos;
    END IF;

	SET v_Silabo = CONCAT(v_Silabo, v_Temas);

  END LOOP get_cursos;
  CLOSE silabo_cursor;

RETURN SUBSTR(v_Silabo,1,LENGTH(v_Silabo)-4);
END;

CREATE DEFINER=`sisezend`@`%` FUNCTION `siseacad`.`getTurnoHorarioMatriculaAlumno`(idCursoProgramado INT, idSede INT) RETURNS text CHARSET latin1
BEGIN
  DECLARE v_turnos text default '';
  DECLARE v_Horario varchar(500);
  DECLARE fin INTEGER DEFAULT 0;
 declare turno text default '';


  DECLARE horario_cursor CURSOR FOR
SELECT CONCAT(g1.id_turno)
FROM horarios AS h
INNER JOIN diasemana ds on h.diasem = ds.id
    INNER JOIN grupo_hora_det g1 on h.id_grupo_hora_det_i = g1.id
    INNER JOIN grupo_hora_det g2 on h.id_grupo_hora_det_f = g2.id
LEFT JOIN aulas a on h.id_aula = a.id
LEFT JOIN sedes s on a.id_local = s.id



WHERE h.id_cursoprogramado = idCursoProgramado
 and s.id_padre in (idSede ,15)
and h.activo=1 and h.estado=1



ORDER BY ds.id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    OPEN horario_cursor;
get_horario: LOOP
    FETCH horario_cursor INTO v_Horario;
    IF fin = 1 THEN
       LEAVE get_horario;
    END IF;

   if turno='' then
   	set v_turnos = v_Horario;
	else
		if turno <> v_Horario THEN
			SET v_turnos = CONCAT(v_turnos, v_Horario);
		end if;
	end if;


  END LOOP get_horario;
  CLOSE horario_cursor;

RETURN v_turnos;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_CursosDesaprobados_by_alumno_idunidad`(
	IN pIdAlumno INT,
	IN pIdUnidad INT
)
begin
SELECT
	mallas_det.id,mallas_det.id_curso, cursos.descripcion as curso, mallas_det.ciclo,
	periodos.desc_larga as periodo_descripcion,
	cursos_programados.id,matricula_det.promedio_final
	FROM matricula_det
	INNER JOIN matricula ON matricula_det.id_matricula = matricula.id
	INNER JOIN periodos on periodos.id = matricula.id_periodo
	INNER JOIN cursos_programados ON matricula_det.id_cursoprogramado = cursos_programados.id
	INNER JOIN mallas_det ON mallas_det.id = cursos_programados.id_malla_det
	INNER JOIN cursos ON cursos.id = mallas_det.id_curso
	WHERE matricula.id_alumno = pIdAlumno
	AND matricula_det.promedio_final < mallas_det.nota_min
	AND matricula_det.id_matricula_est = 1 AND matricula.id_unidad =pIdUnidad
	AND mallas_det.id_curso NOT IN(
	SELECT mallas_det.id_curso
	FROM matricula_det
	INNER JOIN matricula ON matricula_det.id_matricula = matricula.id
	INNER JOIN cursos_programados ON matricula_det.id_cursoprogramado = cursos_programados.id
	INNER JOIN mallas_det ON mallas_det.id = cursos_programados.id_malla_det
	WHERE matricula.id_alumno = pIdAlumno
	AND matricula_det.promedio_final >= mallas_det.nota_min
	AND matricula_det.id_matricula_est = 1 AND matricula.id_unidad =pIdUnidad)
	and mallas_det.id_curso not in (
select c2.id from convalidaciones c
inner join admisiones a on a.id = c.id_admision and a.id_unidad = c.id_unidad
inner join convalidaciones_det cd on cd.id_convalidacion = c.id
inner join mallas_det md on md.id = cd.id_malla_det_des
inner join cursos c2 on md.id_curso = c2.id
where a.id_alumno =pIdAlumno and a.id_unidad =pIdUnidad and c.estado=1)
	;
end;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_CursosPendientes`(
	IN `pIdAlumno` INT,
	IN `pIdMalla` INT,
	IN `pIdPeriodo` INT
)
BEGIN

DECLARE vPeriodo INT;
DECLARE vCantDes INT;
DECLARE vValor CHAR(1);
DECLARE vCicloMax INT;
DECLARE vCiclosCons INT;
DECLARE vCant INT;
DECLARE vUltPerMat INT;
DECLARE vUnd INT;


SET vCiclosCons = 0;

SELECT COUNT(*) INTO vCant FROM matricula_parametros WHERE clave = 'CICLOSCONS' AND estado = '1';

IF vCant>0 THEN
	SELECT valor INTO vCiclosCons FROM matricula_parametros WHERE clave = 'CICLOSCONS' AND estado = '1';
END IF;



SELECT id_unidad INTO vUnd FROM mallas WHERE id = pIdMalla;

CREATE TEMPORARY TABLE tmpCursos(
   idMallaDet INT PRIMARY KEY,
   id INT,
   descripcion VARCHAR(250),
   ciclo TINYINT,
   creditos TINYINT,
   flagdesa TINYINT
);

INSERT INTO tmpCursos(idMallaDet,id,descripcion,ciclo,creditos,flagdesa)
SELECT md.id as idMallaDet, c.id, CONCAT(c.descripcion,' - Ciclo ',md.ciclo),md.ciclo,md.creditos,0
FROM mallas_det as md
INNER JOIN cursos AS c ON md.id_curso=c.id
WHERE md.estado = 1
AND c.estado=1
AND md.id_malla = pIdMalla;


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT id_malla_det FROM v_notas_alumno
WHERE id_alumno = pIdAlumno AND id_malla = pIdMalla
AND nota >= nota_min
);


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT cod_malla_det
FROM mallas_req mr
WHERE id_malla = pIdMalla AND cod_malla_det_req NOT IN
(SELECT id_malla_det
FROM v_notas_alumno
WHERE id_alumno = pIdAlumno AND id_malla=pIdMalla AND nota>=nota_min)
);


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT mallas_det.id
FROM matricula_det
INNER JOIN matricula ON matricula_det.id_matricula = matricula.id
INNER JOIN cursos_programados ON matricula_det.id_cursoprogramado = cursos_programados.id_padre
INNER JOIN mallas_det ON mallas_det.id = cursos_programados.id_malla_det
WHERE matricula.id_alumno = pIdAlumno AND mallas_det.id_malla = pIdMalla
AND matricula_det.promedio_final IS NULL
AND id_matricula_est in (1,4)
);



SELECT IFNULL(max(m.id_periodo),0) INTO vUltPerMat
FROM matricula as m
WHERE m.id_alumno = pIdAlumno
AND m.id_unidad = vUnd
AND m.id_periodo <> pIdPeriodo;

UPDATE tmpCursos SET flagdesa = 1 WHERE idMallaDet IN(
SELECT cp.id_malla_det
FROM matricula as m
inner JOIN matricula_det as md ON md.id_matricula = m.id
inner JOIN cursos_programados as cp on md.id_cursoprogramado = cp.id_padre
inner JOIN mallas_det as mad on cp.id_malla_det = mad.id
WHERE m.id_alumno = pIdAlumno
and m.id_unidad = vUnd
and m.id_periodo = vUltPerMat
and md.id_matricula_est = 1
and md.promedio_final < mad.nota_min);

SET @row_number = 0;
SET vCicloMax = 9999;

IF vCant>0 THEN
	SELECT MAX(b.ciclo) INTO vCicloMax FROM(
	SELECT (@row_number:=@row_number + 1) AS num, ciclo
	FROM (
	SELECT ciclo
	FROM tmpCursos
	GROUP BY ciclo) a) b
	WHERE b.num <= vCiclosCons;
END IF;



IF pIdPeriodo>0 THEN
	DELETE FROM tmpCursos WHERE idMallaDet NOT IN
	(SELECT md1.id
		FROM cursos_programados cp1
		INNER JOIN mallas_det md1 ON cp1.id_malla_det = md1.id
		INNER JOIN horarios h1 ON h1.id_cursoprogramado = cp1.id_padre
		WHERE
		cp1.id_periodo = pIdPeriodo AND h1.activo = 1
	);
END IF;

SELECT * FROM tmpCursos
WHERE ciclo <= vCicloMax
ORDER BY ciclo, descripcion;

DROP TEMPORARY TABLE tmpCursos;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_CursosPendientesConClase`(
	IN `pIdAlumno` INT,
	IN `pIdMalla` INT,
	IN `pIdPeriodo` INT
)
BEGIN

DECLARE vPeriodo INT;
DECLARE vCantDes INT;
DECLARE vValor CHAR(1);
DECLARE vCicloMax INT;
DECLARE vCiclosCons INT;
DECLARE vCant INT;
DECLARE vUltPerMat INT;
DECLARE vUnd INT;


SET vCiclosCons = 0;

SELECT COUNT(*) INTO vCant FROM matricula_parametros WHERE clave = 'CICLOSCONS' AND estado = '1';

IF vCant>0 THEN
	SELECT valor INTO vCiclosCons FROM matricula_parametros WHERE clave = 'CICLOSCONS' AND estado = '1';
END IF;



SELECT id_unidad INTO vUnd FROM mallas WHERE id = pIdMalla;

CREATE TEMPORARY TABLE tmpCursos(
   idMallaDet INT PRIMARY KEY,
   id INT,
   descripcion VARCHAR(100),
   ciclo TINYINT,
   flagdesa TINYINT
);

INSERT INTO tmpCursos(idMallaDet,id,descripcion,ciclo,flagdesa)
SELECT md.id as idMallaDet, c.id, CONCAT(c.descripcion,' - Ciclo ',md.ciclo),md.ciclo,0
FROM mallas_det as md
INNER JOIN cursos AS c ON md.id_curso=c.id
WHERE md.estado = 1
AND c.estado=1
AND md.id_malla = pIdMalla;


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT id_malla_det FROM v_notas_alumno
WHERE id_alumno = pIdAlumno AND id_malla = pIdMalla
AND nota >= nota_min
);


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT cod_malla_det
FROM mallas_req mr
WHERE id_malla = pIdMalla AND cod_malla_det_req NOT IN
(SELECT id_malla_det
FROM v_notas_alumno
WHERE id_alumno = pIdAlumno AND id_malla=pIdMalla AND nota>=nota_min)
);


DELETE FROM tmpCursos WHERE idMallaDet IN
(SELECT mallas_det.id
FROM matricula_det
INNER JOIN matricula ON matricula_det.id_matricula = matricula.id
INNER JOIN cursos_programados ON matricula_det.id_cursoprogramado = cursos_programados.id
INNER JOIN mallas_det ON mallas_det.id = cursos_programados.id_malla_det
WHERE matricula.id_alumno = pIdAlumno AND mallas_det.id_malla = pIdMalla
AND matricula_det.promedio_final IS NULL
);


SELECT IFNULL(max(m.id_periodo),0) INTO vUltPerMat
FROM matricula as m
INNER JOIN matricula_det as md ON md.id_matricula = m.id
INNER JOIN cursos_programados as cp ON md.id_cursoprogramado = cp.id
INNER JOIN mallas_det as mad ON cp.id_malla_det = mad.id
WHERE m.id_alumno = pIdAlumno
AND m.id_unidad = vUnd
AND m.promedio IS NOT NULL;

UPDATE tmpCursos SET flagdesa = 1 WHERE idMallaDet IN(
SELECT cp.id_malla_det
FROM matricula as m
inner JOIN matricula_det as md ON md.id_matricula = m.id
inner JOIN cursos_programados as cp on md.id_cursoprogramado = cp.id
inner JOIN mallas_det as mad on cp.id_malla_det = mad.id
WHERE m.id_alumno = pIdAlumno
and m.id_unidad = vUnd
and m.id_periodo = vUltPerMat
and md.promedio_final < mad.nota_min);

SET @row_number = 0;
SET vCicloMax = 9999;

IF vCant>0 THEN
	SELECT MAX(b.ciclo) INTO vCicloMax FROM(
	SELECT (@row_number:=@row_number + 1) AS num, ciclo
	FROM (
	SELECT ciclo
	FROM tmpCursos
	GROUP BY ciclo) a) b
	WHERE b.num <= vCiclosCons;
END IF;

SELECT * FROM tmpCursos
WHERE ciclo <= vCicloMax
ORDER BY ciclo, descripcion;

DROP TEMPORARY TABLE tmpCursos;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_gen_semanas`()
BEGIN

SET @num:=0;
SET @id_cp_ant:=0;

UPDATE sesiones s
INNER JOIN
	(
		SELECT id, diasem, id_curso_programado, id_cp_ant, fecha, seman_anio, seman_ant, contador_grupo, contador
		FROM
			(select id, diasem, id_curso_programado, @id_cp_ant AS id_cp_ant, fecha, seman_anio, @seman_anio AS seman_ant,
		        @num := if((@id_cp_ant <> `id_curso_programado`  ), 1, IF(@seman_anio <> `seman_anio`, @num + 1, @num))as contador_grupo,
		        @seman_anio := `seman_anio` as dummy, contador,
		        @id_cp_ant := `id_curso_programado`
		  	 from
			  		(SELECT a.id, a.diasem, a.id_curso_programado, a.fecha, YEARWEEK(a.fecha) AS seman_anio, @rn:=@rn+1 contador
				    from sesiones a, (SELECT @rn:=0) r
				    WHERE a.id_curso_programado IN(SELECT DISTINCT id_curso_programado FROM sesiones WHERE semana = 0)
				    ORDER BY id_curso_programado, fecha
			  		) x
			 ) x
		ORDER BY id_curso_programado, fecha
	) sesiones_grpo
ON s.id = sesiones_grpo.id
SET s.semana = sesiones_grpo.contador_grupo;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_gen_sesiones`(
)
BEGIN

	DECLARE v_id_horario INT;
	DECLARE v_id_cursoprogramado INT;
	DECLARE v_id_docente INT;
	DECLARE v_id_aula INT;
	DECLARE v_dia TINYINT;
   DECLARE v_hor_ini VARCHAR(5);
	DECLARE v_fec_inicio DATE;
   DECLARE v_hor_fin VARCHAR(5);
	DECLARE v_fec_fin DATE;
	DECLARE v_nro_sesiones INT;
	DECLARE v_id_horario_actual INT;
	DECLARE v_contador INT;
	DECLARE v_semana INT;
	DECLARE fin INTEGER DEFAULT 0;

DECLARE cur_horarios CURSOR FOR
	SELECT DISTINCT a.id, a.id_cursoprogramado, a.id_docente, a.id_aula, a.diasem, a.hora_ini, a.fecha_ini, a.hora_fin, a.fecha_fin
	FROM horarios a
	INNER JOIN cursos_programados b ON a.id_cursoprogramado = b.id
	INNER JOIN periodos c ON b.id_periodo = c.id
	WHERE IFNULL(sesiones_gen_flg2, 0)=0
			AND IFNULL(a.fecha_ini, '')<>''
			AND IFNULL(a.fecha_fin, '')<>''
			AND IFNULL(a.hora_ini, '')<>''
			AND IFNULL(a.hora_fin, '')<>''
			AND b.estado = 1
			AND a.estado = 1
			AND a.activo = 1
			AND c.estado = 1
			AND a.fecha_fin > DATE_FORMAT(NOW( ), '%Y-%m-%d')
			AND DATE_FORMAT((DATE_SUB(a.fecha_ini,INTERVAL 1 DAY)), '%Y-%m-%d')<= DATE_FORMAT(NOW(), '%Y-%m-%d')
		 	AND IFNULL(a.cant_horas, 0)<>0
		 	AND IFNULL(a.id_docente, 0)<>0
		 	AND b.id = b.id_padre
		 	AND a.fecha_ini >= '2020-09-01'
	ORDER BY a.id_cursoprogramado, a.diasem, a.id;

  	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;

	OPEN cur_horarios;
	get_runners: LOOP

	FETCH cur_horarios INTO v_id_horario, v_id_cursoprogramado, v_id_docente, v_id_aula, v_dia, v_hor_ini, v_fec_inicio, v_hor_fin, v_fec_fin;
	IF fin = 1 THEN
	  LEAVE get_runners;
	END IF;




	SET @s=0;


	INSERT INTO sesiones(id_horario, id_curso_programado, id_docente, id_aula, diasem, fecha, semana, estado, created_at, created_by, updated_at, updated_by)

	SELECT 	v_id_horario, v_id_cursoprogramado, v_id_docente, v_id_aula, v_dia, DIASENTREFECHAS, 0, 1, NOW(), 1, NOW(), 1 FROM

	(SELECT 	DATE(ADDDATE(ADDDATE(NOW(), INTERVAL 1 DAY), INTERVAL @i:=@i+1 DAY)) AS DIASENTREFECHAS

	FROM (
	SELECT a.a
	FROM (SELECT 0 AS a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS a
	CROSS JOIN (SELECT 0 AS a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS b
	CROSS JOIN (SELECT 0 AS a UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS c
	) a
	JOIN (SELECT @i := -1) r1
	WHERE @i < (TIMESTAMPDIFF(DAY, v_fec_inicio, v_fec_fin )
	) ) AS DIAS
	WHERE dayofweek(DIASENTREFECHAS) = (CASE WHEN v_dia = 7 THEN 1 ELSE (v_dia + 1) END)
	AND DIASENTREFECHAS NOT IN (SELECT fec_excepcion FROM excep_calendario WHERE id_periodo_lab IN(YEAR(v_fec_inicio), YEAR(v_fec_fin)) )
	AND DIASENTREFECHAS > IFNULL((SELECT fec_fin FROM periodo_laboral
											WHERE  IFNULL(cierre, 0) = 1 AND DIASENTREFECHAS BETWEEN fec_inicio AND fec_fin), '1990-01-01')
	AND DIASENTREFECHAS > DATE_FORMAT(NOW( ), '%Y-%m-%d')
	AND DIASENTREFECHAS <= v_fec_fin
	AND DIASENTREFECHAS NOT IN (SELECT fecha FROM sesiones WHERE id_horario = v_id_horario)

	ORDER BY v_id_cursoprogramado, DIASENTREFECHAS;




	SET v_nro_sesiones 		=	(SELECT IFNULL(COUNT(*),0) FROM sesiones WHERE id_horario = v_id_horario);
	UPDATE horarios SET
	sesiones_gen_nro  = v_nro_sesiones,
	sesiones_fec_gen1 = (CASE WHEN sesiones_fec_gen1 IS NULL THEN NOW() ELSE sesiones_fec_gen1 END),
	sesiones_gen_flg1 = (CASE WHEN sesiones_gen_flg1 IS NULL THEN 1 ELSE sesiones_gen_flg1 END),
	sesiones_gen_flg2 = (CASE WHEN v_nro_sesiones = 0 THEN 0 ELSE 1 END),
	sesiones_fec_gen2 = NOW()
	WHERE id = v_id_horario;

END LOOP get_runners;

CLOSE cur_horarios;

END;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListaAulasMant`(IN par_descr VARCHAR(50), IN par_campus INT, IN par_sede INT)
SELECT c.id cod,b.desc_corta campus,a.desc_corta locacion,c.descripcion descr,c.nro_instalacion nroinst,c.capacidad capac,d.id id_tipo_instalacion,d.descripcion_corta tipo, c.estado,
	c.created_at fecreg2, DATE_FORMAT(c.created_at, '%d/%m/%Y %H:%i') as fecreg, c.updated_at fecupd2, DATE_FORMAT(c.updated_at, '%d/%m/%Y %H:%i') as fecupd
	FROM (SELECT * FROM sedes WHERE id_padre<>0 ) a
	INNER JOIN (SELECT * FROM sedes WHERE id_padre=0 ) b ON b.id=a.id_padre
	INNER JOIN aulas c ON a.id=c.id_local
	INNER JOIN tipo_instalacion d ON d.id=c.id_tipo_instalacion
	WHERE upper(c.descripcion) like (case par_descr when 9999 then '%' else concat('%',upper(par_descr),'%') END) and
  	b.id like par_campus  and
   a.id like (case par_sede when '9999' then '%' else par_sede END)
   ORDER BY c.updated_at DESC;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListaDocentesMant`(IN `par_descr` VARCHAR(50), IN `par_estado` INT)
SELECT a.id cod,concat(b.paterno,' ',b.materno,' ',b.nombres) AS nombre_completo, c.des_corta tipdoc,nro_documento nrodoc, ruc, telefono_movil telf, us.email as email, a.estado FROM docentes a
INNER JOIN persona_actualiza b ON a.id_persona=b.id_persona
INNER JOIN tipo_documento c ON b.id_tipo_documento=c.id
INNER JOIN users us ON us.id = a.id_user
where upper(concat(b.paterno,' ',b.materno,' ',b.nombres)) like upper(concat('%',par_descr,'%'))
and a.estado like (case par_estado when 2 then '%' else par_estado end);

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListadodedocenteSinAsistencias`(IN `par_desde` VARCHAR(10), IN `par_hasta` VARCHAR(10), IN `par_local` INT)
SELECT a.id,coalesce(total,0) cant_alumnos ,
 l.id,substr(l.descripcion,1,30) descripcion,upper(substr(dayname(CONVERT(a.fecha,DATE)),1,3)) AS dia_nombre,CONCAT(' ',a.fecha,'(',c.hora_ini,c.hora_fin,')') AS horario,i.descripcion curso_nombre,
CONCAT(h.paterno,' ',h.materno,',',h.nombres) AS nombre_docente,
h.email,h.telefono_movil
FROM (SELECT id_sesion, COUNT(*) total FROM asistencia_alumnos GROUP BY id_sesion) cant_sesion
right JOIN sesiones a ON cant_sesion.id_sesion = a.id
INNER JOIN horarios c 		ON c.id 			= a.id_horario
INNER JOIN sedes f			ON c.id_local	= f.id
INNER JOIN docentes g      ON a.id_docente=g.id
INNER JOIN persona h      ON g.id_persona = h.id
INNER JOIN cursos i       ON i.id=a.id_curso_programado
INNER JOIN cursos_programados j ON i.id=j.id
INNER JOIN mallas_det k ON a.id_curso_programado=k.id_curso
INNER JOIN mallas l ON k.id_malla=l.id
WHERE a.estado = 1 AND
 a.fecha BETWEEN par_desde AND par_hasta AND
 f.id_padre = par_local and coalesce(total,0)=0
ORDER BY a.id,l.id,a.fecha;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListadodedocenteSinAvance`(IN `par_desde` VARCHAR(10), IN `par_hasta` VARCHAR(10), IN `par_local` INT)
SELECT a.id, l.id,l.descripcion,upper(substr(dayname(CONVERT(a.fecha,DATE)),1,3)) AS dia_nombre,CONCAT(' ',a.fecha,'(',c.hora_ini,c.hora_fin,')') AS horario,i.descripcion curso_nombre,
CONCAT(h.paterno,' ',h.materno,',',h.nombres) AS nombre_docente,
h.email,h.telefono_movil
FROM avance_programatico as cant_sesion
right JOIN sesiones a ON cant_sesion.id_sesion = a.id
INNER JOIN horarios c 		ON c.id 			= a.id_horario
INNER JOIN sedes f			ON c.id_local	= f.id
INNER JOIN docentes g      ON a.id_docente=g.id
INNER JOIN persona h      ON g.id_persona = h.id
INNER JOIN cursos i       ON i.id=a.id_curso_programado
INNER JOIN cursos_programados j ON i.id=j.id
INNER JOIN mallas_det k ON a.id_curso_programado=k.id_curso
INNER JOIN mallas l ON k.id_malla=l.id
WHERE a.estado = 1
AND a.fecha BETWEEN par_desde AND par_hasta
AND f.id_padre = par_local
ORDER BY a.id,l.id,a.fecha;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListadodedocenteSinMarca`(IN `par_local` INT(2), IN `par_desde` VARCHAR(10), IN `par_hasta` VARCHAR(10))
SELECT a.id,substr(a.descripcion,1,30) as carrera,upper(substr(dayname(CONVERT(h.fecha,DATE)),1,3)) AS dia_nombre,CONCAT(' ',h.fecha,'(',e.hora_ini,'-',e.hora_fin,')') AS horario,d.descripcion as curso_nombre,
CONCAT(g.paterno,' ',g.materno,',',g.nombres) AS nombre_docente,
i.marca_ini, i.marca_fin, g.email,g.telefono_movil,
a.id, h.fecha, e.id_aula, e.id_local, j.desc_corta, h.id_docente, e.hora_ini, i.marca_ini, i.min_dife AS 'tard_ent', e.hora_fin, i.marca_fin, i.min_difs AS 'tard_sal', e.cant_horas FROM mallas a
INNER JOIN mallas_det b
ON a.id=b.id_malla AND b.estado=1
INNER JOIN cursos_programados c
ON b.id=c.id_malla_det
INNER JOIN cursos d
ON b.id_curso=d.id
INNER JOIN horarios e
ON e.id_cursoprogramado=c.id
INNER JOIN docentes f
ON e.id_docente=f.id
INNER JOIN persona g
ON f.id_persona=g.id
INNER JOIN sesiones h
ON E.id=h.id_horario
left JOIN marcaciones i
ON i.id_sesion=h.id AND i.id_horario=e.id AND i.id_docente=f.id
INNER JOIN sedes j
ON e.id_local=j.id
WHERE i.id_sesion IS null
and j.id_padre=par_local
and h.fecha between par_desde and par_hasta;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListadodedocenteTardanza`(IN `par_local` INT(2), IN `par_desde` VARCHAR(10), IN `par_hasta` VARCHAR(10))
SELECT a.id,a.descripcion as carrera,upper(substr(dayname(CONVERT(h.fecha,DATE)),1,3)) AS dia_nombre,CONCAT(' ',h.fecha,'(',e.hora_ini,'-',e.hora_fin,')') AS horario,d.descripcion as curso_nombre,
CONCAT(g.paterno,' ',g.materno,',',g.nombres) AS nombre_docente,
i.marca_ini, i.marca_fin, g.email,g.telefono_movil,
a.id, h.fecha, e.id_aula, e.id_local, j.desc_corta, h.id_docente, e.hora_ini, i.marca_ini, i.min_dife AS 'tard_ent', e.hora_fin, i.marca_fin, i.min_difs AS 'tard_sal', e.cant_horas FROM mallas a
INNER JOIN mallas_det b
ON a.id=b.id_malla AND b.estado=1
INNER JOIN cursos_programados c
ON b.id=c.id_malla_det
INNER JOIN cursos d
ON b.id_curso=d.id
INNER JOIN horarios e
ON e.id_cursoprogramado=c.id
INNER JOIN docentes f
ON e.id_docente=f.id
INNER JOIN persona g
ON f.id_persona=g.id
INNER JOIN sesiones h
ON e.id=h.id_horario
INNER JOIN marcaciones i
ON i.id_sesion=h.id AND i.id_horario=e.id AND i.id_docente=f.id
INNER JOIN sedes j
ON e.id_local=j.id
WHERE
 (COALESCE(min_dife,0)<>0 OR COALESCE(min_difs,0)<>0)
 and j.id_padre=par_local AND h.fecha between par_desde and par_hasta;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_ListarSedes`()
SELECT distinct a.id, a.desc_corta FROM sedes a
INNER JOIN seg_sedes_2 b
ON a.id=b.id_sedes_1
WHERE b.id_users='10164';

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_PorcentajeAvance`(IN `par_fecha` VARCHAR(10), IN `par_local` INT)
SELECT COALESCE(ROUND(
((select COUNT(*) FROM
(SELECT b.id, b.fecha,coalesce(avance_sesion.total_al,0) alumnos FROM (SELECT id_sesion,COUNT(*) total_al FROM avance_programatico
GROUP BY id_sesion) avance_sesion
right JOIN sesiones b
ON avance_sesion.id_sesion=b.id
RIGHT JOIN horarios c
ON b.id_horario=c.id
INNER JOIN sedes f
ON c.id_local=f.id
WHERE b.fecha=par_fecha
AND f.id_padre=par_local
)  SIN_avance WHERE SIN_avance.alumnos=0)
/
COUNT(*))*100),100) AS percent from
(SELECT b.id, b.fecha,coalesce(avance_sesion.total_al,0) alumnos FROM (SELECT id_sesion,COUNT(*) total_al FROM avance_programatico
GROUP BY id_sesion) avance_sesion
right JOIN sesiones b
ON avance_sesion.id_sesion=b.id
RIGHT JOIN horarios c
ON b.id_horario=c.id
INNER JOIN sedes f
ON c.id_local=f.id
WHERE b.fecha=par_fecha
AND f.id_padre=par_local
) avance_programaticos;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_PorcentajeSinAsistencia`(IN `par_fecha` VARCHAR(10), IN `par_local` INT)
SELECT coalesce(ROUND(
((select COUNT(*) FROM
(SELECT b.id, b.fecha,coalesce(alumno_sesion.total_al,0) alumnos FROM (SELECT id_sesion,COUNT(*) total_al FROM asistencia_alumnos
GROUP BY id_sesion) alumno_sesion
right JOIN sesiones b
ON alumno_sesion.id_sesion=b.id
RIGHT JOIN horarios c
ON b.id_horario=c.id
INNER JOIN sedes f
ON c.id_local=f.id
WHERE b.fecha=par_fecha
AND f.id_padre=par_local
)  SIN_asis WHERE SIN_asis.alumnos=0)
/
COUNT(*))*100),100) AS percent from
(SELECT b.id, b.fecha,coalesce(alumno_sesion.total_al,0) alumnos FROM (SELECT id_sesion,COUNT(*) total_al FROM asistencia_alumnos
GROUP BY id_sesion) alumno_sesion
right JOIN sesiones b
ON alumno_sesion.id_sesion=b.id
RIGHT JOIN horarios c
ON b.id_horario=c.id
INNER JOIN sedes f
ON c.id_local=f.id
WHERE b.fecha=par_fecha
AND f.id_padre=par_local
) asistencia;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_PorcentajeSinMarcas`(IN `pfecha` VARCHAR(10), IN `plocal` INT)
select coalesce(round(count(*)/ (SELECT count(*) FROM sesiones a LEFT JOIN marcaciones b ON a.id = b.id_sesion INNER JOIN horarios c ON c.id = a.id_horario INNER JOIN sedes f ON c.id_local = f.id WHERE a.estado = 1 AND COALESCE(b.estado, 1) = 1 AND a.fecha=pfecha AND f.id_padre = plocal)*100),100) as percent from sesiones a LEFT JOIN marcaciones b ON a.id = b.id_sesion INNER JOIN horarios c ON c.id = a.id_horario INNER JOIN sedes f ON c.id_local = f.id WHERE a.estado = 1 AND COALESCE(b.estado, 1) = 1 AND a.fecha=pfecha AND f.id_padre = plocal and (b.marca_ini is null or b.marca_fin is null);

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_PorcentajeTardanzas`(IN `pfecha` VARCHAR(10), IN `plocal` INT)
select coalesce(round(count(*)/ (SELECT count(*) FROM sesiones a LEFT JOIN marcaciones b ON a.id = b.id_sesion
 INNER JOIN horarios c ON c.id = a.id_horario INNER JOIN sedes f ON c.id_local = f.id WHERE a.estado = 1 AND COALESCE(b.estado, 1) = 1
  AND a.fecha=pfecha AND f.id_padre = plocal)*100),100) as percent from sesiones a LEFT JOIN marcaciones b ON a.id = b.id_sesion INNER JOIN
   horarios c ON c.id = a.id_horario INNER JOIN sedes f ON c.id_local = f.id WHERE a.estado = 1 AND COALESCE(b.estado, 1) = 1 AND a.fecha=pfecha
	AND f.id_padre = plocal and min_difs>0;

CREATE DEFINER=`sisezend`@`localhost` PROCEDURE `siseacad`.`PA_prc_calculo_1`(
	IN `pid_tar_proceso_calculo_1` INT,
	IN `pprocessed_by` INT
)
BEGIN

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
 	BEGIN
 		SELECT 'Hay un excepción SQL';
 		SHOW ERRORS LIMIT 1;
		RESIGNAL;
 		ROLLBACK;
 	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
 	BEGIN
 		SELECT 'Hay un warning en SQL';
 		SHOW WARNINGS LIMIT 1;
		RESIGNAL;
 		ROLLBACK;
 	END;

	START TRANSACTION;

		SET @validar=0;
		SET @id_pl	=0;
		SET @ins_tar_proceso_calculo_2=0;


	 	SELECT @id_pl:=id_periodo_laboral, @id_campus:=id_campus, @id_grupo_pago:=id_grupo_pago FROM tar_proceso_calculo_1 WHERE id = pid_tar_proceso_calculo_1 AND estado <> 2;
	 	IF(@id_pl>0) THEN

		 	SELECT @validar:= id, @pl_fi:=fec_inicio, @pl_ff:=fec_fin FROM periodo_laboral WHERE id = @id_pl AND cierre = 0;

		 	IF(@validar>0) THEN

		 		UPDATE tar_proceso_calculo_1 SET estado = 2 WHERE id = pid_tar_proceso_calculo_1 AND estado <> 2;

		 		DELETE FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1;




		 		INSERT INTO tar_proceso_calculo_2 (id, id_tar_proceso_calculo_1, id_sesion, id_horario, id_docente, desc_docente, fecha, hora_ini, hora_fin, cant_horas, marca_ini, min_dife, min_dife_a, marca_fin, min_difs, min_difs_a, obs, justificar,
				procesado, smarc, estado, id_grupo_pago, id_cursoprogramado, id_malla_det, ciclo, desc_curso, tarifa_ori, id_subtipo, id_tarifa_det, tarifa, obs_ref, duracion_hr, min_tardanza, min_efec_pagar, hrs_efec_pagar, created_at, created_by, updated_at, updated_by, processed_at, processed_by)

				SELECT DISTINCT 0 AS id_tar_proceso_calculo_2, pid_tar_proceso_calculo_1, a.id_sesion, a.id_horario, a.id_docente, CONCAT(e.paterno, ' ', e.materno, ', ', e.nombres)as desc_docente, a.fecha, a.hora_ini, a.hora_fin, b.cant_horas, a.marca_ini, a.min_dife, a.min_dife_a, a.marca_fin, a.min_difs, a.min_difs_a, a.obs, a.justificar,
				1 AS procesado, a.smarc, a.estado, e.id_grupo_pago, b.id_cursoprogramado, c.id_malla_det, md.ciclo, cu.descripcion,
				CASE WHEN IFNULL(b.tarifa, 0) <> 0      THEN  1 ELSE
					CASE WHEN IFNULL(md.tarifa, 0) <> 0  THEN  2 ELSE NULL END
				END AS tarifa_ori,
				NULL AS id_subtipo,
				NULL AS id_tarifa_det,
				CASE WHEN IFNULL(b.tarifa, 0) <> 0      THEN  b.tarifa ELSE
					CASE WHEN IFNULL(md.tarifa, 0) <> 0  THEN  md.tarifa ELSE NULL END
				END AS tarifa,
				CASE WHEN IFNULL(b.tarifa, 0) <> 0 THEN  'Tarifa de Horario' ELSE
					(CASE WHEN IFNULL(md.tarifa, 0) <> 0 THEN 'Tarifa de Malla' ELSE NULL END)
				END AS obs_ref, g.duracion_hr,
				CASE WHEN a.justificar = 1 THEN b.cant_horas ELSE
					CASE 	WHEN (  ( (a.min_dife + a.min_difs) - (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) )>0 THEN
									(  ( (a.min_dife + a.min_difs) - (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) )
					ELSE
								0
					END
				END AS min_tardanza,
				CASE WHEN a.justificar = 1 THEN b.cant_horas ELSE
					CASE 	WHEN ( (b.cant_horas * g.duracion_hr) - ( (a.min_dife + a.min_difs) - (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) )>0 THEN
									( (b.cant_horas * g.duracion_hr) - ( (a.min_dife + a.min_difs) - (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) )
					ELSE
								0
					END
				END AS min_efec_pagar,
				CASE WHEN a.justificar = 1 THEN b.cant_horas ELSE
					CASE 	WHEN ( (b.cant_horas * g.duracion_hr) - ( (a.min_dife + a.min_difs) - (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) )>0 THEN
									( b.cant_horas*( (b.cant_horas * g.duracion_hr) - ((a.min_dife + a.min_difs)- (IFNULL(a.min_dife_a,0) + IFNULL(a.min_difs_a, 0)) ) ) )/(b.cant_horas * g.duracion_hr)
					ELSE
								0
					END
				END AS hrs_efec_pagar,
				a.created_at, a.created_by, a.updated_at, a.updated_by, NOW() AS  processed_at, pprocessed_by
			 	FROM marcaciones a
			 	INNER JOIN horarios  b 				ON b.id = a.id_horario
			 	INNER JOIN cursos_programados	c 	ON c.id = b.id_cursoprogramado
			 	INNER JOIN docentes d				ON d.id = b.id_docente
			 	INNER JOIN persona e					ON e.id = d.id_persona
			 	INNER JOIN grupo_pago f				ON f.id = e.id_grupo_pago
			 	LEFT JOIN  tarifa_cab tc			ON tc.id_docente = a.id_docente		AND tc.id_subtipo = 1
			 	LEFT JOIN  tarifa_det td			ON td.id_tarifa_cab = tc.id 			AND td.estado = 1
			 	LEFT JOIN  mallas_det md			ON md.id = c.id_malla_det
			 	LEFT JOIN  cursos cu					ON cu.id =md.id_curso
			 	INNER JOIN grupo_hora_det g		ON g.id = b.id_grupo_hora_det_i
				WHERE a.estado = 1
				AND a.procesado <> 1
				AND a.fecha BETWEEN @pl_fi AND @pl_ff

				AND e.id_grupo_pago	= @id_grupo_pago;

				SELECT @procesados   	:= COUNT(id_sesion) 	  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND procesado = 1;
				SELECT @nro_docentes 	:= COUNT(DISTINCT id_docente)   FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND IFNULL(id_docente, 0)<>0;
				SELECT @justificaciones := COUNT(justificar)   FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND justificar = 1;
				SELECT @marcas_efectivas:= COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND (IFNULL(marca_fin,'')	<>'' AND IFNULL(marca_ini,'')<>'');
				SELECT @tardanzas		   := COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND ( (IFNULL(min_dife,0)	<>0  OR  IFNULL(min_difs,0)<>0) ) AND (IFNULL(marca_fin,'')	<>'' AND IFNULL(marca_ini,'')<>'');
				SELECT @faltas			   := COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND (IFNULL(marca_fin,'')	<>'' OR IFNULL(marca_ini,'')<>'');

				UPDATE tar_proceso_calculo_2 SET monto = (IFNULL(tarifa, 0) * IFNULL(hrs_efec_pagar,0)) WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1;
				UPDATE tar_proceso_calculo_1
				SET nro_docentes 	 		= @nro_docentes,
					 nro_sesiones 	 		= @procesados,
					 nro_marcas 	 		= @marcas_efectivas,
					 nro_tardanzas	 		= @tardanzas,
					 nro_faltas  		 	= @faltas,
					 nro_justificaciones	= @justificaciones
				WHERE id = pid_tar_proceso_calculo_1;


				SET @ins_tar_proceso_calculo_2=1;
			END IF;

		END IF;

	COMMIT;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_prc_calculo_2`(
	IN pid_tar_proceso_calculo_1 INT,
	IN pprocessed_by INT)
BEGIN

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
 	BEGIN
 		SELECT 'Hay un excepción SQL';
 		SHOW ERRORS LIMIT 1;
		RESIGNAL;
 		ROLLBACK;
 	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
 	BEGIN
 		SELECT 'Hay un warning en SQL';
 		SHOW WARNINGS LIMIT 1;
		RESIGNAL;
 		ROLLBACK;
 	END;

	START TRANSACTION;

		SET @validar=0;
		SET @id_pl	=0;
		SET @ins_tar_proceso_calculo_2=0;


	 	SELECT @id_pl:=id_periodo_laboral, @id_campus:=id_campus, @id_grupo_pago:=id_grupo_pago FROM tar_proceso_calculo_1 WHERE id = pid_tar_proceso_calculo_1 AND IFNULL(id_campus, 0) = 0 AND estado <> 2;
	 	IF(@id_pl>0) THEN

		 	SELECT @validar:= id, @pl_fi:=fec_inicio, @pl_ff:=fec_fin FROM periodo_laboral WHERE id = @id_pl AND cierre = 0;

		 	IF(@validar>0) THEN

		 		UPDATE tar_proceso_calculo_1 SET estado = 2 WHERE id = pid_tar_proceso_calculo_1 AND estado <> 2 AND IFNULL(id_campus, 0) = 0;

		 		DELETE FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1;





		 		INSERT INTO tar_proceso_calculo_2 (id, id_tar_proceso_calculo_1, id_sesion, id_horario, id_docente, desc_docente, fecha, hora_ini, hora_fin, cant_horas, marca_ini, min_dife, min_dife_a, marca_fin, min_difs, min_difs_a, obs,
				justificar, procesado, smarc, estado, id_grupo_pago, id_cursoprogramado, id_malla_det, ciclo, desc_curso, tarifa_ori, id_subtipo, id_tarifa_det, tarifa, obs_ref, duracion_hr, min_tardanza, min_efec_pagar, hrs_efec_pagar,
				created_at, created_by, updated_at, updated_by, processed_at, processed_by)

				SELECT DISTINCT 0 AS id_tar_proceso_calculo_2, pid_tar_proceso_calculo_1, 0 AS id_sesion, 0 AS id_horario, a.id_docente, CONCAT(e.paterno, ' ', e.materno, ', ', e.nombres)as desc_docente, @pl_fi AS  fecha, NULL AS hora_ini, NULL AS hora_fin, NULL as cant_horas, NULL AS marca_ini, NULL AS min_dife, NULL AS min_dife_a, NULL AS marca_fin, NULL AS min_difs, NULL AS min_difs_a, NULL AS obs,
				'' AS justificar, '' AS procesado, '' AS smarc, 1 AS estado, e.id_grupo_pago, 0 AS id_cursoprogramado, 0 AS id_malla_det, NULL AS ciclo, '' AS desc_curso, 3 as tarifa_ori, tc.id_subtipo, td.id AS id_tarifa_det, td.monto AS tarifa, 'Tarifa Monto Fijo' AS obs_ref, NULL AS duracion_hr,
				NULL as min_tardanza, NULL as min_efec_pagar, NULL as hrs_efec_pagar,
				td.created_at, td.created_by, td.updated_at, td.updated_by, NOW() AS  processed_at, pprocessed_by
			 	FROM marcaciones a
			 	INNER JOIN horarios  b 				ON b.id = a.id_horario
			 	INNER JOIN cursos_programados	c 	ON c.id = b.id_cursoprogramado
			 	INNER JOIN docentes d				ON d.id = b.id_docente
			 	INNER JOIN persona e					ON e.id = d.id_persona
			 	INNER JOIN grupo_pago f				ON f.id = e.id_grupo_pago
			 	INNER JOIN  tarifa_cab tc			ON tc.id_docente = a.id_docente		AND tc.id_subtipo = 1
			 	INNER JOIN  tarifa_det td			ON td.id_tarifa_cab = tc.id 			AND td.estado = 1
				WHERE a.estado = 1
				AND a.procesado <> 1
				AND a.fecha BETWEEN @pl_fi AND @pl_ff

				AND e.id_grupo_pago	= @id_grupo_pago;

				SELECT @procesados   	:= COUNT(id_sesion) 	  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND procesado = 1;
				SELECT @nro_docentes 	:= COUNT(id_docente)   FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND IFNULL(id_docente, 0)<>0;
				SELECT @justificaciones := COUNT(justificar)   FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND justificar = 1;
				SELECT @marcas_efectivas:= COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND (IFNULL(marca_fin,'')	<>'' AND IFNULL(marca_ini,'')<>'');
				SELECT @tardanzas		   := COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND ( (IFNULL(min_dife,0)	<>0  OR  IFNULL(min_difs,0)<>0) ) AND (IFNULL(marca_fin,'')	<>'' AND IFNULL(marca_ini,'')<>'');
				SELECT @faltas			   := COUNT(id)  			  FROM tar_proceso_calculo_2 WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND (IFNULL(marca_fin,'')	<>'' OR IFNULL(marca_ini,'')<>'');

				UPDATE tar_proceso_calculo_2 SET monto = IFNULL(tarifa, 0) WHERE id_tar_proceso_calculo_1 = pid_tar_proceso_calculo_1 AND tarifa_ori = 3 AND id_subtipo = 1;
				UPDATE tar_proceso_calculo_1 SET nro_docentes 	 		= @nro_docentes WHERE id = pid_tar_proceso_calculo_1;

				SET @ins_tar_proceso_calculo_2=1;
			END IF;

		END IF;
	COMMIT;

END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `siseacad`.`PA_ResumenEstAsistenciaDoc`(
	IN `pid_campus`	INT,
	IN `pid_locac` 	INT,
	IN `pid_prog` 		INT,
	IN `pid_esc` 		INT,
	IN `pid_carr` 		INT,
	IN `pdia_i` 		DATE,
	IN `pdia_f` 		DATE
)
BEGIN

	SET @ntot:= (SELECT IFNULL(COUNT(DISTINCT a.id),0) FROM sesiones a
	INNER JOIN horarios b ON b.id = a.id_horario
	INNER JOIN cursos_programados f  ON f.id_padre	= a.id_curso_programado
	LEFT JOIN unidad u4					ON u4.id			= f.id_unidad
	LEFT JOIN unidad u3					ON u3.id			= u4.id_padre
	WHERE
	a.fecha 		BETWEEN pdia_i AND pdia_f																	AND
	b.id_local = CASE WHEN IFNULL(pid_locac, 0)=0 THEN b.id_local ELSE pid_locac END	AND
	u4.id	= CASE WHEN IFNULL(pid_carr, 0) = 0 THEN f.id_unidad ELSE pid_carr END 				AND
	u3.id = CASE WHEN IFNULL(pid_esc, 0) = 0 THEN u3.id ELSE pid_esc END 						AND
	a.estado = 1);


	SET @s_asis_a:= (SELECT IFNULL(COUNT(DISTINCT a.id),0) FROM sesiones a
	INNER JOIN horarios b ON b.id = a.id_horario
	INNER JOIN cursos_programados f  ON f.id_padre	= a.id_curso_programado
	LEFT JOIN unidad u4					ON u4.id			= f.id_unidad
	LEFT JOIN unidad u3					ON u3.id			= u4.id_padre

	WHERE
	a.fecha 		BETWEEN pdia_i AND pdia_f																	AND
	b.id_local = CASE WHEN IFNULL(pid_locac, 0)=0 THEN b.id_local ELSE pid_locac END			AND
	u4.id	= CASE WHEN IFNULL(pid_carr, 0) = 0 THEN f.id_unidad ELSE pid_carr END 				AND
	u3.id = CASE WHEN IFNULL(pid_esc, 0) = 0 THEN u3.id ELSE pid_esc END 						AND
	registro_asistencia = 0 																					AND
	a.estado = 1);


	SET @s_ava_a:= (SELECT IFNULL(COUNT(DISTINCT a.id),0) FROM sesiones a
	INNER JOIN horarios b ON b.id = a.id_horario
	INNER JOIN cursos_programados f  ON f.id_padre	= a.id_curso_programado
	LEFT JOIN unidad u4					ON u4.id			= f.id_unidad
	LEFT JOIN unidad u3					ON u3.id			= u4.id_padre

	WHERE
	a.fecha 		BETWEEN pdia_i AND pdia_f																	AND
	b.id_local = CASE WHEN IFNULL(pid_locac, 0)=0 THEN b.id_local ELSE pid_locac END	AND
	u4.id	= CASE WHEN IFNULL(pid_carr, 0) = 0 THEN f.id_unidad ELSE pid_carr END 				AND
	u3.id = CASE WHEN IFNULL(pid_esc, 0) = 0 THEN u3.id ELSE pid_esc END 						AND
	registro_avance = 0 																							AND
	a.estado = 1);


	SELECT EstAsistencia, COUNT(EstAsistencia) AS nroEA, @ntot AS ntot, @s_asis_a AS s_asis_a, @s_ava_a AS s_ava_a, ROUND( ((COUNT(EstAsistencia)/@ntot)*100), 2) AS por FROM
	(
		SELECT DISTINCT
			CASE 	WHEN IFNULL(b.marca_ini,'')='' 	OR IFNULL(marca_fin, '')='' 	THEN 'F'
					WHEN IFNULL(b.marca_ini,'')<>'' 	AND IFNULL(marca_fin, '')<>''	THEN
							CASE WHEN IFNULL(b.min_dife, 0)>0 OR IFNULL(b.min_difs, 0)>0 THEN 'T'
								  ELSE 'A'
							END
					ELSE
						CASE WHEN IFNULL(b.marca_ini,'')='' OR IFNULL(marca_fin, '')='' THEN 'T' END
			END AS 'EstAsistencia',
			a.id AS id_sesion, a.id_curso_programado, a.id_horario AS id_horario_se, a.id_docente AS id_docente_se, a.fecha AS fecha_se, a.id_aula as id_aula_se, c.id_local,
			b.id_horario AS id_horario_ma, b.id_docente AS id_docente_ma, b.fecha AS fecha_ma, b.hora_ini, b.hora_fin, b.marca_ini, b.min_dife, b.min_dife_a, b.marca_fin, b.min_difs, b.min_difs_a
		FROM sesiones a
		LEFT JOIN marcaciones b 			ON b.id_sesion = a.id
		LEFT JOIN horarios c 				ON c.id			= a.id_horario
		LEFT JOIN sedes d 					ON c.id_local	= d.id
		LEFT JOIN sedes e 					ON d.id_padre	= e.id
		INNER JOIN cursos_programados f  ON f.id_padre	= a.id_curso_programado
		LEFT JOIN unidad u4					ON u4.id			= f.id_unidad
		LEFT JOIN unidad u3					ON u3.id			= u4.id_padre
		LEFT JOIN unidad u2					ON u2.id			= u3.id_padre
		WHERE
		a.fecha 		BETWEEN pdia_i AND pdia_f																AND
		e.id 			= pid_campus 																				AND
		c.id_local 	= CASE WHEN IFNULL(pid_locac, 0)=0 THEN c.id_local ELSE pid_locac END 	AND
		u4.id	= CASE WHEN IFNULL(pid_carr, 0) = 0 THEN f.id_unidad 	ELSE pid_carr 	END 		AND
		u3.id = CASE WHEN IFNULL(pid_esc, 0) = 0 	THEN u3.id 			ELSE pid_esc 	END 		AND
		u2.id = CASE WHEN IFNULL(pid_prog, 0) = 0 THEN u2.id 			ELSE pid_prog 	END 		AND
		( b.justificar <> 1 OR ( IFNULL(min_dife_a,0) >=IFNULL(min_dife,0) AND IFNULL(min_difs_a,0) >=IFNULL(min_difs,0) ) ) AND
		a.estado 	= 1
	) AS EstadoA
	GROUP BY EstAsistencia
	ORDER BY EstAsistencia;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_tar_proceso_calculo_3_alumnos_insert`(
IN `inIdPeriodoLab` INT)
BEGIN
	SET @validar=0;
	select @validar:=count(id) from tar_proceso_calculo_3_alumnos where id_periodo_laboral = inIdPeriodoLab ;
	if (@validar =0) THEN
		insert into  tar_proceso_calculo_3_alumnos (tpc_id, id_periodo_laboral,id_cursos_programado, id_docente,matd_id,id_alumno, alumno)
		select tpc_id, id_periodo_laboral,id_cursos_programado, id_docente,matd_id,id_alumno, alumno from vw_tareo_calc_por_curso_docente_pl
		where id_periodo_laboral = inIdPeriodoLab ;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_tar_proceso_calculo_3_insert`(
IN `inIdPeriodoLab` INT)
BEGIN
	SET @validar=0;
	select @validar:=count(id) from tar_proceso_calculo_3 where id_periodo_laboral = inIdPeriodoLab ;
	if (@validar =0) THEN
		insert into  tar_proceso_calculo_3 (id_periodo_laboral,periodo_lab, id_programa,programa,id_curso,curso,id_cursos_programado,id_docente, desc_docente, cant_horas, hrs_efec_pagar,min_tardanza, tarifa,monto, cant_alumnos)
		select id_periodo_laboral,periodo_lab, id_programa,programa,id_curso, curso,id_cursos_programado,id_docente, desc_docente, cant_horas, hrs_efec_pagar,min_tardanza, tarifa,monto , cant_alumnos
		from vw_tareo_calc_por_curso_id_curso_prog where id_periodo_laboral = inIdPeriodoLab;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`PA_tar_proceso_calculo_4_insert`(
IN `inIdPeriodoLab` INT)
BEGIN
	SET @validar=0;
	select @validar:=count(id) from tar_proceso_calculo_4 where id_periodo_laboral = inIdPeriodoLab ;
	if (@validar =0) THEN
		insert into  tar_proceso_calculo_4 (tpc3_id, id_periodo_laboral,periodo_lab,id_curso,curso,id_cursos_programado,desc_docente, id_docente, sede_id, n_sede,escuela, cant_alumnos_por_sede,monto_total, cant_alumnos_total,monto_total_sede)
		select tpc3_id, id_periodo_laboral,periodo_lab, id_curso, curso,id_cursos_programado,desc_docente, id_docente, id_sede , sede,escuela, cantidad_alumnos_por_sede,monto_total , cant_alumnos_total,monto_total_sede
		from vw_tar_proceso_calc_4_sede_escuela where id_periodo_laboral = inIdPeriodoLab;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`spIsertMatricula`(IN inidalumno int, IN inId_padre int, in inId_unidad int, IN inilocal int)
begin
	set @idCursoProg := (select distinct id from cursos_programados where id_padre = inId_padre and id_unidad = inId_unidad);
    set @varid_periodo := (select cp.id_periodo from cursos_programados cp where cp.id = @idCursoProg);
    set @varIdUnidad := (select cp.id_unidad from cursos_programados cp where cp.id = @idCursoProg);

    insert into matricula (id_periodo, id_alumno,
                           id_unidad, estado,
                           created_at, created_by, updated_at, updated_by)
    values (@varid_periodo, inidalumno, @varIdUnidad, '1', now(), '21553', now(), '21553');


    set @lastIdMatricula = (select last_insert_id() as lastidMatricula);

    insert into matricula_det (id_matricula, id_cursoprogramado, id_matricula_est, id_alumno, estado, created_at,
                               created_by, updated_at, updated_by)
    values (@lastIdMatricula, inId_padre, '1', inidalumno, '1', now(), '21553', now(), '21553');

    set @lastIdMatriculaDetalle = (select last_insert_id() as lastIdMatriculaDetalle);

    insert into matricula_det_comp(id_matricula_det, id_cursoprogramado, created_at, created_by, updated_at, updated_by)
    values (@lastIdMatriculaDetalle, inId_padre, now(), '21553', now(), '21553');


    set @varIdCiclo := (select id_ciclo_lectivo from periodos where id = @varid_periodo);

    set @varIdMalla := (select distinct md.id_malla
						from cursos_programados cp
						inner join mallas_det md on cp.id_malla_det=md.id
						inner join mallas ma on md.id_malla=ma.id
						where cp.id_padre = inId_padre and cp.id_unidad = inId_unidad and ma.estado=1);

    insert into admisiones (id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo, id_malla, id_tipo_admision,
                            orden, id_matricula_est, estado, created_at, created_by, updated_at,updated_by)
    values (inidalumno, @varIdUnidad, inilocal, @varIdCiclo, @varid_periodo, @varIdMalla, '5', '1', '1', 1,now(), 21553, now(), 21553);

    set @varIdAdmision := (select last_insert_id() as lastIdAdmision);

    insert into alumno_sesion_lect (id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo, id_malla, id_admision,
                                    id_matricula, id_matricula_est, created_at, created_by, updated_at, updated_by)

    values (inidalumno, @varIdUnidad, inilocal, @varIdCiclo, @varid_periodo, @varIdMalla, @varIdAdmision,
            @lastIdMatricula, '1', now(), '21553', now(), '21553');

    select @lastIdMatriculaDetalle as idMatDetalle;
end;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`spPollsDatosAlumnosEncuestas`(IN inUsers_id int, IN inPeriodo int,
                                                                  IN inPrograma int, IN inCursos_id int,
                                                                  IN inPollsId int, IN inquestions_id int,
                                                                  IN inSectionsId int, IN inAnswer int)
BEGIN
set @idAlumno := (select id from alumnos where id_user = inUsers_id);
set @idCarrera := (select siseacad.fn_GetIdCarreraAlumno(@idAlumno, inPrograma));
set @localAlumno := (select siseacad.fn_GetLocal(@idAlumno, @idCarrera));
set @sede := (select siseacad.fn_GetLocal(@idAlumno, @idCarrera));

set @carrera := (select siseacad.fn_GetCarreraAlumno(@idAlumno, inPrograma));
set @ciclo := (select siseacad.fn_GetCicloMatriculado(@idAlumno, @idCarrera, inPeriodo));
set @modulo := (select siseacad.fn_GetModulo(@idAlumno, @idCarrera));
set @turno := (select siseacad.fn_GetTurno(@idAlumno, @idCarrera, inPeriodo));
set @escuela := (select siseacad.fn_GetEscuela(@idCarrera));
#

set @pregunta := (select question from encuestas.questions where id = inquestions_id);
set @nombreAlumno := (select name from siseacad.users where id = inUsers_id);
set @curso := (select descripcion from encuestas.cursos_estatus where cursos_id = inCursos_id and polls_id = inPollsId and users_id =inUsers_id limit 1);
set @docente := (select docente from encuestas.cursos_estatus where cursos_id = inCursos_id and polls_id =inPollsId and users_id =inUsers_id limit 1 );
set @comentario :=(select comment from encuestas.comments where polls_id= inPollsId and users_id= inUsers_id and cursos_id = inCursos_id limit 1);


insert into encuestas.polls_studies_answers (users_id, cursos_id, polls_id, questions_id, sections_id, alumnos_id,
                                             periodo, answer, status, docente, pregunta, sede,
                                             escuela, ciclo, modulo, turno, carrera, created_at, nombreAlumno,
                                             curso , comentario)

values (inUsers_id, inCursos_id, inPOllsId, inQuestions_id, inSectionsId, @idAlumno, inPeriodo, inAnswer, '1',
        @docente, @pregunta, @sede, @escuela, @ciclo, @modulo, @turno, @carrera, now(), @nombreAlumno, @curso, @comentario);



END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`spResetEncuentaAlumno`(IN inPollsid int, In InUsers_id int )
BEGIN

    update encuestas.polls_asign_users pas
        set pas.estado  = 0
    where  pas.users_id = InUsers_id and pas.polls_id = inPollsid;

    delete from encuestas.polls_studies_answers  where users_id = InUsers_id and  polls_id = inPollsid;

    delete  from encuestas.comments  where polls_id = inPollsid  and users_id = InUsers_id;

    delete from encuestas.cursos_estatus where users_id = InUsers_id and polls_id = inPollsid;
end;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_Alumnos_ProgramaPendiente`(xidPrograma1 int, xidPrograma2 int, xPeriodoIni int, xPeriodoFin int)
BEGIN
	select distinct

		us.username as usuario,
		pe.nro_documento as dni,
		concat(pe.paterno,' ',pe.materno,' ',pe.nombres) as alumno,
		pe.telefono_movil,
		pe.telefono_fijo,
		pe.email,
		es.descripcion as escuela,
		ca.descripcion as carrera,
		fn_GetCicloMaximo(asl.id_alumno , asl.id_unidad) as ciclo,
		fn_GetLocal(asl.id_alumno , asl.id_unidad) as sede
	from alumnos al
	inner join persona pe on pe.id=al.id_persona
	inner join users us on al.id_user=us.id
	inner join alumno_sesion_lect asl on al.id=asl.id_alumno
	inner join unidad ca on asl.id_unidad=ca.id
	inner join unidad es on ca.id_padre=es.id
	inner join unidad pr on es.id_padre=pr.id
	where asl.id_periodo between xPeriodoIni and xPeriodoFin
	and fn_GetCicloMaximo(al.id, asl.id_unidad) > 1
	and pr.id = xidPrograma1
	and asl.id_alumno not in
	(
		select distinct asl.id_alumno
		from alumno_sesion_lect asl
		inner join unidad ca on asl.id_unidad=ca.id
		inner join unidad es on ca.id_padre=es.id
		inner join unidad pr on es.id_padre=pr.id
		where pr.id = xidPrograma2
	);
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_bd_ListarCursos_Notas`(xidPeriodo int)
BEGIN
	select distinct
		ma.id_alumno,
		concat('u', lpad(CAST(al.id AS CHAR), 8, '0')) as usuario,
		pa.nro_documento as dni,
		concat(pa.paterno,' ',pa.materno,' ',pa.nombres) as nomAlumno,
		es.descripcion as escuela,
		ca.descripcion as carrera,
		fn_GetLocal(ma.id_alumno,ma.id_unidad) as sede,
		'2202' as periodo,
		'2022' as anio,
		cu.descripcion as curso,
		fn_GetCicloMatriculado(ma.id_alumno,ma.id_unidad,ma.id_periodo) as ciclo,
		fn_GetTurno(ma.id_alumno, ma.id_unidad, xidPeriodo) as turno,
		md.promedio_final as promedio
	from matricula ma
	inner join matricula_det md on ma.id=md.id_matricula
	inner join cursos_programados cp on md.id_cursoprogramado=cp.id
	inner join mallas_det mt on cp.id_malla_det=mt.id
	inner join cursos cu on mt.id_curso=cu.id
	inner join horarios ho on cp.id=ho.id_cursoprogramado
	inner join docentes do on ho.id_docente=do.id
	inner join persona pe on do.id_persona=pe.id
	inner join alumnos al on ma.id_alumno=al.id
	inner join persona pa on al.id_persona=pa.id
	inner join unidad ca on ma.id_unidad=ca.id
	inner join unidad es on ca.id_padre=es.id
	inner join mallas ms on mt.id_malla=ms.id
	where ma.estado=1
	and ma.id_periodo=xidPeriodo
	and md.id_matricula_est=1
	and do.id <> 556;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_bd_ListarNotas_Parciales`(xidPeriodo int)
BEGIN
	select distinct
		asl.id_alumno,
		asl.id_unidad,
		concat('u', lpad(CAST(al.id AS CHAR), 8, '0')) as usuario,
		concat(pe.paterno,' ',pe.materno,' ',pe.nombres) as nombre,
		es.descripcion as escuela,
		ca.descripcion as carrera,
		fn_GetCicloMaximo(asl.id_alumno, asl.id_unidad) as ciclo,
		fn_GetLocal(asl.id_alumno, asl.id_unidad) as sede,
		fn_GetTurno(asl.id_alumno, asl.id_unidad, xidPeriodo) as turno,
		concat(per.paterno,' ',per.materno,' ',per.nombres) as docente,
		cu.descripcion as curso,
		nd.nota
	from alumno_sesion_lect asl
	inner join unidad ca on asl.id_unidad=ca.id
	inner join unidad es on ca.id_padre=es.id
	inner join alumnos al on asl.id_alumno=al.id
	inner join persona pe on al.id_persona=pe.id
	inner join users us on al.id_user=us.id
	inner join matricula ma on asl.id_matricula=ma.id and ma.id_periodo=xidPeriodo
	inner join matricula_det md on ma.id=md.id_matricula
	inner join cursos_programados cp on md.id_cursoprogramado=cp.id
	inner join mallas_det mdt on cp.id_malla_det=mdt.id
	inner join cursos cu on mdt.id_curso=cu.id
	inner join notas_detalle nd on cp.id=nd.id_cursoprogramado and nd.id_alumno=asl.id_alumno
	inner join horarios ho on cp.id=ho.id_cursoprogramado and ho.activo=1 and ho.estado=1
	inner join docentes do on ho.id_docente=do.id
	inner join persona per on do.id_persona=per.id
	where asl.id_periodo = xidPeriodo
	and fn_GetCicloMaximo(asl.id_alumno, asl.id_unidad) = 1
	and nd.id_tipoevaluacion=1
	and cp.estado=1
	and md.id_matricula_est=1
	order by asl.id_alumno, cu.descripcion;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_DatosBasicos_AlumnoMatricula`(in xCorreo varchar(50), in xIdPeriodo int)
BEGIN
select DISTINCT  u.name as nombre, u3.descripcion as escuela, u2.descripcion as carrera, s.desc_larga as sede, m.created_at as fecha_matricula
from users u
inner join alumnos a on a.id_user  = u.id
inner join matricula m on m.id_alumno = a.id
inner join alumno_sesion_lect asl on asl.id_matricula = m.id and asl.id_periodo = m.id_periodo
inner join admisiones a2 on a2.id = asl.id_admision
inner join unidad u2 on u2.id = a2.id_unidad
inner join unidad u3 on u3.id = u2.id_padre
inner join sedes s on s.id = a2.id_local
where
 u.email = xCorreo and m.id_periodo = xIdPeriodo;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`Sp_insertAlumno`(IN incodigo varchar(20), IN inpaterno varchar(25),
                                                     IN inmaterno varchar(25), IN innombres varchar(50),
                                                     IN inidtiopo_documento varchar(4), IN innrodocumento varchar(20),
                                                     IN infecha date, IN inemail varchar(90), IN insexo varchar(1),
                                                     IN indireccion varchar(300), IN inreferencia varchar(100),
                                                     IN inunbigeo char(6), IN inntelefono_movil varchar(15),
                                                     IN invalida char, IN inclave varchar(250),
                                                     IN clavealeatoria varchar(250), in inIdAlumno int)
BEGIN
	set @lastInsertIdUsers = 0;
	set @lastInsertIdPersona = 0;
	set @newusername = '';
	set @idTmp = 0;
	set @nomCompleto := (select concat(inpaterno,' ',inmaterno,' ',innombres));

	if inIdAlumno = 0 then

	    insert into users(name, username, email, password, status, created_at, updated_at)
	    values (@nomCompleto, innrodocumento, clavealeatoria, inclave, 1,now(), now());

	    set @lastInsertIdUsers := (select last_insert_id() as lastid);

	    set @idTmp := (select max(id)+1 from tmp);
		insert into tmp values(@idTmp,@lastInsertIdUsers,clavealeatoria,now(),now());

	    insert into persona (codigo, paterno, materno, nombres, id_tipo_documento,
	                         nro_documento, fecnac, email, sexo,
	                         direccion, referencia, ubigeo, telefono_movil,
	                         created_at, created_by, updated_at, updated_by, estado_civil)
	    values (incodigo, inpaterno, inmaterno, innombres, inidtiopo_documento,
	            innrodocumento, infecha, inemail, insexo,
	            indireccion, inreferencia, inunbigeo, inntelefono_movil,
	            now(), '10166', now(), '10166', 'S');
	    set @lastInsertIdPersona := (select last_insert_id() as lasti);

	   	insert into persona_actualiza (codigo, paterno, materno, nombres, id_tipo_documento,
	                                   nro_documento, fecnac, email, sexo,
	                                   direccion, referencia, ubigeo, telefono_movil,
	                                   created_at, created_by, updated_at, updated_by, estado_civil, valida, id_persona)
	    values (incodigo, inpaterno, inmaterno, innombres, inidtiopo_documento,
	            innrodocumento, infecha, inemail, insexo,
	            indireccion, inreferencia, inunbigeo, inntelefono_movil,
	            now(), '10166', now(), '10166', 'S', invalida, @lastInsertIdPersona);

		insert into model_has_roles (role_id, model_type, model_id)
		values ('3','App\\User' ,@lastInsertIdUsers);

		insert into alumnos (id_persona, id_user, estado, created_at, created_by, updated_at, updated_by)
		values (@lastInsertIdPersona, @lastInsertIdUsers, '1', now(), '10166', now(), '10166');

		set @lastIAlumno := (select last_insert_id() as lastidalumno);
		set @newusername := (select concat('u', lpad(CAST(@lastIAlumno AS CHAR), 8, '0')));
		set @correoSise := (select concat(@newusername,'@sise.com.pe'));

		update users
		set username = @newusername, email=@correoSise
		where id = @lastInsertIdUsers;
	else
		set @lastIAlumno := inIdAlumno;
		set @lastInsertIdPersona := (select id_persona from alumnos where id = inIdAlumno);

		update persona
		set codigo = incodigo,
			paterno = inpaterno,
			materno = inmaterno,
			nombres = innombres,
			id_tipo_documento = inidtiopo_documento,
			nro_documento = innrodocumento,
			fecnac = infecha,
			email = inemail,
			sexo = insexo,
			direccion = indireccion,
			referencia = inreferencia,
			ubigeo = inunbigeo,
			telefono_movil = inntelefono_movil
		where id = @lastInsertIdPersona;
	end if;

	select al.id as idAlumno,
	    		u.id,
	           u.username,
	           ut.key as password,
	           p.nombres,
	           p.paterno,
	           p.materno,
	           p.email,
	           p.id           as idpersona,
	           al.created_at
	 from alumnos al
	             inner join users u on u.id = al.id_user
	             inner join persona p on al.id_persona = p.id
	             inner join tmp ut on u.id = ut.user_id
	 where al.id = @lastIAlumno;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_ListarRetirados_Egresados`(xTipo varchar(10), xPrograma int, xPeriodoIni int, xPeriodoFin int)
BEGIN
	select distinct B.*, per.desc_corta as Periodo, cl.identificador as Anio
	from
		(select A.id_alumno,
			A.Usuario,
			A.TipoDocumento,
			A.Nro_documento,
			A.Paterno,
			A.Materno,
			A.Nombres,
			DATE_FORMAT(A.fecNac, '%d/%m/%Y') as FecNac,
			A.Sexo,
			A.Direccion,
			A.Email,
			A.Telefono_fijo as Telf1,
			A.telefono_movil as Telf2,
			A.Escuela,
			A.Carrera,
			max(A.id_periodo) as IdPeriodo,
			A.Sede
		from (
			select distinct
			asl.id_alumno,
			asl.id_unidad,
			concat('u', lpad(CAST(al.id AS CHAR), 8, '0')) as usuario,
			td.des_corta as TipoDocumento,
			pe.nro_documento,
			pe.paterno,
			pe.materno,
			pe.nombres,
			pe.fecnac,
			pe.sexo,
			pe.direccion,
			pe.email,
			pe.telefono_fijo,
			pe.telefono_movil,
			es.descripcion as escuela,
			ca.descripcion as carrera,
			asl.id_periodo,
			fn_GetLocal(asl.id_alumno, asl.id_unidad) as Sede
			from alumno_sesion_lect asl
			inner join unidad ca on asl.id_unidad=ca.id
			inner join unidad es on ca.id_padre=es.id
			inner join alumnos al on asl.id_alumno=al.id
			inner join persona pe on al.id_persona=pe.id
			inner join users us on al.id_user=us.id
			inner join admisiones ad on asl.id_admision=ad.id
			inner join tipo_documento td on pe.id_tipo_documento=td.id
			where es.id_padre = xPrograma
			and fn_GetCondicionAlumno(asl.id_alumno,asl.id_unidad) = xTipo
			and ad.estado=1
			) A
		group by A.id_alumno,A.id_unidad,A.usuario,A.TipoDocumento,A.nro_documento,A.Paterno,A.Materno,
			A.Nombres,A.FecNac,A.Sexo,A.Direccion,A.email,A.telefono_fijo,A.telefono_movil,A.escuela,A.carrera,A.sede
		) B
	inner join periodos per on B.IdPeriodo=per.id
	inner join ciclo_lectivo cl on per.id_ciclo_lectivo=cl.id
	where B.IdPeriodo between xPeriodoIni and xPeriodoFin;


END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_Listar_CicloLectivo`(xTipo varchar(20), xPrograma int)
BEGIN
	if xTipo = 'completo' then
		select id, desc_larga as nombre
		from ciclo_lectivo
		where estado = 1 and id_unidad=xPrograma
		order by 1 desc;
	else
		select id, identificador as nombre
		from ciclo_lectivo
		where estado=1
		and id_unidad=xPrograma
		and year(fec_ini) >= year(DATE_ADD(curdate(), INTERVAL -1 YEAR))
		order by 1 desc;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_Matriculados_DatosPersonales`(xidPeriodo int, xidSede int)
BEGIN
	select distinct

	us.username as Usuario,
	pa.nro_documento as DNI,
	concat(pa.paterno,' ',pa.materno,' ',pa.nombres) as Alumno,
	date_format(pa.fecnac, "%d-%m-%Y") as FecNac,
	pa.Sexo,
	concat(pa.telefono_movil,' / ',pa.telefono_fijo) as Telefono,
	pa.Email,
	ub.Distrito,
	pa.Direccion,
	es.descripcion as Escuela,
	ca.descripcion as Carrera,
	fn_GetCicloMatriculado(ma.id_alumno,ma.id_unidad,ma.id_periodo) as Ciclo,

	fn_GetModulo(ma.id_alumno,ma.id_unidad) as Modulo,
	fn_GetLocal(ma.id_alumno,ma.id_unidad) as Sede
	from matricula ma
	inner join matricula_det md on ma.id=md.id_matricula
	inner join cursos_programados cp on md.id_cursoprogramado=cp.id
	inner join mallas_det mt on cp.id_malla_det=mt.id
	inner join cursos cu on mt.id_curso=cu.id
	inner join horarios ho on cp.id=ho.id_cursoprogramado
	inner join docentes do on ho.id_docente=do.id
	inner join alumnos al on ma.id_alumno=al.id
	inner join persona pa on al.id_persona=pa.id
	inner join unidad ca on ma.id_unidad=ca.id
	inner join unidad es on ca.id_padre=es.id
	inner join users us on al.id_user=us.id
	inner join ubigeo ub on pa.ubigeo=ub.ubigeo
	where ma.estado=1
	and do.id <> 556
	and ma.id_periodo = xidPeriodo
	and (fn_GetidLocal(ma.id_alumno,ma.id_unidad)=xidSede or xidSede=99);

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_Matricula_Extemporanea`(idPeriodo int, idCurso int, idAlumno int, nomAlumno varchar(100))
BEGIN
	set @xIdAlumno := idAlumno;

	if nomAlumno <> '' then
		set @xIdAlumno := (select al.id
							from persona pe
							inner join alumnos al on pe.id=al.id_persona
							where concat(pe.paterno,' ',pe.materno,' ',pe.nombres)=nomAlumno);
	end if;

	set @contarMatriculas := (select count(*) from matricula where id_alumno=@xIdAlumno and id_periodo=idPeriodo);

	if @contarMatriculas = 0 then
		select @xIdAlumno as SinMatricula;
	elseif @contarMatriculas > 1 then
		select @xIdAlumno as DobleMatricula;
	else
		set @idMatricula := (select id from matricula where id_alumno=@xIdAlumno and id_periodo=idPeriodo);

		set @idMatDetalle := (select id from matricula_det
							where id_matricula=@idMatricula and id_alumno=@xIdAlumno and id_cursoprogramado=idCurso);

		if @idMatDetalle is null then
			insert into matricula_det
			(id_matricula,id_cursoprogramado,id_alumno,id_matricula_est,fec_retiro,estado,created_at,created_by,updated_at,updated_by)
			values(@idMatricula,idCurso,@xIdAlumno,1,now(),1,now(),10166,now(),10166);

			set	@idMatDetalle := (select LAST_INSERT_ID());

			insert into matricula_det_comp
			(id_matricula_det,id_cursoprogramado,created_at,created_by,updated_at,updated_by)
			values(@idMatDetalle,idCurso,now(),10166,now(),10166);
		else
			select @xIdAlumno as YaMatriculado;
		end if;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_PeriodoAlumno_upd`(xidAlumno int, xidPeriodoAnt int, xidPeriodoNew int)
BEGIN

	declare var_idCicloLectivo int;
	declare var_idMatriculaDet int;
	DECLARE var_final int DEFAULT 0;

	DECLARE cursor1 CURSOR FOR
  		select md.id
		from matricula m
		inner join matricula_det md on m.id = md.id_matricula
		where m.id_alumno = xidAlumno and m.id_periodo = xidPeriodoAnt;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_final = 1;


	delete from matricula_det_comp
	where id_matricula_det in
	(
		select md.id
		from matricula m
		inner join matricula_det md on m.id = md.id_matricula
		where m.id_alumno = xidAlumno and m.id_periodo = xidPeriodoAnt
	);

	set var_idCicloLectivo := (select id_ciclo_lectivo from periodos where id = xidPeriodoNew);

	update matricula
	set id_periodo = xidPeriodoNew
	where id_alumno = xidAlumno and id_periodo = xidPeriodoAnt;

	update alumno_sesion_lect
	set id_periodo = xidPeriodoNew, id_ciclo_lectivo=var_idCicloLectivo
	where id_alumno = xidAlumno and id_periodo = xidPeriodoAnt;

	update admisiones
	set id_periodo = xidPeriodoNew, id_ciclo_lectivo=var_idCicloLectivo
	where id_alumno = xidAlumno and id_periodo = xidPeriodoAnt and estado=1;


	OPEN cursor1;
	bucle: LOOP

    FETCH cursor1 INTO var_idMatriculaDet;

    IF var_final = 1 THEN
      LEAVE bucle;
    END IF;

   	delete from matricula_det where id = var_idMatriculaDet;

  	END LOOP bucle;
  	CLOSE cursor1;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_RptMatriculados_SCL`(xTipo varchar(15), xPeriodoIni int, xPeriodoFin int)
BEGIN
	if xTipo = 'notas' then
		select distinct
			A.periodo as 'Ciclo Lectivo',
			A.Campus,
			A.Turno,
			'' as 'Abreviatura de Programa Academico',
			A.NombrePrograma as 'Descripcion completa del Programa Academico',
			'' as 'Abreviatura de Plan Academico',
			A.NombrePlan as 'Descripcion completa del Plan Academico',
			A.Ciclo,
			mt.id_curso as 'Id Curso',
			'' as 'Catalogo de Curso',
			cu.descripcion as 'Nombre del Curso',
			mt.Creditos as 'Creditos',
			md.promedio_final as 'Calificacion Final',
			'' as 'Numero de Clase',
			'' as 'Seccion',
			concat(pe.paterno,' ',pe.materno,' ',pe.nombres) as Docente,
			A.usuario as 'CodActualAlumno',
			'' as 'CodAntiguoAlumno',
			A.TipoDoc as 'Tipo de documento de identidad de Alumno',
			A.DniAlumno as 'Numero de documento de identidad del Alumno',
			A.NombresAlumno as 'Nombres de Alumno',
			A.ApellidosAlumno as 'Apellidos del Alumno',
			A.FechaNacimiento as 'Fecha de Nacimiento',
			A.Sexo,
			'No' as 'Tiene discapacidad',
			A.idAlumno,
			A.idEscuela,
			A.idCarrera
		from (
			select distinct
			fn_GetNombreMes(month(pe.fec_ini)) as periodo,
			vm.usuario,
			fn_GetLocal(vm.id_alumno,vm.id_unidad) as Campus,
			vm.dni as DniAlumno,
			if(length(vm.dni) = 8, 'D.N.I','CARNET DE EXTRANJERIA') as TipoDoc,
			vm.SoloApellidos as ApellidosAlumno,
			vm.SoloNombres as NombresAlumno,
			date_format(vm.fecnac, "%Y-%m-%d") as FechaNacimiento,
			vm.Sexo,
			vm.escuela as NombrePrograma,
			vm.NombreMalla as NombrePlan,
			vm.id_alumno as idAlumno,
			vm.id_escuela as idEscuela,
			vm.id_unidad as idCarrera,
			fn_GetCicloMatriculado(vm.id_alumno,vm.id_unidad,vm.id_periodo) as ciclo,
			fn_GetTurno(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Turno,
			vm.id_Matricula as idMatricula
			from vw_matriculados vm
			inner join horarios ho on ho.id_cursoprogramado=vm.idclase
			inner join docentes do on ho.id_docente=do.id
			inner join periodos pe on vm.id_periodo=pe.id
			where vm.estMatricula=1
			and vm.id_periodo between xPeriodoIni and xPeriodoFin
			and do.id <> 556
		) A
		inner join matricula ma on A.idMatricula=ma.id
		inner join matricula_det md on ma.id=md.id_matricula
		inner join cursos_programados cp on md.id_cursoprogramado=cp.id
		inner join mallas_det mt on cp.id_malla_det=mt.id
		inner join cursos cu on mt.id_curso=cu.id
		inner join horarios ho on cp.id=ho.id_cursoprogramado
		inner join docentes do on ho.id_docente=do.id
		inner join persona pe on do.id_persona=pe.id
		where do.id <> 556;
	else
		select distinct ma.id_alumno as idAlumno, ma.id_unidad as idCarrera
		from matricula ma
		inner join matricula_det md on ma.id=md.id_matricula
		inner join cursos_programados cp on md.id_cursoprogramado=cp.id
		inner join horarios ho on cp.id=ho.id_cursoprogramado
		inner join docentes do on ho.id_docente=do.id
		inner join alumnos al on ma.id_alumno=al.id
		inner join persona pa on al.id_persona=pa.id
		inner join unidad ca on ma.id_unidad=ca.id
		inner join unidad es on ca.id_padre=es.id
		inner join mallas ms on ma.id_unidad=ms.id_unidad
		inner join users us on al.id_user = us.id
		inner join periodos pe on ma.id_periodo=pe.id
		where ma.estado=1
		and ma.id_periodo between xPeriodoIni and xPeriodoFin
		and do.id <> 556;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_SubirNotas_Virtuales`(xIdAlumno int, xIdCursoProg int, xPromedio int)
BEGIN
	set @x := (select count(1) from actas where id_cursoprogramado=xIdCursoProg);

	if @x = 0 then
		set @NumActa := (select max(nro_acta) + 1 as num from actas);

		insert into actas (id_cursoprogramado,version,nro_acta,estado,fecha_cierre,created_at,created_by,updated_at)
		values(xIdCursoProg,1,@NumActa,1,now(),now(),10166,now());
	end if;

	if (select count(1) from actas_det where id_cursoprogramado=xIdCursoProg and id_alumno=xIdAlumno) = 0 then
		insert into actas_det (id_cursoprogramado,version,id_alumno,nota,created_at,created_by,updated_at)
		values(xIdCursoProg,1,xIdAlumno,xPromedio,now(),10166,now());
	else
		update actas_det
		set nota = xPromedio
		where id_cursoprogramado=xIdCursoProg and id_alumno=xIdAlumno;
	end if;

	delete from notas_detalle where id_alumno=xIdAlumno and id_cursoprogramado=xIdCursoProg;

	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 1, 1, xPromedio);
	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 2, 1, xPromedio);
	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 3, 1, xPromedio);
	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 3, 2, xPromedio);
	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 3, 3, xPromedio);
	call sp_SubriNotas_Virtuales_Detalle(xIdAlumno, xIdCursoProg, 3, 4, xPromedio);

	update matricula_det
	set promedio_final=xPromedio
	where id_alumno=xIdAlumno and id_cursoprogramado=xIdCursoProg;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_SubriNotas_Virtuales_Detalle`(xidAlumno int, xIdCursoProg int, xTipo int, xNumEval int, xNota int)
BEGIN
	set @idFormula := (select md.id_formula
					from cursos_programados cp
					inner join mallas_det md on cp.id_malla_det=md.id
					where cp.id=xIdCursoProg);

	insert into notas_detalle (id_cursoprogramado,id_alumno,id_formula,id_tipoevaluacion,nro_evaluacion,nota,nodio,created_at,created_by,updated_at,updated_by)
	values(xIdCursoProg,xidAlumno,@idFormula,xTipo,xNumEval,xNota,0,now(),10166,now(),10166);
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_TempoMigracion`(xIdAlumnoNuevo int, xIdAlumnoValido int)
BEGIN
	insert into alumnos (id, id_persona, id_user, estado, created_at, created_by, updated_at, updated_by)
	select xIdAlumnoValido, id_persona, id_user, estado, now(), created_by, now(), updated_by
	from alumnos
	where id = xIdAlumnoNuevo;

	set @username := (select concat('u', lpad(CAST(xIdAlumnoValido AS CHAR), 8, '0')));

	update users
	set username=@username, email=concat(@username,'@sise.com.pe')
	where id in (select id_user from alumnos where id = xIdAlumnoNuevo);

	update alumno_sesion_lect
	set id_alumno = xIdAlumnoValido
	where id_admision in (select id from admisiones where id_alumno=xIdAlumnoNuevo);

	update admisiones
	set id_alumno = xIdAlumnoValido
	where id_alumno in (select id from alumnos where id = xIdAlumnoNuevo);

	update matricula_det
	set id_alumno = xIdAlumnoValido
	where id_matricula in (select id from matricula where id_alumno = xIdAlumnoNuevo);

	update matricula
	set id_alumno = xIdAlumnoValido
	where id_alumno = xIdAlumnoNuevo;

	delete from alumnos where id=xIdAlumnoNuevo;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`sp_ValidarExiste_idAlumno`(in xidAlumno int, in xNombres varchar(250))
BEGIN
	set @rpta := 'ok';

	if (select count(1) from alumnos where id = xidAlumno) = 0 then
		set @rpta := 'limpiar';
	else
		if (select count(1) from persona where concat(paterno,' ',materno,' ',nombres)=xNombres) = 0 then
			set @rpta := 'conflicto';
		end if;
	end if;

	select @rpta;
END;

CREATE DEFINER=`root`@`%` PROCEDURE `siseacad`.`test`()
begin

DECLARE xidAlumno INT;
DECLARE xidUnidad INT;
DECLARE xidLocal INT;


DECLARE done INT DEFAULT FALSE;
DECLARE cur CURSOR FOR
    SELECT p.id_alumno, p.id_sede, u.id as id_unidad
    FROM presise p
    INNER JOIN unidad u ON u.descripcion = p.carrera;


DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;


OPEN cur;


loop_cursor: LOOP

    FETCH cur INTO xidAlumno, xidLocal, xidUnidad;


    IF done THEN
        LEAVE loop_cursor;
    END IF;


    CALL usp_Matricula_PreSise_ins(xidAlumno, xidUnidad, xidLocal);
	UPDATE presise set ya =1
   	where id_alumno =xidAlumno and id_sede= xidLocal;
END LOOP;


CLOSE cur;
end;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`ufn_TEMPO_EliminarClases`(xidCursoProg int)
BEGIN

delete from asistencia_alumnos
where id_sesion in (select id from sesiones
	where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg));

delete from marcaciones
where id_sesion in (select id from sesiones
	where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg));

delete from sesiones where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

delete from matricula_det_comp where id_cursoprogramado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

delete from matricula_det where id_cursoprogramado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

delete from horarios where id_cursoprogramado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

delete from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_convalidacion_existe`(xidAlumno int, xidCarrera int, xidPeriodo int)
BEGIN
	set @idConvalidacion := (select co.id
							from admisiones ad
							inner join convalidaciones co on ad.id = co.id_admision
							where ad.id_alumno=xidAlumno
							and ad.id_unidad=xidCarrera
							and ad.id_periodo=xidPeriodo
							and ad.id_motivo_accion=8
							and ad.estado=0
							and co.estado=1);

	if @idConvalidacion is null then
		set @idConvalidacion := 0;
	end if;

	select @idConvalidacion as idConvalidacion;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_convalida_inicios`(in xTipo varchar(10), in xidPeriodo int, in xidUnidad int)
BEGIN
	if xTipo = 'carrera' then
		select distinct p.id, p.id_ciclo_lectivo, cl.desc_corta as cicloLectivo, p.desc_corta as programa,
		DATE_FORMAT(p.fec_ini, '%d-%m-%Y') as fecIni, DATE_FORMAT(p.fec_fin, '%d-%m-%Y') as fecFin
		from periodos p
		inner join ciclo_lectivo cl on p.id_ciclo_lectivo = cl.id
		where p.id = xidPeriodo;
	else
		select distinct p.id, p.id_ciclo_lectivo, cl.desc_corta as cicloLectivo, p.desc_corta as programa,
		DATE_FORMAT(p.fec_ini, '%d-%m-%Y') as fecIni, DATE_FORMAT(p.fec_fin, '%d-%m-%Y') as fecFin
		from periodos p
		inner join ciclo_lectivo cl on p.id_ciclo_lectivo = cl.id
		where cl.id_unidad = xidUnidad
		and p.fec_ini >= DATE_ADD(p.fec_ini, INTERVAL -3 MONTH)
		and CURDATE() <= p.fec_fin_mat_r
		and cl.desc_corta like '%migra%';
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_convalida_ins_cab`(in xidAlumno int,
																			in xidUnidad int,
																			in xidLocal int,
																			in xidPeriodo int,
																			in xidCurso int,
																			in xidMalla int,
																			in xTemporada varchar(20))
BEGIN
	set @idConvalidacion := -1;

	set @contar := (select count(*)
						from cursos_programados cp
						inner join mallas_det md on cp.id_malla_det=md.id
						inner join mallas ma on md.id_malla=ma.id
						where md.id_curso=xidCurso and cp.id_unidad=xidUnidad and ma.estado=1);

	if @contar > 1 then


		set @orden := (select IFNULL(max(orden)+1,1) from admisiones where id_alumno = xidAlumno);
		set @idCicloLect := (select id_ciclo_lectivo from periodos where id = xidPeriodo);

		insert into admisiones (id_alumno,id_unidad,id_local,id_ciclo_lectivo,id_periodo,id_malla,
		id_tipo_admision,orden,id_matricula_est,id_motivo_accion,estado,created_at,created_by,updated_at,updated_by)
		values(xidAlumno,xidUnidad,xidLocal,@idCicloLect,xidPeriodo,xidMalla,5,@orden,1,8,0,now(),10166,now(),10166);

		set @idAdmision := (select last_insert_id());

		insert into convalidaciones(id_admision,id_unidad,id_malla,referencia,estado,created_at,created_by,updated_at,updated_by)
		values (@idAdmision,xidUnidad,xidMalla,xTemporada,1,now(),10166,now(),10166);

		set @idConvalidacion := (select last_insert_id());

		insert into alumno_sesion_lect(id_alumno,id_unidad,id_local,id_ciclo_lectivo,id_periodo,id_malla,id_admision,
					referencia,id_matricula_est,created_at,created_by,updated_at,updated_by)
		values(xidAlumno,xidUnidad,xidLocal,@idCicloLect,xidPeriodo,xidMalla,@idAdmision,"MIGRACION (Reg.xConv, sin detalle matricula)",1,now(),10166,now(),10166);
	end if;

	select @idConvalidacion;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_convalida_ins_det`(in xidMalla int,
												in xidUnidad int,
												in xidConvalidacion int,
												in xidCurso int,
												in xNota decimal(5,2))
BEGIN
	set @idMalla := 0;
	set @rpta := 0;
	set @contar := (select count(*)
						from cursos_programados cp
						inner join mallas_det md on cp.id_malla_det=md.id
						inner join mallas ma on md.id_malla=ma.id
						where md.id_curso=xidCurso and cp.id_unidad=xidUnidad and ma.estado=1);

	if @contar > 1 then
		if xidMalla = 0 then
			set @idMalla := (select distinct md.id_malla
						from cursos_programados cp
						inner join mallas_det md on cp.id_malla_det=md.id
						inner join mallas ma on md.id_malla=ma.id
						where md.id_curso=xidCurso and cp.id_unidad=xidUnidad and ma.estado=1);
		else
			set @idMalla := xidMalla;
		end if;

		set @existeCurso := (select count(1) from mallas_det where id_curso = xidCurso and id_malla = @idMalla);
		set @rpta := 0;

		IF @existeCurso > 0 THEN
			set @idMallaDet := (select id from mallas_det where id_curso = xidCurso and id_malla = @idMalla);
			set @existeConvDet := (select count(1) from convalidaciones_det
							where id_convalidacion=xidConvalidacion and id_malla_det_des=@idMallaDet);

			if @existeConvDet = 0 then
				insert into convalidaciones_det(id_convalidacion,id_malla_det_des,nota,vez,estado,created_at,created_by,updated_at,updated_by)
				values(xidConvalidacion,@idMallaDet,xNota,1,1,now(),10166,now(),10166);
			else
				update convalidaciones_det
				set nota=xNota, updated_at=now(), updated_by=10166
				where id_convalidacion=xidConvalidacion and id_malla_det_des=@idMallaDet;
			end if;

			set @rpta := xidCurso;
		END IF;
	end if;

	select @rpta as rpta;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_En_EnviaAlumnos`(in xCursoProgramado int(11))
BEGIN
	select * from vw_En_EnviaAlumnos where id = xCursoProgramado;

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_horario_upd`(
in xid int,
in xfec_ini date,
in xfec_fin date
)
BEGIN
	UPDATE cursos_programados SET
	fec_ini = xfec_ini,
	fec_fin = xfec_fin
	WHERE id_periodo = xid;

	UPDATE horarios SET
	fecha_ini = xfec_ini,
	fecha_fin = xfec_fin
	WHERE id_cursoprogramado IN (SELECT cp.id from cursos_programados cp inner join periodos p on cp.id_periodo = p.id where cp.id_periodo = xid);

	UPDATE periodos SET
	fec_ini = xfec_ini,
	fec_ini_hab_a = xfec_ini,
	fec_ini_hab_d = xfec_ini,
	fec_fin = xfec_fin,
	fec_fin_hab_a = xfec_fin,
	fec_fin_hab_d = xfec_fin
	WHERE id = xid;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Listar_Inicios`(in xTipo varchar(10), in xidUnidad int, in xCiclo int, in xPeriodo int)
BEGIN
	if xTipo = 'carrera' then
		select distinct gi.id, pe.id as idPeriodo, pe.desc_corta as periodo,
			concat(gi.ciclo,' - ',tu.turno,' - ',se.desc_corta,' | ',gi.descripcion) as cicloTurno,
			pe.fec_ini
		from grupos_inicio gi
		inner join periodos pe on gi.id_periodo = pe.id
		inner join grupos_inicio_det gid on gi.id = gid.id_grupo_inicio
		inner join cursos_programados cp on gid.id_curso_programado = cp.id
		inner join mallas_det md on cp.id_malla_det = md.id
		inner join turno tu on gi.id_turno=tu.id
		inner join sedes se on gi.id_campus=se.id
		where gi.id_unidad = xidUnidad
		and md.ciclo = xCiclo
		and pe.id = xPeriodo
		and gi.estado = 1
		and pe.fec_fin_mat_r >= CURDATE();

	else
		SELECT distinct A.id, A.idPeriodo, A.fecIni, A.hora, A.nomCurso, A.ciclo,
			(select turno from grupo_hora_det where id=max(A.idTurno)) as Turno
		FROM (
		select distinct cp.id_padre as id, p.id as idPeriodo, DATE_FORMAT(h.fecha_ini, '%d-%m-%Y') as fecIni,
				GetHorario(cp.id,0) as hora, concat(c.descripcion,' | ',se.desc_corta) as nomCurso, md.ciclo,
				ghd.id as idTurno
				from cursos_programados cp
				inner join mallas_det md on cp.id_malla_det = md.id
				inner join horarios h on cp.id = h.id_cursoprogramado
				inner join cursos c on md.id_curso = c.id
				inner join periodos p on cp.id_periodo = p.id
				inner join sedes se on h.id_local=se.id
				inner join grupo_hora_det ghd on h.hora_ini=ghd.rotulo_hr
				where h.estado = 1 and cp.estado = 1 and h.activo = 1
				and cp.fec_ini >= DATE_ADD(CURDATE(), INTERVAL -6 MONTH)
				and CURDATE() <= p.fec_fin_mat_r
				and cp.id_padre in (select distinct id_padre from cursos_programados where id_unidad = xidUnidad)
		) A
		group by A.id, A.idPeriodo, A.fecIni, A.hora, A.nomCurso, A.ciclo;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Listar_Matriculados`(xTipo varchar(20), xidSede int, xidPeriodo int, xUserMatricula varchar(2))
BEGIN
	if xTipo = 'xCurso' then
		select DISTINCT
			vm.Id_alumno,
			vm.Usuario,
			vm.Nombre,
			vm.Est,
			vm.Sede,
			vm.Escuela,
			vm.Carrera,
			'' as Grupo_Inicio,
			vm.Curso,
			getHorario(vm.id_padre, 0) as Horario,
			fn_GetDocente(vm.id_padre) as Docente,
			vm.id_padre,
			vm.idclase,
			UsuReg,
			Perfil
		from vw_matriculados vm
		where (vm.id_sede=xidSede or xidSede=99) and vm.id_periodo = xidPeriodo;

	else
		if xUserMatricula = 'no' then
			select DISTINCT
				vm.Id_alumno,
				vm.Usuario,
				vm.Nombre,
				if(vm.Est is null, 0, vm.Est) as Est,
				vm.Sede,
				vm.Escuela,
				vm.Carrera,
				fn_GetCicloMatriculado(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Ciclo,
				fn_GetModuloMatriculado(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Modulo,
				fn_GetTurno(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Turno,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 1) as CurMatr,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 2) as CurRet,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 4) as CurPend,
				(select count(vm2.Curso)
				from vw_matriculados vm2
				where vm2.Id_alumno=vm.Id_alumno and vm2.id_periodo=vm.id_periodo) as CurCant,
				'' as UsuReg,
				'' as Perfil
			from vw_matriculados vm
			where (vm.id_sede=xidSede or xidSede=99) and vm.id_periodo = xidPeriodo;

		else
			select DISTINCT
				vm.Id_alumno,
				vm.Usuario,
				vm.Nombre,
				if(vm.Est is null, 0, vm.Est) as Est,
				vm.Sede,
				vm.Escuela,
				vm.Carrera,
				fn_GetCicloMatriculado(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Ciclo,
				fn_GetModuloMatriculado(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Modulo,
				fn_GetTurno(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Turno,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 1) as CurMatr,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 2) as CurRet,
				fn_GetCursosCant(vm.Id_alumno, vm.id_unidad, vm.id_periodo, 4) as CurPend,
				(select count(vm2.Curso)
				from vw_matriculados vm2
				where vm2.Id_alumno=vm.Id_alumno and vm2.id_periodo=vm.id_periodo) as CurCant,
				vmu.username as UsuReg,
				vmu.rol as Perfil
			from vw_matriculados vm
			inner join vw_matriculados_usuarios vmu on vm.Id_alumno=vmu.id_alumno
				and vm.id_periodo=vmu.id_periodo and vm.id_unidad=vmu.id_unidad
			where (vm.id_sede=xidSede or xidSede=99) and vm.id_periodo = xidPeriodo;

		end if;

	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Matricula_ins`(in xidAlumno int, in xidUnidad int, in xidMalla int, in xidGrupoInicio int, in xidLocal int)
BEGIN
	set @ContarTurnos := (select count(distinct ghd.id_turno)
  					from grupos_inicio gi
  					inner join grupos_inicio_det gid on gi.id=gid.id_grupo_inicio
  					inner join cursos_programados cp on gid.id_curso_programado=cp.id
					inner join horarios ho on cp.id=ho.id_cursoprogramado
					inner join grupo_hora_det ghd on ghd.id=ho.id_grupo_hora_det_i
					inner join mallas_det md on cp.id_malla_det=md.id
					inner join cursos cu on md.id_curso=cu.id
					where cp.estado=1 and ho.estado=1 and ho.activo=1

					and cu.descripcion not like '%VIRTUAL%'
					and gi.id = xidGrupoInicio);

	if @ContarTurnos = 1 then
		set @idPeriodo := (select id_periodo from grupos_inicio where id = xidGrupoInicio);
		set @idCicloLectivo := (select id_ciclo_lectivo from periodos where id = @idPeriodo);




		insert into matricula (id_periodo, id_alumno, id_unidad, estado, created_at, created_by, updated_at, updated_by)
	    values (@idPeriodo, xidAlumno, xidUnidad, '1', now(), '21553', now(), '21553');

	    set @idMatricula = (select last_insert_id() as lastidMatricula);

	   	insert into matricula_det (id_matricula, id_cursoprogramado, id_matricula_est, id_alumno, estado, created_at,created_by, updated_at, updated_by)
	  	select @idMatricula, gt.id_curso_programado, '1', xidAlumno, '1', now(), '21553', now(), '21553'
	  	from grupos_inicio_det gt
		inner join cursos_programados cp on gt.id_curso_programado=cp.id
		inner join mallas_det md on cp.id_malla_det=md.id
		inner join cursos cu on md.id_curso=cu.id
		where cu.descripcion not like '%VIRTUAL%'
		and gt.id_grupo_inicio = xidGrupoInicio;


		set @CursoVirtual := (SELECT A.id_cursoprogramado
							FROM (
								select md.id_cursoprogramado, count(*) as cant
								from matricula_det md
								where id_cursoprogramado in (
									select distinct gt.id_curso_programado
									from grupos_inicio_det gt
									inner join cursos_programados cp on gt.id_curso_programado=cp.id
									inner join mallas_det md on cp.id_malla_det=md.id
									inner join cursos cu on md.id_curso=cu.id
									where cu.descripcion like '%VIRTUAL%'
									and gt.id_grupo_inicio = xidGrupoInicio
								)
								group by md.id_cursoprogramado
								order by 2 desc
							) A
							where A.cant < (select valor from matricula_parametros where id=10)
							limit 1);

		if @CursoVirtual is not null then
			insert into matricula_det (id_matricula, id_cursoprogramado, id_matricula_est, id_alumno, estado, created_at,created_by, updated_at, updated_by)
			values(@idMatricula, @CursoVirtual, '1', xidAlumno, '1', now(), '21553', now(), '21553');
		end if;


	  	insert into matricula_det_comp(id_matricula_det, id_cursoprogramado, created_at, created_by, updated_at, updated_by)
	  	select md.id, md.id_cursoprogramado, now(), '21553', now(), '21553'
	  	from matricula_det md
	    where md.id_matricula = @idMatricula;

	    insert into admisiones (id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo, id_malla, id_tipo_admision,
	                            orden, id_matricula_est, estado, created_at, created_by, updated_at,updated_by)
	    values(xidAlumno, xidUnidad, xidLocal, @idCicloLectivo, @idPeriodo, xidMalla, '5', '1', '1', 1,now(), 21553, now(), 21553);

	   	set @idAdmision := (select last_insert_id() as lastIdAdmision);

	    insert into alumno_sesion_lect(id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo, id_malla, id_admision,
	                                    id_matricula, id_matricula_est, created_at, created_by, updated_at, updated_by)
	    values(xidAlumno, xidUnidad, xidLocal, @idCicloLectivo, @idPeriodo, xidMalla, @idAdmision, @idMatricula, '1', now(), '21553', now(), '21553');

	   set @idTurno := (select distinct ghd.id_turno
  					from grupos_inicio gi
  					inner join grupos_inicio_det gid on gi.id=gid.id_grupo_inicio
  					inner join cursos_programados cp on gid.id_curso_programado=cp.id
					inner join horarios ho on cp.id=ho.id_cursoprogramado
					inner join grupo_hora_det ghd on ghd.id=ho.id_grupo_hora_det_i
					inner join mallas_det md on cp.id_malla_det=md.id
					inner join cursos cu on md.id_curso=cu.id
					where cp.estado=1 and ho.estado=1 and ho.activo=1

					and cu.descripcion not like '%VIRTUAL%'
					and gi.id = xidGrupoInicio);

		update admisiones
		set id_turno = @idTurno
		where id = @idAdmision;


		call usp_Matricula_PreSise_ins(xidAlumno,xidUnidad,xidLocal);
	end if;

	select @ContarTurnos as ContarTurnos;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Matricula_PreSise_ins`(in xidAlumno int, in xidUnidad int, in xidLocal int)
BEGIN
	set @idEscuela := (select id_padre from unidad where id = xidUnidad);
	set @idMalla := (select id_malla from unidad_PreSise where id_unidad = @idEscuela);

	if @idMalla is not null then
		set @idPeriodo := (select cp.id_periodo
						from cursos_programados cp
						inner join mallas_det md on cp.id_malla_det=md.id
						where md.id_malla = @idMalla
						and cp.estado = 1
						order by cp.id desc
						limit 1);

		if @idPeriodo is not null then
			set @idCicloLectivo := (select id_ciclo_lectivo from periodos where id = @idPeriodo);
			set @idUnidadPreSise := (select id_unidad_PreSise from unidad_PreSise where id_unidad = @idEscuela);


			insert into matricula (id_periodo, id_alumno, id_unidad, estado, created_at, created_by, updated_at, updated_by)
	    	values (@idPeriodo, xidAlumno, @idUnidadPreSise, '1', now(), '21553', now(), '21553');

	    	set @idMatricula = (select last_insert_id() as lastidMatricula);



	    	insert into matricula_det (id_matricula, id_cursoprogramado, id_matricula_est, id_alumno, estado, created_at,created_by, updated_at, updated_by)
			select distinct @idMatricula, cp.id, '1', xidAlumno, '1', now(), '21553', now(), '21553'
			from cursos_programados cp
			inner join mallas_det md on cp.id_malla_det=md.id
			where cp.estado = 1
			and md.id_malla = @idMalla
			and id_periodo = @idPeriodo;



			insert into matricula_det_comp(id_matricula_det, id_cursoprogramado, created_at, created_by, updated_at, updated_by)
		  	select md.id, md.id_cursoprogramado, now(), '21553', now(), '21553'
		  	from matricula_det md
		    where md.id_matricula = @idMatricula;



			insert into admisiones (id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo,
									id_malla, id_tipo_admision,orden, id_matricula_est, estado,
									created_at, created_by, updated_at,updated_by)
	    	values(xidAlumno, @idUnidadPreSise, xidLocal, @idCicloLectivo, @idPeriodo, @idMalla, '5', '1', '1', 1,now(), 21553, now(), 21553);

	   		set @idAdmision := (select last_insert_id() as lastIdAdmision);



	   		insert into alumno_sesion_lect(id_alumno, id_unidad, id_local, id_ciclo_lectivo, id_periodo,
	   									id_malla, id_admision,id_matricula, id_matricula_est,
	   									created_at, created_by, updated_at, updated_by)
	    	values(xidAlumno, @idUnidadPreSise, xidLocal, @idCicloLectivo, @idPeriodo, @idMalla, @idAdmision, @idMatricula, '1', now(), '21553', now(), '21553');



	    	set @idTurno := (select distinct ghd.id_turno
							from cursos_programados cp
							inner join mallas_det md on cp.id_malla_det=md.id
							inner join horarios ho on cp.id=ho.id_cursoprogramado
							inner join grupo_hora_det ghd on ghd.id=ho.id_grupo_hora_det_i
							where cp.estado = 1
							and md.id_malla = @idMalla
							and id_periodo = @idPeriodo
							limit 1);

			update admisiones
			set id_turno = @idTurno
			where id = @idAdmision;

		end if;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_MAT_Alumno_Upd`(xidAlumno int,
											xidReniec int,
											xNumDoc varchar(10),
											xTipoDoc varchar(4),
											xNombres varchar(50),
											xPaterno varchar(50),
											xMaterno varchar(50),
											xFecNac date,
											xSexo varchar(1),
											xEmail varchar(50),
											xDireccion varchar(300),
											xReferencia varchar(100),
											xUbigeo varchar(10),
											xTelefono1 varchar(15),
											xTelefono2 varchar(15),
											xEstado int)
BEGIN
	set @idPersona := (select id_persona from alumnos where id = xidAlumno);

	if @idPersona is not null then
		update persona
		set codigo=xidReniec,
			paterno=xPaterno,
			materno=xMaterno,
			nombres=xNombres,
			id_tipo_documento=xTipoDoc,
			nro_documento=xNumDoc,
			fecnac=xFecNac,
			email=xEmail,
			sexo=xSexo,
			direccion=xDireccion,
			referencia=xReferencia,
			ubigeo=xUbigeo,
			telefono_movil=xTelefono1,
			telefono_fijo=xTelefono2,
			updated_at=now(),
			updated_by=10166
		where id = @idPersona;

		update persona_actualiza
		set codigo=xidReniec,
			paterno=xPaterno,
			materno=xMaterno,
			nombres=xNombres,
			id_tipo_documento=xTipoDoc,
			nro_documento=xNumDoc,
			fecnac=xFecNac,
			email=xEmail,
			sexo=xSexo,
			direccion=xDireccion,
			referencia=xReferencia,
			ubigeo=xUbigeo,
			telefono_movil=xTelefono1,
			telefono_fijo=xTelefono2,
			updated_at=now(),
			updated_by=10166
		where id_persona = @idPersona;


		set @nomCompleto := (select concat(xPaterno,' ',xMaterno,' ',xNombres));

		update users
		set name = @nomCompleto, status=xEstado, updated_at=now()
		where id in (select id_user from alumnos where id = xidAlumno);
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_MAT_ValidarMatricula`(xPaterno varchar(50), xMaterno varchar(50), xNombres varchar(50), xidCarrera int, xidPrograma int)
BEGIN
	set @rpta := '';

	if xidPrograma <> 164 then
		set @contar := (select count(1)
				from admisiones ad
				inner join alumnos al on ad.id_alumno=al.id
				inner join persona pe on al.id_persona=pe.id
				where ad.estado=1 and
					pe.paterno=xPaterno and pe.materno=xMaterno and pe.nombres=xNombres
					and ad.id_unidad=xidCarrera and ad.estado = 1);
	else
		set @malla := (select id from mallas where id_unidad=xidCarrera and estado=1 order by id limit 1);

		set @contar := (select count(1)
				from admisiones ad
				inner join alumnos al on ad.id_alumno=al.id
				inner join persona pe on al.id_persona=pe.id
				where ad.estado=1 and
					pe.paterno=xPaterno and pe.materno=xMaterno and pe.nombres=xNombres
					and ad.id_unidad=xidCarrera and ad.estado = 1 and ad.id_malla=@malla);
	end if;

	if @contar = 0 then
		set @rpta := 'Procede';
	else
		set @rpta := 'NoProcede';
	end if;

	select @rpta as rpta;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_persona_cargo_ins`(
in xidPersona int(11),
in xidUser int(11),
in xidRole int
)
BEGIN

	if xidRole = 2 then
		if (select count(*) from docentes where id_persona = xidPersona) = 0 then
			insert into docentes (id_persona,id_user,estado,created_at,created_by,updated_at,updated_by)
			values(xidPersona,xidUser,1,now(),1,now(),1);
		end if;
	end if;

	if (select count(*) from model_has_roles where role_id=xidRole and model_id=xidUser) = 0 then
		insert into model_has_roles (role_id,model_type,model_id)
		values(xidRole,'App\\User',xidUser);
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_persona_ins`(
in xidSise varchar(20),
in xPaterno varchar(25),
in xMaterno varchar(25),
in xNombres varchar(50),
in xTipoDoc tinyint,
in xNroDoc varchar(20),
in xFecNac date,
in xEmail varchar(90),
in xSexo char(1),
in xTelefono1 varchar(15),
in xTelefono2 varchar(15),
in xRuc varchar(11),
in xGrupoPago int,
in xClave varchar(255)
)
BEGIN
	declare idPersona int(11);
	declare idUser int(11);
	declare xClaveActual varchar(255);
	declare xAlumno int;

	if xGrupoPago = 0 then
		set xGrupoPago = null;
	end if;

	set idPersona = (select count(*) from persona_actualiza where codigo=xidSise);

	if idPersona = 0 then
		insert into persona (codigo,paterno,materno,nombres,id_tipo_documento,nro_documento,fecnac,email,sexo,estado_civil,
						telefono_movil,telefono_fijo, RUC,id_grupo_pago,created_at,created_by,updated_at,updated_by)
		values(xidSise,xPaterno,xMaterno,xNombres,xTipoDoc,xNroDoc,xFecNac,xEmail,xSexo,'S',xTelefono1,xTelefono2,xRuc,xGrupoPago,
				now(),1,now(),1);

		set	idPersona = (select LAST_INSERT_ID());

		insert into persona_actualiza (id_persona,codigo,paterno,materno,nombres,id_tipo_documento,nro_documento,fecnac,email,sexo,estado_civil,
							telefono_movil,telefono_fijo,RUC,id_grupo_pago,valida,created_at,created_by,updated_at,updated_by)
		values(idPersona,xidSise,xPaterno,xMaterno,xNombres,xTipoDoc,xNroDoc,xFecNac,xEmail,xSexo,'S',xTelefono1,xTelefono2,xRuc,xGrupoPago,
				0,now(),1,now(),1);

		insert into users (name,email,password,created_at, updated_at)
		values(concat(xPaterno,' ',xMaterno,' ',xNombres),xEmail,xClave,now(),now());

		set	idUser = (select LAST_INSERT_ID());

	else
		set idPersona = (select id_persona from persona_actualiza where codigo=xidSise);

		update persona_actualiza
		set paterno=xPaterno, materno=xMaterno, nombres=xNombres, id_tipo_documento=xTipoDoc,
			nro_documento=xNroDoc, fecnac=xFecNac, sexo=xSexo, telefono_movil=xTelefono1, telefono_fijo=xTelefono2,
			ruc=xRuc, id_grupo_pago=xGrupoPago
		where codigo = xidSise;

		if (select count(*) from users where email = xEmail) = 0 then
			insert into users (name,email,password,created_at, updated_at)
			values(concat(xPaterno,' ',xMaterno,' ',xNombres),xEmail,xClave,now(),now());

			set	idUser = (select LAST_INSERT_ID());
		ELSE
			set idUser = (select id from users where email=xEmail);
			set xClaveActual = (select password from users where id=idUser);

			if xClave = '' then
				set xClave = xClaveActual;
			end if;

			update users
			set name = concat(xPaterno,' ',xMaterno,' ',xNombres),
				password = xClave,
				updated_at=now()
			where id = idUser;
		end if;


		set xAlumno = (select count(*) from alumnos where id_persona=idPersona);
		if xAlumno = 0 then
			delete from docentes where id_persona=idPersona;
			delete from model_has_roles where model_id=idUser;
		end if;
	end if;

	select idPersona, idUser;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Producto_Matriculado`(xidAlumno int, xidCarrera int)
BEGIN
	select concat(es.descripcion,' - ',ca.descripcion,' - Ciclo: ',fn_GetCicloMaximo(ma.id_alumno, ma.id_unidad)) as ProdMatriculado
	from matricula ma
	inner join matricula_det md on ma.id = md.id_matricula
	inner join unidad ca on ma.id_unidad = ca.id
	inner join unidad es on ca.id_padre = es.id
	inner join cursos_programados cp on md.id_cursoprogramado = cp.id
	inner join mallas_det mad on cp.id_malla_det = mad.id
	where ma.id_alumno = xidAlumno and ma.id_unidad = xidCarrera and ma.estado = 1
	order by ma.id desc
	limit 1;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Rpt_Alumnos_xCursoProg`(xidCursoProg int)
BEGIN
	select DISTINCT
			vm.Id_alumno,
			vm.Usuario,
			vm.Nombre,
			vm.Est,
			vm.Sede,
			vm.Escuela,
			vm.Carrera,
			fn_GetCicloMaximo(vm.Id_alumno, vm.id_unidad) as Ciclo,
			fn_GetTurno(vm.Id_alumno, vm.id_unidad, vm.id_periodo) as Turno
		from vw_matriculados vm
		where vm.idclase = xidCursoProg
		order by 3;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Rpt_Asistencia_Alumnos`(xidCursoProg int)
BEGIN
	set @idPadre = (select count(*) from cursos_programados where id_padre=xidCursoProg);

	if @idPadre = 0 then
		select 'Sin información' as Sin_Informacion;
	else



		SET session group_concat_max_len=15000;

		set @sql =
			(select group_concat(distinct
		        concat(
		            "max(CASE WHEN fecha = '",
		      		date_format(fecha, '%Y-%m-%d'),
		      		"' THEN estado END) AS '",
		      		date_format(fecha, '%d-%m'), "'"
		        )
		    )
		    from vw_asistencia_alumnos
			where activo = 1 and id_cp = xidCursoProg
			);


		set @sql = concat("select id_alumno as id, Alumno, Sede, fn_GetMatriculado(id_alumno,id_cp) as Mat, ", @sql, " from vw_asistencia_alumnos where activo=1 and estadoAdmi=1 and alumno is not null and id_cp=",xidCursoProg," group by alumno, sede, id_alumno, id_cp");


		prepare stmt from @sql;


		execute stmt;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_Rpt_CursosProgramados`(xSoloIdPadre int,
																				xSoloActivos int,
																				xidCicloLectivo int,
																				xidPeriodo int,
																				xidEscuela int,
																				xidCarrera int,
																				xidCurso int)
BEGIN
	if xSoloIdPadre = 1 then
		if xSoloActivos = 1 then
			select DISTINCT


				Escuela,
				Carrera,
				Curso,
				id_cp,
				id_pa,
				getHorario(id_pa, 0) as Horario,
				fec_ini,
				fec_fin,
				fn_GetDocente(id_pa) as Docente,
				Cant_Alumnos,

				estado,
				'' as Grupo_Inicio

			from vw_cursos_programados
			where id_cicloLectivo = xidCicloLectivo and id_periodo = xidPeriodo and id_cp = id_pa and estado='A'
			and (idEscuela=xidEscuela or xidEscuela=9999) and (idCarrera=xidCarrera or xidCarrera=9999) and (id_pa=xidCurso or xidCurso=9999)
			order by id_pa, id_cp;
		else
			select DISTINCT


				Escuela,
				Carrera,
				Curso,
				id_cp,
				id_pa,
				getHorario(id_pa, 0) as Horario,
				fec_ini,
				fec_fin,
				fn_GetDocente(id_pa) as Docente,
				Cant_Alumnos,

				estado,
				'' as Grupo_Inicio

			from vw_cursos_programados
			where id_cicloLectivo = xidCicloLectivo and id_periodo = xidPeriodo and id_cp = id_pa
			and (idEscuela=xidEscuela or xidEscuela=9999) and (idCarrera=xidCarrera or xidCarrera=9999) and (id_pa=xidCurso or xidCurso=9999)
			order by id_pa, id_cp;
		end if;
	else
		if xSoloActivos = 1 then
			select DISTINCT


				Escuela,
				Carrera,
				Curso,
				id_cp,
				id_pa,
				getHorario(id_pa, 0) as Horario,
				fec_ini,
				fec_fin,
				fn_GetDocente(id_pa) as Docente,
				Cant_Alumnos,

				estado,
				'' as Grupo_Inicio

			from vw_cursos_programados
			where id_cicloLectivo = xidCicloLectivo and id_periodo = xidPeriodo and estado='A'
			and (idEscuela=xidEscuela or xidEscuela=9999) and (idCarrera=xidCarrera or xidCarrera=9999) and (id_pa=xidCurso or xidCurso=9999)
			order by id_pa, id_cp;
		else
			select DISTINCT


				Escuela,
				Carrera,
				Curso,
				id_cp,
				id_pa,
				getHorario(id_pa, 0) as Horario,
				fec_ini,
				fec_fin,
				fn_GetDocente(id_pa) as Docente,
				Cant_Alumnos,

				estado,
				'' as Grupo_Inicio

			from vw_cursos_programados
			where id_cicloLectivo = xidCicloLectivo and id_periodo = xidPeriodo
			and (idEscuela=xidEscuela or xidEscuela=9999) and (idCarrera=xidCarrera or xidCarrera=9999) and (id_pa=xidCurso or xidCurso=9999)
			order by id_pa, id_cp;
		end if;
	end if;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_seg_sede_ins`(in xIdUser int)
BEGIN
    declare xidSede int;
    declare xidsegsedes_1 int;
    declare findelbucle int default 0;
    declare cursor_sede cursor for select id from sedes where id_padre=0;



    declare CONTINUE handler for not found set findelbucle=1;

	DELETE FROM seg_sedes_2 WHERE id_sedes_1 IN (SELECT id FROM seg_sedes_1 WHERE id_users = xIdUser);
	DELETE FROM seg_sedes_1 WHERE id_users = xIdUser;

    open cursor_sede;
    loop1: loop

	fetch cursor_sede into xidSede;


    if (findelbucle = 1) then
		leave loop1;
    end if;



        insert into seg_sedes_1 (id_sede, id_users, estado, created_at, created_by, updated_at, updated_by)
			values (xidSede, xIdUser, 1, now(), 1, now(), 1);
            set xidsegsedes_1 = (select last_insert_id());

		insert into seg_sedes_2 (id_sedes_1, id_sede, id_users, estado, created_at, created_by, updated_at, updated_by)
		select xidsegsedes_1, id, xIdUser, 1, now(), 1, now(), 1
			from sedes where id_padre=xidsede;

    end loop loop1;

    close cursor_sede;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_seg_unidad_ins`(IN xIdUser int)
BEGIN
	declare xid_SegUnidad_1 int;
	set	xid_SegUnidad_1 = (select id from seg_unidad_1 where id_users = xIdUser);

	if xid_SegUnidad_1 is null then
		insert into seg_unidad_1(id_unidad,id_users,estado,created_at,created_by,updated_at,updated_by)
		values(1,xIdUser,1,now(),1,now(),1);

		set	xid_SegUnidad_1 = (select LAST_INSERT_ID());
	end if;

	insert into seg_unidad_2(id_seg_unidad_1,id_unidad,id_users,estado,created_at,created_by,updated_at,updated_by)
  	select xid_SegUnidad_1, id, xIdUser,1,now(),1,now(),1
  	from unidad
  	where nivel = 2 and id not in (select id_unidad from seg_unidad_2 where id_seg_unidad_1 = xid_SegUnidad_1 and id_users=xIdUser);

  	insert into seg_unidad_3(id_seg_unidad_2,id_unidad,id_users,estado,created_at,created_by,updated_at,updated_by)
  	select id, 9999, xIdUser,1,now(),1,now(),1
  	from seg_unidad_2
  	where id_users = xIdUser and id not in (select id_seg_unidad_2 from seg_unidad_3 where id_users = xIdUser);

	insert into seg_unidad_4(id_seg_unidad_3,id_unidad,id_users,estado,created_at,created_by,updated_at,updated_by)
  	select id, 9999, xIdUser,1,now(),1,now(),1
  	from seg_unidad_3
  	where id_users = xIdUser and id not in (select id_seg_unidad_3 from seg_unidad_4 where id_users = xIdUser);
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_TEMPO_TablasClases`(xidCursoProg int)
BEGIN

select * from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg;

select * from horarios where id_cursoprogramado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

select * from matricula_det where id_cursoprogramado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

select * from matricula_det_comp where id_cursoprogramado
in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

select * from sesiones where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg);

select * from marcaciones
where id_sesion in (select id from sesiones
	where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg));

select * from asistencia_alumnos
where id_sesion in (select id from sesiones
	where id_curso_programado in (select id from cursos_programados where id = xidCursoProg or id_padre = xidCursoProg));

END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_upd_cursosHijos`(in xidMatricula int, in xidUnidad int, in xidAlumno int)
BEGIN
	set @idGrupoInicio := (select distinct id_grupo_inicio
							from grupos_inicio_det
							where id_grupo_inicio in (select id from grupos_inicio where id_unidad = xidUnidad)
							and id_curso_programado
								in (select id_cursoprogramado from matricula_det where id_matricula = xidMatricula));

	delete from matricula_det_comp  where id_matricula_det in (select id from matricula_det where id_matricula=xidMatricula);
	delete from matricula_det where id_matricula=xidMatricula;

	insert into matricula_det (id_matricula, id_cursoprogramado, id_matricula_est, id_alumno, estado, created_at,created_by, updated_at, updated_by)
	select xidMatricula, (select id from cursos_programados where id_padre=gt.id_curso_programado and id_unidad=xidUnidad), '1', xidAlumno, '1', now(), '1', now(), '1'
	from grupos_inicio_det gt
	where id_grupo_inicio = @idGrupoInicio;

	insert into matricula_det_comp(id_matricula_det, id_cursoprogramado, created_at, created_by, updated_at, updated_by)
	select md.id, md.id_cursoprogramado, now(), '1', now(), '1'
	from matricula_det md
	where md.id_matricula = xidMatricula;

	set @id = (select max(id) +1 from Alumnos_Realizados);
	insert into Alumnos_Realizados values(@id, xidAlumno);
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_validarAlumno_TEMP`(in xPaterno varchar(50),
												 in xMaterno varchar(50),
												 in xNombre varchar(50),
												 in xIdEspecialidad int)
BEGIN
	set @idPersona := (select id from persona where paterno=xPaterno and materno=xMaterno and nombres=xNombre);
	set @rpta := 'Ok';

	if @idPersona is not null then
		set @idAlumno := (select id from alumnos where id_persona = @idPersona);

		if @idAlumno is null then
			delete from persona_actualiza where id_persona = @idPersona;
			delete from persona where id = @idPersona;
		else
			set @ExisteMatriculas := (select count(1) from matricula where id_alumno = @idAlumno);

			if @ExisteMatriculas = 0 then
				DELETE from model_has_roles where model_id in (select id_user from alumnos where id_persona = @idPersona);
				DELETE from users where id in (select id_user from alumnos where id_persona = @idPersona);
				DELETE from alumno_sesion_lect where id_admision in (select id from admisiones where id_alumno = (select id from alumnos where id_persona = @idPersona));
				DELETE from admisiones where id_alumno in (select id from alumnos where id_persona = @idPersona);
				DELETE from matricula_det_comp where id_matricula_det in
					(select id from matricula_det where id_matricula in (select id from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona)));
				DELETE from matricula_det where id_matricula in (select id from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona));
				DELETE from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona);
				DELETE from alumnos where id_persona = @idPersona;
				DELETE from persona_actualiza where id_persona = @idPersona;
				DELETE from persona where id = @idPersona;
				DELETE from tmp where user_id = (select id_user from alumnos where id_persona = @idPersona);
			else
				set @existe = (select count(1) from matricula where id_periodo=229 and id_alumno=@idAlumno and id_unidad=xIdEspecialidad);

				if @existe > 0 then
					set @rpta := 'NotOk';
				end if;
			end if;
		end if;
	end if;

	select @rpta;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_validarEmail_TEMP`(in xEmail varchar(50),xNomCompleto varchar(200))
BEGIN
	set @rpta := 'Ok';
	set @idUser := (select id from users where email = xEmail);

	if @idUser is not null then
		set @nom := (select concat(paterno,' ',materno,' ',nombres) from persona where id = (select id_persona from alumnos where id_user=@idUser));

		if xNomCompleto <> @nom then
			set @rpta := 'NotOk';
		end if;
	end if;

	select @rpta;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_validarExistencia_Alumno`(in xDni varchar(10), in xNomCompleto varchar(200), in xIdPeriodo int, in xIdCarrera int)
BEGIN
	set @IdAlumno := 0;
	set @contar := (select count(1) from persona where nro_documento=xDni);

	IF @contar > 1 THEN
		set @IdAlumno = -2;
	ELSE
		set @idPersona := (select id from persona where nro_documento=xDni);

		if @idPersona is not null then
			set @IdAlumno := (select id from alumnos where id_persona = @idPersona);

			if @IdAlumno is null then
				set @idDocente := (select count(1) from docentes where id_persona=@idPersona);

				if @idDocente = 0 then
					DELETE from persona_actualiza where id_persona = @idPersona;
					DELETE from persona where id = @idPersona;
				end if;

				set @IdAlumno := 0;
			else
				set @ExisteAdmision := (select count(1) from admisiones where id_alumno = @IdAlumno);

				if @ExisteAdmision = 0 then
					DELETE from model_has_roles where model_id in (select id_user from alumnos where id_persona = @idPersona);
					DELETE from users where id in (select id_user from alumnos where id_persona = @idPersona);
					DELETE from matricula_det_comp
						where id_matricula_det in (select id from matricula_det
						where id_matricula in (select id from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona)));
					DELETE from matricula_det
						where id_matricula in (select id from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona));
					DELETE from matricula where id_alumno in (select id from alumnos where id_persona = @idPersona);
					DELETE from asistencia_alumnos where id_alumno = (select id from alumnos where id_persona = @idPersona);
					DELETE from alumnos where id_persona = @idPersona;
					DELETE from persona_actualiza where id_persona = @idPersona;
					DELETE from persona where id = @idPersona;
					DELETE from tmp where user_id = (select id_user from alumnos where id_persona = @idPersona);

					set @IdAlumno := 0;
				else
					set @ExisteAdmision := (select count(1) from admisiones where estado = 1
																				and id_periodo=xIdPeriodo
																				and id_alumno=@IdAlumno
																				and id_unidad=xIdCarrera);

					if @ExisteAdmision > 0 then
						set @IdAlumno := -1;
					else
						set @idUsuario := (select id from users where id = (select id_user from alumnos where id = @IdAlumno));
						set @NewUserName := (select concat('u', lpad(CAST(@IdAlumno AS CHAR), 8, '0')));
						set @correoSise := (select concat(@NewUserName,'@sise.com.pe'));

						if @idUsuario is null then
							insert into users(name, username, email, password, status, created_at, updated_at)
				    		values (xNomCompleto, @NewUserName, @correoSise,'$2y$10$.T/OeTiwUZSIXsp5r2TsWumi0A4XPvasU.Va8CsEEsO.woEZmIp5G',1,now(), now());

				    		set @lastIdUser := (select last_insert_id());

				    		insert into model_has_roles (role_id, model_type, model_id)
							values ('3','App\\User' ,@lastIdUser);


							set @idTmp := (select max(id)+1 from tmp);
							insert into tmp values(@idTmp,@lastIdUser,'XV64fd35',now(),now());

							update alumnos
							set id_user = @lastIdUser
							where id = @IdAlumno;
						else
							set @idTmp = (select id from tmp where user_id=@idUsuario);

							if @idTmp is null then

								set @idTmp := (select max(id)+1 from tmp);
								insert into tmp values(@idTmp,@idUsuario,'XV64fd35',now(),now());

								update users
								set password = '$2y$10$.T/OeTiwUZSIXsp5r2TsWumi0A4XPvasU.Va8CsEEsO.woEZmIp5G'
								where id = @idUsuario;
							end if;

							update users
							set name=xNomCompleto, username=@NewUserName, email=@correoSise
							where id = @idUsuario;
						end if;
					end if;
				end if;
			end if;
		end if;
	END IF;

	select @IdAlumno;
END;

CREATE DEFINER=`sisezend`@`%` PROCEDURE `siseacad`.`usp_VentaNueva_del`(in inTipo varchar(10), in inIdAlumno int, in idIdUnidad int)
BEGIN
	if inTipo = 'all' then
		delete from tmp where user_id = (select id_user from alumnos where id = inIdAlumno);
		delete from model_has_roles where model_id in (select id_user from alumnos where id = inIdAlumno);
		delete from users where id in (select id_user from alumnos where id = inIdAlumno);
		delete from asistencia_alumnos where id_alumno = inIdAlumno;
		delete from alumno_sesion_lect where id_admision in (select id from admisiones where id_alumno = inIdAlumno);
		delete from admisiones where id_alumno = inIdAlumno;
		delete from matricula_det_comp where id_matricula_det in (select id from matricula_det where id_matricula in (select id from matricula where id_alumno = inIdAlumno));
		delete from matricula_det where id_matricula in (select id from matricula where id_alumno = inIdAlumno);
		delete from matricula where id_alumno = inIdAlumno;
		delete from alumnos where id = inIdAlumno;
		delete from persona_actualiza where id_persona = (select id_persona from alumnos where id = inIdAlumno);
		delete from persona where id = (select id_persona from alumnos where id = inIdAlumno);
	else
		delete from alumno_sesion_lect where id_admision in (select id from admisiones where id_alumno = inIdAlumno and id_unidad = idIdUnidad);
		delete from admisiones where id_alumno = inIdAlumno and id_unidad = idIdUnidad;
		delete from matricula_det_comp where id_matricula_det in (select id from matricula_det where id_matricula in (select id from matricula where id_alumno = inIdAlumno and id_unidad = idIdUnidad));
		delete from matricula_det where id_matricula in (select id from matricula where id_alumno = inIdAlumno and id_unidad = idIdUnidad);
		delete from matricula where id_alumno = inIdAlumno and id_unidad = idIdUnidad;
	end if;
END;