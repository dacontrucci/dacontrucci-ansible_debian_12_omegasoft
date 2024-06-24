#!/bin/bash

set -o pipefail

#set -x

mkdir -p /root/.backup

echo >> /root/.backup/bkp_inc_mysql.log
exec >> /root/.backup/bkp_inc_mysql.log
exec 2>&1

CLIENTE="${1,,}"
FLAG_SUCESSO=".BACKUP_SUCCESS_AWS_BKP_INC_MYSQL"
BINLOG_FILES="/var/log/mysql/mysql-bin.*"
ERRO=0

echo "[`date`] ==== FIM DA ROTINA DE BACKUP INCRMENTAL DO MYSQL"

echo "[`date`] = Executando flush do log binario do MySQL"
mysqladmin flush-logs

if [ "$?" != "0" ]; then
     echo "[`date`] = Erro"
     ERRO=1
  else
     echo "[`date`] = OK"
fi


### O SNAPSHOT DO TAR E ZERADO PELO SCRIPT QUE GERA O BACKUP FULL DO SISTEMA. NORMALMENTE O BKP.SH
### VERIFICAR NO /ETC/CRONTAB

echo "[`date`] = Copiando os arquivos dos logs binarios para o storage"
tar -g /root/.backup/bkp_inc_mysql.snar -Ilbzip2 -c $BINLOG_FILES | aws s3 cp - s3://$CLIENTE-omegasoft/backup/mysql-inc/$(date +%H)h.tar.bz2

if [ "$?" != "0" ]; then
    echo "[`date`] = Erro"
    ERRO=1
  else
    echo "[`date`] = OK"
fi


##GRAVA O ARQUIVO/FLAG DE SUCESSO
mkdir -p /var/spool/.backup
echo "[`date`] = Gravando arquivo flag de sucesso."
if [ $ERRO -eq 0 ]; then
   touch /var/spool/.backup/$FLAG_SUCESSO
fi


echo "[`date`] ==== FIM DA ROTINA DE BACKUP INCRMENTAL DO MYSQL"
