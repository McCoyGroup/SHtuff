MAIN_USER="b3m2a1"
MAIN_PARTITION="cori"

### Pull user and partition stuff
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

function scratch {
  local user=$(_get_user "$1");

  echo /global/cscratch1/sd/$user

}

function homes {
  local user=$(_get_user "$1");

  echo /global/homes/${user:0:1}/$user

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

### get_node
NERSC_GET_NODE_FLAGS="N:C:q:t:"
function get_node {

  local node_nums;
  local core_type;
  local doop_type;
  local time_time;

  node_nums=$(mcoptvalue "$NERSC_GET_NODE_FLAGS" "N" "$@");
  core_type=$(mcoptvalue "$NERSC_GET_NODE_FLAGS" "C" "$@");
  doop_type=$(mcoptvalue "$NERSC_GET_NODE_FLAGS" "q" "$@");
  time_time=$(mcoptvalue "$NERSC_GET_NODE_FLAGS" "t" "$@");

  if [ "$node_nums" == "" ]
    then node_nums=1
  fi
  if [ "$core_type" == "" ]
    then core_type=haswell
  fi
  if [ "$doop_type" == "" ]
    then doop_type=interactive
  fi
  if [ "$time_time" == "" ]; then
    time_time="01:00:00"
  fi

  arg_str=$(mcargs "$NERSC_GET_NODE_FLAGS" $@)

  echo "Requesting $node_nums nodes for $time_time"
  salloc -N $node_nums -C $core_type -t $time_time --qos=$doop_type $arg_str

}

function _get_pyth {
  local pyth;

  pyth="$1";
  if [ "$pyth" == "" ]
    then pyth=3.7
  fi

  echo $pyth
}

function _get_venv {
  local pyth;
  local name;

  pyth=$(_get_pyth "$1");
  name=$(_get_user "$2");

  echo "$name-python$pyth"

}

NERSC_LOAD_VENV_FLAGS="p:s:"
function load_conda {

  local pyth;
  local subversion;

  pyth=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "p" "$@");
  pyth=$(_get_pyth "$pyth");
  subversion=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "s" "$@");

  if [ "$subversion" == "" ];
    then subversion="4.4";
  fi

  echo "module load python/$pyth-anaconda-$subversion"

}

NERSC_LOAD_VENV_FLAGS="n:p:"
function load_venv {

  local pyth;
  local name;

  name=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "n" "$@");
  name=$(_get_user "$name");
  pyth=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "p" "$@");
  pyth=$(_get_pyth "$pyth");

  echo "source activate $(_get_venv $pyth $name)"

}

NERSC_MAKE_VENV_FLAGS="n:p:"
function make_venv {

  local python;
  local name;

  name=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "n" "$@");
  name=$(_get_user "$name");
  pyth=$(mcoptvalue "$NERSC_MAKE_VENV_FLAGS" "p" "$@");
  pyth=$(_get_pyth "$pyth");

  args=$(mcargs "$NERSC_MAKE_VENV_FLAGS" "$@");

  echo "conda create -n $(_get_venv $pyth $name) $args"

}

# mcopts: EXTRACT OPTIONS
#     Takes a flag pattern and call signature
#     Returns the opts

function mcopts {

  local flag_pat;
  local ignore_pat;
  local opt_string;
  local opt_whitespace;
  local opt;
  local OPTARG;
  local OPTIND;

  flag_pat="$1";
  shift
  ignore_pat="$1";
  shift

  while getopts "$flag_pat" opt; do
    if [[ $opt =~ $ignore_pat ]]
      then
        :
      else
        if [ "$opt_string" != "" ]
          then opt_whitespace=" ";
          else opt_whitespace="";
        fi;
        if [ "$OPTARG" != "" ]
          then opt_string="$opt_string$opt_whitespace-$opt $OPTARG"
          else opt_string="$opt_string$opt_whitespace-$opt"
        fi
    fi
  done

  echo $opt_string

}

# mcoptvalue: EXTRACT OPTION VALUE
#     Takes a flag pattern, opt key, and call signature
#     Returns the opt value for the key

function mcoptvalue {

  local flag_pat;
  local value_pat;
  local opt;
  local opt_string;
  local opt_whitespace;
  local OPTARG;
  local OPTIND;

  flag_pat="$1";
  shift
  value_pat="$1";
  shift

  while getopts ":$flag_pat:" opt; do
    case "$opt" in
      $value_pat)
        if [ "$opt_string" != "" ]
          then opt_whitespace=" ";
          else opt_whitespace="";
        fi;
        if [ "$OPTARG" == "" ]
          then OPTARG=true;
        fi
        opt_string="$opt_string$opt_whitespace$OPTARG"
        ;;
    esac;
  done

  OPTIND=1;

  if [ "$opt_string" == "" ]; then
    while getopts "$flag_pat" opt; do
      case "$opt" in
        $value_pat)
          if [ "$opt_string" != "" ]
            then opt_whitespace=" ";
            else opt_whitespace="";
          fi;
          OPTARG=true;
          opt_string="$opt_string$opt_whitespace$OPTARG"
          ;;
      esac;
    done
  fi

  echo $opt_string

}

# mcargs: EXTRACT ARGUMENTS
#     Takes a flag pattern and call signature
#     Returns just the args

function mcargs {

  local flag_pat;
  local opt;
  local OPTARG;
  local OPTIND;

  flag_pat="$1";
  shift

  while getopts "$flag_pat" opt; do
      :
  done
  shift "$((OPTIND -1))";

  echo "$@"

}
