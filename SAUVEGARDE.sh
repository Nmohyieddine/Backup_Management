#!/bin/bash

InfoServer=( kalimohyi 172.20.10.3 pi 172.20.10.8 )
## ordonné les serveurs dans lordre décroissant d'indépendance

##Le nombre de serveurs applicatifs
Nbr_Server=2
##Server DataBase informations
IDServerDataBase=pi
IPServerDataBase=172.20.10.8

##Server Backup informations
IDServerSauvegard=kalimohyi
IPServerSauvegard=172.20.10.3

##the name of service
service=bluetooth

#date +"%d-%m-%Y"
#var=$date
var=`date +"%d-%m-%Y"`

#date +"%x_%r"
#var2=$date
var2=`date +"%x_%r"`


NameFileSauvegarde="Sauvegarde${var}"


let NBRM1=$Nbr_Server-1     ##nombre serveur moin 1
let NBRP1=$Nbr_Server+1	    ## nombre de serveur plus 1
let NBRP2=$Nbr_Server+2     ##nombre de servuer plus 2

j=0
k=0
T=0



function Stop(){
IDServer=$1
IPServer=$2
Application=$3
SleepTime=5

ligne=$(ssh $IDServer@$IPServer  sudo systemctl is-active $Application)




if [ "$ligne" = "active" ]
then
        ssh  $IDServer@$IPServer   sudo systemctl stop $Application

        sleep $SleepTime

        LIG=$(ssh $IDServer@$IPServer  sudo systemctl is-active $Application)


        if [ "$LIG" = "active" ]
        then
                echo "Échec d'arrêt de $Application au $IDServer $IPServer " >>Sauvegarde.log
                return 1

        elif [ "$LIG" = "inactive" ]
	then


		echo "$Application arrêté avec succes au  $IDServer $IPServer " >>Sauvegarde.log
                return 0

        else
               echo "Cas imprévue l'ors de l'arrêt de $Application au serveur $IDServer $IPServer " >>Sauvegarde.log
               return 2


	fi


elif [ "$ligne" = "inactive" ] ; then echo "$Application est déjà arrété au $IDServer $IPServer"



else


return 2

fi

}

function start(){

IDServer=$1
IPServer=$2
Application=$3
SleepTime=5

ssh $IDServer@$IPServer sudo systemctl start $Application

ssh $IDServer@$IPServer systemctl is-failed $Application >> /dev/null 2>&1
echo $?
if [ "$?" == "0" ]
then
        echo "Démarrage avec succès de $Application au  $IDServer $IPServer " >>Sauvegarde.log
        return 0
else
        echo "Échec démarrage de $Application au serveur $IDServer $IPServer " >>Sauvegarde.log
        return 1
fi
}

function startPreviousServer(){

Indice=$1

for i in `seq $Indice -1 0 `
do

start ${InfoServer[2*$i]} ${InfoServer[2*$i+1]} $service >> /dev/null


done

}
##################################

cat Logoproject.txt

gnome-terminal -- tail -f Sauvegarde.log 2>&1


echo "########Tentative de Sauvegarde à $var2#######" >> Sauvegarde.log


for i in `seq 0 $NBRM1 `
do


	ssh -q ${InfoServer[2*$i]}@${InfoServer[2*$i+1]} echo > /dev/null

	if [ "$?" == "255" ]

	then
        	echo "Connection impossible avec  ${InfoServer[2*$i]} ${InfoServer[2*$i+1]} " >>Sauvegarde.log


	else

        	echo "Connection établie avec ${InfoServer[2*$i]} ${InfoServer[2*$i+1]} " >>Sauvegarde.log

		((j+=1))
	fi

done

ssh -q $IDServerDataBase@$IPServerDataBase echo > /dev/null

if [ "$?" == "255" ]

	then
        	echo "Connection impossible avec le serveur  $IDServerDataBase $IPServerDataBase de Base de donées " >>Sauvegarde.log


        else

                echo "Connection établie avec le serveur  $IDServerDataBase $IPServerDataBase de Base de donées  " >>Sauvegarde.log
		((j+=1))
        fi

