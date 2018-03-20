#!/bin/sh
#
# check_age.sh
# usage: /bin/sh gpdb-check_age.sh <database_name>
#
# Check arguments
if [[ $# -eq 0 ]]; then
    echo 'Database name must be specified'
    exit 0
fi
# Everything will be done in utility mode now on
export PGOPTIONS="-c gp_session_role=utility"
# Prepare variables to use in the script
database=$1
now=`date +%Y%m%d_%H%M%S_%N`
segments="select hostname || ' ' || port || ' ' || content from gp_segment_configuration where preferred_role = 'p'"
wraparound_limit=2147483647
# Prepare sql to use in the script
sql_check_age="select age(datfrozenxid) from pg_database where datname = '${database}'"
sql_xid_stop_limit="show xid_stop_limit"
sql_xid_warn_limit="show xid_warn_limit"
# Loop over segments
psql -Atc "${segments}" postgres | while read host port content;
  do
    stop_limit=`psql -h ${host} -p ${port} -Atc "${sql_xid_stop_limit}" postgres`
    warn_limit=`psql -h ${host} -p ${port} -Atc "${sql_xid_warn_limit}" postgres`
    age=`psql -h ${host} -p ${port} -Atc "${sql_check_age}" postgres`
    
    echo -n "age of ${database} (seg${content} ${host}:${port}) = ${age}"
    if [ ${age} -gt ${wraparound_limit} ] || [ ${age} -le 0 ]
    then
        echo " ... ERROR [OVER WRAPAROUND LIMIT!]"
    elif [ ${age} -gt $((${wraparound_limit}-${stop_limit})) ]
    then
    echo " ... ERROR [OVER xid_stop_limit]"
    elif [ ${age} -gt $((${wraparound_limit}-${stop_limit}-${warn_limit})) ]
    then
        echo " ... WARN [OVER xid_warn_limit]"
    else
        echo " ... OK"
    fi
done
export PGOPTIONS=""
