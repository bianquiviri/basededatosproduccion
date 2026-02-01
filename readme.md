# Para instalar la base de datos
Para ejecutar los siguiente comandos se recomienda para windowns el siguiente terminal 
https://github.com/felixse/FluentTerminal

1)instalar docker y docker-composer 

En linux  puede ejecutar  docker sin sudo 
sudo usermod -aG docker ${USER}

3) Para ejecutar el archivo docker-composer.yml
docker-compose up -d

4) Actualizar los permisos de usuario  para ello 
	a) ingresar a mysl 
		mysql -h 127.0.0.1 -p root -u 
	b) dentro de mysql ejecutar 
		GRANT ALL PRIVILEGES ON * . * TO 'sisezend'@'%';
	c) activar  los premiso de usuario 
		FLUSH PRIVILEGES;
	d) cerra la consola de mysql 
	bye;
5) subir los archivos 
  mysql -h 127.0.0.1 -p sisezend -u siseacad < siseacd..sql 