ssh -q $IDServerSauvegard@$IPServerSauvegard echo > /dev/null 

if [ "$?" == "255" ]

        then
                echo "Connection impossible avec le serveur  $IDServerSauvegard $IPServerSauvegard de sauvegarde" >>Sauvegarde.log


        else

                echo "Connection établie avec le serveur  $IDServerSauvegard $IPServerSauvegard de sauvegarde" >>Sauvegarde.log
                ((j+=1))
        fi



if [ "$j" == "$NBRP2" ]
then
	echo "La disponibilité des serveurs pour la communication SSH est vérifiée avec succés " >>Sauvegarde.log
	echo "Start Sauvegard" >>Sauvegarde.log



	let check=$NBRP1
	i=0
	while [ $i -le $NBRM1 ]
        do
		if [ "$check" == "$NBRP1" ]
		then

			echo "Vérificarion du status de $service dans ${InfoServer[2*$i]} ${InfoServer[2*$i+1]} ">>Sauvegarde.log
	                 ligne=$(ssh ${InfoServer[2*$i]}@${InfoServer[2*$i+1]}  systemctl is-active $service )

			if [ "$ligne" = "active" ]
        		then

				 Stop ${InfoServer[2*$i]} ${InfoServer[2*$i+1]} $service >> /dev/null

			 	if [ "$?" == "0" ]
                         	then
					((T++))

			 	else
					check=$i
                                	echo "Problème d'arrét $service au serveur ${InfoServer[2*$i]} ${InfoServer[2*$i+1]}" >>Sauvegarde.log

				fi

			elif [ "$ligne" = "inactive" ]
			then
				echo " L'application $service est déjà en arrét au serveur ${InfoServer[2*$i]} ${InfoServer[2*$i+1]}" >>Sauvegarde.log

				check=$i
				echo $check
			fi
		else
			break
		fi
	((i++))


	done
	if [ "$check" != "0" ] && [ $check -le $Nbr_Server ]
	then
		echo "Intéruption du sauvgarde : redémarage des applications " >>Sauvegarde.log
		startPreviousServer $check >>/dev/null

	fi

	if [ "$check" == "0" ]
	then
		echo "Intéruption du sauvgarde : redémarage des applications " >>Sauvegarde.log
		start ${InfoServer[0]} ${InfoServer[1]} $service >> /dev/null
	fi

	if [ "$T" == "$Nbr_Server" ]
	then
		echo " Start shutdown Database " >>Sauvegarde.log

		Stop $IDServerDataBase $IPServerDataBase mariadb

		if [ "$?" == "0" ]
        	then
        		##start sauvegard

	ssh $IDServerDataBase@$IPServerDataBase sudo tar -czf /home/pi/AllSauvegardeDataBase/${NameFileSauvegarde}.tar   /var/lib/mysql

		scp $IDServerDataBase@$IPServerDataBase:/home/pi/AllSauvegardeDataBase/${NameFileSauvegarde}.tar /home/mohyi/ProjetLinux/SauvegardIntermédiaire


			scp /home/mohyi/ProjetLinux/SauvegardIntermédiaire/${NameFileSauvegarde}.tar  $IDServerSauvegard@${IPServerSauvegard}:/home/kalimohyi/Sauvegarde

			start $IDServerDataBase $IPServerDataBase mariadb >> /dev/null
                	startPreviousServer $NBRM1
			echo "Sauvegarde Terminer"



        	else
		echo "Échec d'arrêt de mariadb" >>Sauvegarde.log
        	echo "Intéruption du sauvegarde : redémarage des applications " >>Sauvegarde.log

		StartPreviousServer $NBRM1

		echo"Error:Vérifie Sauvegarde.log"

        	fi



	else
		echo "arret Sauvegaed vérifier les Serveurs "
		echo " Vérifie Sauvegarde.log"
	fi




else


	echo "Impossible de sauvegard : un ou plusieurs serveurs sont injoignable en SSH" >>Sauvegarde.log
	echo " Error:Vérifie Sauvegarde.log"

fi




exit
