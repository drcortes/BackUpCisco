#!/usr/bin/expect 
#Autor: Diego Cortes Robles
#Tel: 973886883

#set tmp [open /Respaldos/SCRIPT/Cred/cred ] 
#set cred [split [read $tmp] " "]
#close $tmp

proc envio {Mensaje} {
        spawn telnet vippowasmtp.cl.bsch 25
        expect "Microsoft"
        send "helo\n"
        expect "250"
        send "mail from:pgsttlcap01@santander.cl\n"
        expect "Sender OK"
        send "rcpt to:<diego.cortes@servexternos.santander.cl>\nrcpt to:<giorgio.coiro@santander.cl>\nrcpt to:<teleco_n2@santander.cl>\n"
        expect "Recipient OK"
        send "data\n"
        expect "Start mail input"
        send "Content-Type: text/html\nSubject:Falla de Respaldos diarios - Cisco\n\n$Mensaje<br>Se solicita al equipo de 24-7, realizar el backup de la configuración de todos los equipos mencionados en el listado y que estos sean guardados en el equipo PGSTTLCAP01, usuario PLLNX02, ruta /Respaldos/Routeryswitch/AÑO/MES/DIA, ingresando a la carpeta de la fecha correspondiente. En caso de que este listado supere las 10 máquinas favor de redirigir esto con su supervisor para que sea analizado.<br><br><b>Este correo ha sido generado de manera automática, favor NO RESPONDER.</b>\n.\n"
        expect "250"
        send "QUIT\n"
        expect "221"
        puts "Correo Enviado"
}


proc Respaldo {IP} {

	set key [open /Respaldos/SCRIPT/Cred/cred ]
	set hash [read $key]
	set tmp [exec python3 /Respaldos/SCRIPT/Cred/Cifrado.py $hash ]	
	set cred [split $tmp " "]
	close $key

	match_max -d 8000000
	#set timeout 10

	set Username [lindex $cred 0]
	set Password [lindex $cred 1]

	#Declaracion de Variables"
	set fecha [exec date +%Y%m%d]
	set hora [exec date +%H%M%S]
	set year [exec date +%Y]
	set month [exec date +%m]
	set day [exec date +%d]
	set fallo 0
	set ListaFalla "Los equipos que no fueron respaldados en el servidor PGSTTLCAP01 son:<br><br>"
	set ListaIPFalla {}
	set log /Respaldos/SCRIPT/regRyS.log
	if { ![file exists $log] } {
        	exec touch regRyS.log
	        set log [open  /Respaldos/SCRIPT/regRyS.log a]
	} else {
        	set log [open  /Respaldos/SCRIPT/regRyS.log a]
	}



	#creación de Directorios
	set dir /Respaldos/RouterySwitch/$year
		if { ![file isdirectory $dir] } {
                        file mkdir /Respaldos/RouterySwitch/$year/$month/$day
                } else {
			set dir  /Respaldos/RouterySwitch/$year/$month
			if { ![file isdirectory $dir] } {
				file mkdir /Respaldos/RouterySwitch/$year/$month/$day
			} else {
				set dir /Respaldos/RouterySwitch/$year/$month/$day
				if { ![file isdirectory $dir] } {
				file mkdir /Respaldos/RouterySwitch/$year/$month/$day }	
			}
			}


	#conexión a equipos listados

	foreach line $IP {
		set hora [exec date +%H%M%S]
		if { "$line" eq "" } {
			set fallo 1
		 } else {
		set fallo 0
		spawn ssh -o "StrictHostKeyChecking no"  $Username@$line	
		expect {
       		-re "Connection refused" { set fallo 1;  puts $log "$fecha-$hora: Fallo la conexión al equipo: $line" ; append ListaFalla $line "<br>" ; lappend ListaIPFalla $line }
   	 	-re "Could not resolve hostname" { set fallo 1; puts $log "$fecha-$hora: No se pudo resolver el nombre: $line" ; append ListaFalla $line "<br>"
			lappend ListaIPFalla $line   }
	 	-re "Received disconnect"  { set fallo 1; puts $log "$fecha-$hora: Fallo la autenticación en: $line" ;  append ListaFalla $line "<br>"; lappend ListaIPFalla $line   }
	 	-re "No route to host" { set fallo 1; puts $log "$fecha-$hora: Sin Ruta a destino: $line" ; append ListaFalla $line "<br>"; lappend ListaIPFalla $line  }
	 	-re "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"  { 
			exec /bin/sh -c "sed -i '/$line/d' /root/.ssh/known_hosts"
			puts $log "$fecha-$hora: ATENCION! Existio cambio de llave Publica: $line"
			append ListaFalla $line "\n" 
		 	}	 
		#timeout { set fallo 1; puts $log "$fecha-$hora:Equipo no responde timeout: $line" ; append ListaFalla $line "<br>" }
			}
		
			}

		if { "$fallo" eq "0" } {
			expect {
				"*assword:" {
					        send "$Password\r"
		        	        	expect {
			        	                "#" {
       		         			        send "terminal length 0\r"
     		                   			expect  "#"
				                        send "show run\r"
        				                expect  "\[A-Za-z0-9]#" {
               		 	        		        set respaldo [open /Respaldos/RouterySwitch/$year/$month/$day/$line-$fecha.bkp w]
		       		                 	        puts $respaldo "$expect_out(buffer)"
                			               		puts $log "$fecha-$hora: Se realiza respaldo de equipo: $line"
                               		 				}
		                       		 	send "exit\r"
                		        		expect eof
                        				}
				             	  	 "*assword:" { puts $log "$fecha-$hora: Fallo la autenticación en: $line" ; append ListaFalla $line "<br>"
								lappend ListaIPFalla $line }
	                  				}
						}
				timeout {  puts $log "$fecha-$hora: No se logro la conexion por Timeout en: $line" ; append ListaFalla $line "<br>"; lappend ListaIPFalla $line }
				}
		}	
	}
close $log
return [list $ListaFalla $ListaIPFalla]
}

proc EnviaCorreo {ListaFalla} {

if {[regexp {[0-9]+} $ListaFalla]} {
	envio $ListaFalla
}
}


set Archivo [open /Respaldos/SCRIPT/listadoEquiposRyS]
set IP [split [read $Archivo] "\n"]
close $Archivo

set ListaF [Respaldo $IP]

if { [llength [lindex $ListaF 1]] == 0 } { 
	envio [lindex $ListaF 0]
	puts "OK"
} else {
	puts "Inicia Proceso de Pausa"
	after [expr (int (1000 * 30 * 30))]
	set ListaF2 [Respaldo [lindex $ListaF 1]]
	envio [lindex $ListaF2 0]
	puts "Fail"
}

