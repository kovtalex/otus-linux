#!/bin/bash

logfolder=. # Путь до каталона с логами без последнего слеша
lockfile=/tmp/lockfile
timestampfile=/tmp/timestamp
mailfile=/tmp/mail.tmp
curTimestamp=$(date +"%Y %m %d %H %M %S")

# Добавляем перехват сигналов для удаления lock файла
trap 'rm -f "$lockfile"; exit $?' SIGINT SIGTERM

if [[ -f $lockfile ]]
then
  echo "The script is already running."
  exit 0
else
  touch $lockfile
fi

if [[ -f $timestampfile ]]
then
  timestamp=$(cat $timestampfile)
else
  timestamp="1970 01 01 00 00 00"
fi
echo "$curTimestamp" > $timestampfile


# Формирование заголовка отчета
add_header()
{
  awk -v timestamp="$timestamp" -v curTimestamp="$curTimestamp" '
  BEGIN {
    split(timestamp,data1," ")
    split(curTimestamp,data2," ")
    print sprintf("Временной диапазон анализа скрипта: %s-%s-%s %s:%s:%s - %s-%s-%s %s:%s:%s\n",data1[3],data1[2],data1[1],data1[4],data1[5],data1[6],data2[3],data2[2],data2[1],data2[4],data2[5],data2[6])
  }
  ' > $mailfile
}

# Вывод X IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
parsing_ips()
{
  {
    echo "Список IP адресов с наибольшим кол-вом запросов (топ 10)"
    awk -v timestamp="$timestamp" '
      function monStrToInt(mon){
        m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|")
        for(o=1;o<=m;o++)
        {
          months[d[o]]=sprintf("%02d",o)
        }
        return months[mon]
      }
      function dtimeToEpoch(dtime){
        split(dtime,data1,"[/:]")
        return mktime(sprintf("%s %s %s %s %s %s",data1[3],monStrToInt(data1[2]),data1[1],data1[4],data1[5],data1[6]),-3)
      }
      BEGIN {
        FS="\""
      }
      {  
        split($1,data2," ")
        gsub(/\[/,"",data2[4]) 
        if (dtimeToEpoch(data2[4])>mktime(timestamp,-3))
        {
          print data2[1]
        }
      }
    ' $1 | sort | uniq -c | sort -rn | head -n 10 | column -t
  } >> $mailfile
  printf "\n" >> $mailfile
}

# Вывод Y запрашиваемых адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
parsing_requests()
{
  {
    echo "Список запрашиваемых адресов с наибольшим кол-вом запросов (топ 10)"
    awk -v timestamp="$timestamp" '
      function monStrToInt(mon){
        m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|")
        for(o=1;o<=m;o++)
        {
          months[d[o]]=sprintf("%02d",o)
        }
        return months[mon]
      }
      function dtimeToEpoch(dtime){
        split(dtime,data1,"[/:]")
        return mktime(sprintf("%s %s %s %s %s %s",data1[3],monStrToInt(data1[2]),data1[1],data1[4],data1[5],data1[6]),-3)
      }
      BEGIN {
        FS="\""
      }
      {
        split($1,data2," ")
        gsub(/\[/,"",data2[4])
        if (dtimeToEpoch(data2[4])>mktime(timestamp,-3))
        {
          split($2,data3," ")
          if (data3[1]=="POST" || data3[1]=="GET")
          {
            print data3[2]
          }
        }
      }
    ' $1 | sort | uniq -c | sort -rn | head -n 10 | column -t
  } >> $mailfile
  printf "\n" >> $mailfile
}

# Вывод всех ошибок c момента последнего запуска скрипта
parsing_errors()
{
  {
    echo "Список ошибок"
    awk -v timestamp="$timestamp" '
    BEGIN {
      FS="\""
    }
    function monStrToInt(mon){
      m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|")
      for(o=1;o<=m;o++)
      {
        months[d[o]]=sprintf("%02d",o)
      }
      return months[mon]
    }
    function dtimeToEpoch(dtime){
      split(dtime,data1,"[/:]")
      return mktime(sprintf("%s %s %s %s %s %s",data1[3],monStrToInt(data1[2]),data1[1],data1[4],data1[5],data1[6]),-3)
    }
    {
      split($1,data2," ")
      gsub(/\[/,"",data2[4])
      if (dtimeToEpoch(data2[4])>mktime(timestamp,-3))
      {
        split($2,data3," ")
        if (data3[1]!="POST" && data3[1]!="GET")
        {     
          print data3[1]
        }
      }
    }
    ' $1 | sort | uniq -c | sort -rn | column -t
  } >> $mailfile
  printf "\n" >> $mailfile
}

# Вывод списка всех кодов возврата с указанием их кол-ва с момента последнего запуска
parsing_statuses()
{
  {
    echo "Список кодов возврата"
    awk -v timestamp="$timestamp" '
    BEGIN {
      FS="\""
    }
    function monStrToInt(mon){
      m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|")
      for(o=1;o<=m;o++)
      {
        months[d[o]]=sprintf("%02d",o)
      }
      return months[mon]
    }
    function dtimeToEpoch(dtime){
      split(dtime,data1,"[/:]")
      return mktime(sprintf("%s %s %s %s %s %s",data1[3],monStrToInt(data1[2]),data1[1],data1[4],data1[5],data1[6]),-3)
    }
    {
      split($1,data2," ")
      gsub(/\[/,"",data2[4])
      if (dtimeToEpoch(data2[4])>mktime(timestamp,-3))
      {
        split($3,data3," ")
        print data3[1]
      }
    }
    ' $1 | sort | uniq -c | sort -rn | column -t
  } >> $mailfile
  printf "\n" >> $mailfile
}

add_header
parsing_ips ${logfolder}"/*.log"
parsing_requests ${logfolder}"/*.log"
parsing_errors ${logfolder}"/*.log"
parsing_statuses ${logfolder}"/*.log"


mail -s "Отчет о работе nginx" admin@localhost < $mailfile
rm -f "$lockfile"; exit $?
