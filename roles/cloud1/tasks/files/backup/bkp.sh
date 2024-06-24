#!/bin/bash

set -o pipefail

cliente="${1,,}"
ERRO=0
ucommerce="/var/tomcat/webapps/UCOMMERCE/${1^}"
BUCKET_NAME="s3://$cliente-omegasoft"
BUCKET_FOLDER="backup/$1"
AWS_STORAGE_CLASS="--storage-class STANDARD_IA"
AWS_PROFILE="--profile default"
AWS_OPTIONS="$AWS_STORAGE_CLASS $AWS_PROFILE"
CMD_COPIA="aws s3 cp "
CMD_COPIA_PIPE="aws s3 cp - "
CMD_MYSQL_DUMP="mysqldump -f --single-transaction --routines --events --triggers --hex-blob --master-data --flush-logs"
TMP_FOLDER="/root/.backup/$1"
TMP_DUMP_FILE="atual.sql.bz2"
TMP_DUMP_FILE_NFE="atual.nfe.sql.bz2"
ADDITIONAL_FOLDERS="/etc"
DISK_DEVICE="/dev/sda"
FLAG_SUCESSO=".BACKUP_SUCCESS_AWS"
LOG_FILE="bkp.log"

clear

echo >> $TMP_FOLDER/$LOG_FILE
exec >> $TMP_FOLDER/$LOG_FILE
exec 2>&1

echo "[`date`] ==== INICIO DA ROTINA DE BACKUP"

mkdir -p $TMP_FOLDER

#Gerado o arquivo de particao
echo "[`date`] = Gerando arquivo de informacao de particao na pasta /etc."
sfdisk -d $DISK_DEVICE > /etc/partition.info

if [ "$?" != "0" ];
then
    echo "[`date`] = ERRO"
    ERRO=1
else echo "[`date`] = OK"
fi



###Cria o dump do banco de dados

echo "[`date`] = Criando dump do banco de dados. (db_uc_$cliente) na pasta temporaria"
$CMD_MYSQL_DUMP db_uc_$cliente | lbzip2 > $TMP_FOLDER/$TMP_DUMP_FILE

if [ $((${PIPESTATUS[0]}+${PIPESTATUS[1]}))  != 0 ];
then
    echo "[`date`] = ERRO"
    ERRO=1
else
    echo "[`date`] = OK"
fi

#copia o arquivo atual conforme mes do ano caso seja o ultima dia do mes senao copia conforme dia do mes.

if [[ $(date -d "+1 day" +%m) != $(date +%m) ]]
then
    echo "[`date`] = Copiando arquivo conforme mes e ano."
    arquivo=$(date +%Y).$(date +%b).'sql.bz2'
    
    $CMD_COPIA $TMP_FOLDER/$TMP_DUMP_FILE $BUCKET_NAME/$BUCKET_FOLDER/$arquivo $AWS_OPTIONS
    
    if [ "$?" != "0" ];
    then
        echo "[`date`] = ERRO"
        ERRO=1
    else echo "[`date`] = OK"
    fi
else
    #copia o arquivo conforme dia do mes
    echo "[`date`] = Copiando arquivo conforme dia do mes."
    arquivo=$(date +%d).'sql.bz2'
    $CMD_COPIA $TMP_FOLDER/$TMP_DUMP_FILE $BUCKET_NAME/$BUCKET_FOLDER/$arquivo $AWS_OPTIONS
    
    if [ "$?" != "0" ];
    then
        echo "[`date`] = ERRO"
        ERRO=1
    else echo "[`date`] = OK"
    fi
    
fi

###Cria o dump do banco de dados de notas fiscais
echo "[`date`] = Criando dump do banco de dados de notas fiscais."
$CMD_MYSQL_DUMP db_uc_${cliente}_nfe | lbzip2 > $TMP_FOLDER/$TMP_DUMP_FILE_NFE

if [ "$?" != "0" ];
then
    echo "[`date`] = ERRO"
    ERRO=1
else echo "[`date`] = OK"
fi

#copia o arquivo atual conforme mes do ano caso seja o ultimo dia do mes senao conforme o dia do mes.
if [[ $(date -d "+1 day" +%m) != $(date +%m) ]]
then
    echo "[`date`] = Copiando arquivo conforme mes e ano."
    arquivo=$(date +%Y).$(date +%b).'nfe.sql.bz2'
    $CMD_COPIA $TMP_FOLDER/$TMP_DUMP_FILE_NFE $BUCKET_NAME/$BUCKET_FOLDER/$arquivo $AWS_OPTIONS
    
    if [ "$?" != "0" ];
    then
        echo "[`date`] = ERRO"
        ERRO=1
    else echo "[`date`] = OK"
    fi
else
    #copia o arquivo conforme dia do mes
    echo "[`date`] = Copiando arquivo conforme dia do mes."
    arquivo=$(date +%d).'nfe.sql.bz2'
    $CMD_COPIA $TMP_FOLDER/$TMP_DUMP_FILE_NFE $BUCKET_NAME/$BUCKET_FOLDER/$arquivo $AWS_OPTIONS
    
    if [ "$?" != "0" ];
    then
        echo "[`date`] = ERRO"
        ERRO=1
    else echo "[`date`] = OK"
    fi
fi

#Gera o arquivo de backup da pasta UCOMMERCE do cliente incremental
if [ $(date +%d) -eq 1 ]; then
    #Limpa o snapshot do tar
    > $TMP_FOLDER/snapshot_ucommerce.snar
    
    echo "[`date`] = Gerando arquivo de backup do U-Commerce"
    tar -I lbzip2 -g $TMP_FOLDER/snapshot_ucommerce.snar -c $ucommerce $ADDITIONAL_FOLDERS | $CMD_COPIA_PIPE $BUCKET_NAME/$BUCKET_FOLDER/$(date +%Y.%m.%d).ucommerce.tar.bz2 $AWS_OPTIONS
    
else
    echo "[`date`] = Gerando arquivo de backup do U-Commerce"
    tar -I lbzip2 -g $TMP_FOLDER/snapshot_ucommerce.snar -c $ucommerce | $CMD_COPIA_PIPE $BUCKET_NAME/$BUCKET_FOLDER/$(date +%d).ucommerce.tar.bz2 $AWS_OPTIONS
    
    if [ "$?" != "0" ]; then
        echo "[`date`] = ERRO"
        ERRO=1
    else
        echo "[`date`] = OK"
    fi
fi

#ZERA O ARQUIVO DE SNAPSHOT DO BACKUP INCREMENTAL DO MYSQL
echo "[`date`] = Zerando arquivo de snapshot do backup incremental dos logs do MySQL."
if [ $ERRO -eq 0 ]; then
    > /root/.backup/bkp_inc_mysql.snar
fi

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

echo "[`date`] ==== FIM DA ROTINA DE BACKUP"
