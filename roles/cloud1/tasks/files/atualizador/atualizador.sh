#!/bin/bash

echo "Parando o tomcat com KILLJAVA"
service tomcat stop

cd /tmp/versoes/

for I in $(ls -1 *.sql);
   do
     echo "Atualizando base de dados..."
     mysql -uunosol -p#prudencia5! -C -f < $I;
     rm $I;
   done

for I in $(ls -1 *.war | grep -v ucommerce);
   do
      work=$(echo $I | cut -f 1 -d '.')
      rm -rf /var/tomcat/work/Catalina/localhost/$work;
      rm -rf /var/tomcat/webapps/$work
      mv /tmp/versoes/$I /var/tomcat/webapps/
      chown tomcat.unosol /var/tomcat/webapps/*.war
    done

echo "Subindo o Tomcat..."
service tomcat start

rm /tmp/versoes/*.war
rm /tmp/versoes/*.sql

echo "Processo finalizado"
   
