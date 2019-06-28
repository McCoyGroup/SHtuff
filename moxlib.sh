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

GSUBMIT_FLAGS="n:d:a:p:u:N:D:H:M:Z"
GSUBMIT_DEFAULT_PARTITION="stf"
GSUBMIT_DEFAULT_MEMORY="120G" # leave a bit to run...?
GSUBMIT_DEFAULT_DAYS="1"
GSUBMIT_DEFAULT_HOURS="00:00:00"
GSUBMIT_DEFAULT_NODES="1"
function gjobwrite {

  local job_file;
  local job_script;
  local name;
  local dir;
  local part;
  local account;
  local days;
  local hours;
  local mem;
  local nodes;
  local use_scr;
  local user;
  local job_log;

  # we'll allow different Gaussian versions at some point but not right now
  args=$(mcargs "$GSUBMIT_FLAGS" $@)
  job_file="${args[0]}"
  job_script="${args[1]}"
  if [ "$job_script" = "" ]; then
    job_script="${job_file%.*}.sh"
  fi

  dir=$(mcoptvalue "$GSUBMIT_FLAGS" 'd' $@)
  if [ "$dir" = "" ]; then
    dir=$(dirname $job_file)
  fi
  if [ "$dir" = "" ]; then
    dir="."
  fi

  name=$(mcoptvalue "$GSUBMIT_FLAGS" 'n' $@)
  if [ "$name" = "" ]; then
    name=$(basename $job_file)
    name="${name%.*}"
  fi

  part=$(mcoptvalue "$GSUBMIT_FLAGS" 'p' $@)
  if [ "$part" = "" ]; then
    part="$GSUBMIT_DEFAULT_PARTITION"
  fi
  case "$part" in
    "backfill")
      part="ckpt"
      ;;
  esac

  account=$(mcoptvalue "$GSUBMIT_FLAGS" 'a' $@)
  if [ "$account" = "" ]; then
    case "$part" in
      "ckpt")
        account="stf-ckpt"
        ;;
      *)
        account="$part"
        ;;
    esac
  fi

  nodes=$(mcoptvalue "$GSUBMIT_FLAGS" 'N' $@)
  if [ "$nodes" = "" ]; then
    nodes="$GSUBMIT_DEFAULT_NODES"
  fi
  days=$(mcoptvalue "$GSUBMIT_FLAGS" 'D' $@)
  if [ "$days" = "" ]; then
    days="$GSUBMIT_DEFAULT_DAYS"
  fi
  hours=$(mcoptvalue "$GSUBMIT_FLAGS" 'H' $@)
  if [ "$hours" = "" ]; then
    hours="$GSUBMIT_DEFAULT_HOURS"
  fi
  mem=$(mcoptvalue "$GSUBMIT_FLAGS" 'M' $@)
  if [ "$mem" = "" ]; then
    mem="$GSUBMIT_DEFAULT_MEMORY"
  fi

  use_scr=$(mcoptvalue "$GSUBMIT_FLAGS" 'Z' $@)
  if [ "$use_scr" = "" ]
    then use_scr="false"
    else
      use_scr="true"
      user=$(mcoptvalue "$GSUBMIT_FLAGS" 'u' $@)
      if [ "$user" = "" ]; then
        user=$(whoami)
      fi
      job_file_base=$(basename $job_file)
      job_log="${job_file_base%.*}.log"
  fi

  if [ "$use_scr" = "true" ]; then
    cat > "$job_script" <<GaussianJob
#!/bin/bash
#SBATCH --job-name=$name
#SBATCH --nodes=$nodes
#SBATCH --time=$days-$hours
#SBATCH --mem=$mem
#SBATCH --workdir=$dir
#SBATCH --partition=$part
#SBATCH --account=$account

# load Gaussian environment
module load contrib/g09.e01

# debugging information
echo "**** Job Debugging Information ****"
echo "This job will run on $SLURM_JOB_NODELIST"
echo ""
echo "ENVIRONMENT VARIABLES"
set
echo "**********************************************"

echo "Job starting: \$(date)"
curdir=\${PWD}
echo "Currently in \$curdir"

echo "Moving data to /scr/"
mkdir /scr/chem
mkdir /scr/chem/$user
cp $job_file_base /scr/chem/$user/$job_file_base

echo "Moving to /scr/"
cd /scr/chem/$user

echo "Running Gaussian job $job_file_base"
g09 $job_file_base

echo "Copying data back out to \$curdir"
mv /scr/chem/$user/$job_log \$curdir/$job_log
echo "Job complete: \$(date)"

GaussianJob

  else

  cat > "$job_script" <<GaussianJob
#!/bin/bash
#SBATCH --job-name=$name
#SBATCH --nodes=$nodes
#SBATCH --time=$job_time
#SBATCH --mem=$mem
#SBATCH --workdir=$dir
#SBATCH --partition=$part
#SBATCH --account=$account

# load Gaussian environment
module load contrib/g09.e01

# debugging information
echo "**** Job Debugging Information ****"
echo "This job will run on $SLURM_JOB_NODELIST"
echo ""
echo "ENVIRONMENT VARIABLES"
set
echo "**********************************************"

echo "Job starting: $(date)"
echo "Running Gaussian job $job_file_base"
g09 $job_file
echo "Job complete: $(date)"

exit 0

GaussianJob

fi

echo "$job_script"

}
function gsubmit {
  local script;
  script=$(gjobwrite $@);
  echo $(sbatch $script)
}

############################################################################
############################# ARG PARSE STUFF ##############################
############################################################################

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
