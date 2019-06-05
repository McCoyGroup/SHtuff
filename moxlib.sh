MAIN_USER="b3m2a1"
MAIN_PARTITION="stf"

function _get_user {
  local user="$1";

  if [ "$user" = "" ]
    then user=$MAIN_USER;
  fi;
  echo "$user"
}

function _get_part {
  local user="$1";

  if [ "$user" = "" ]
    then user=$MAIN_PARTITION;
  fi;
  echo "$user"
}

function chemdir {
  local user=$(_get_user "$1");

  echo /gscratch/chem/$user

}

function submit {
  echo $(sbatch $1.sh)
}

function uqueue {
  local user=$(_get_user "$1");

  squeue -u $user
}

function pqueue {
  local part=$(_get_part "$1");

  squeue -p $part
}

function get_node {
  local node="$1";
  local account="$2";
  shift
  shift
  local arg_str="$@";

  if [ "$node" = "" ]
    then node=build
  fi
  if [ "$account" != "" ]
    then account=" -A $account"
  fi
  if [ "$arg_str" = "max_res" ]
    then arg_str="--mem=60gb --ntasks=8 --time=0-8:00:00"
  fi
  if [ "$arg_str" != "" ]
    then arg_str=" $arg_str"
  fi

  srun -p$node$account$arg_str --pty /bin/bash

}

function build_node {

  get_node build "" $@

}

function backfill_node {

  get_node ckpt stf-ckpt $@
}
