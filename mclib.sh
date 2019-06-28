############################################################################
###########################     DEFAULTS       #############################
############################################################################

MCLIB_DIRECTORY=$(dirname "$0")
if [ "$MCLIB_DIRECTORY" == "/bin" ]
  then MCLIB_DIRECTORY=${PWD}
fi
. $MCLIB_DIRECTORY/private/mcparams.sh
#MCDEFAULT_CONNECTION; # the default connection to use with mcconnect
#MCDEFAULT_SLURP; # whether the default connection points to hyak or nersc


############################################################################
#############################  CONSTANTS  ##################################
############################################################################

if [ "$MCDEFAULT_DIRECTORY" == "" ]
  then
    MCDEFAULT_DIRECTORY=$(dirname "$MCLIB_DIRECTORY")
fi
function mcdir {
  echo $MCDEFAULT_DIRECTORY
}

MOX_CHEMDIR=/gscratch/chem/
function moxdir {
  local user="$1";
  if [ "$user" == "" ]
    then user=$MCDEFAULT_USER;
  fi;
  echo $MOX_CHEMDIR/$user
}

############################################################################
###########################      SERVER        #############################
############################################################################

# mcserver: MCCOY GROUP SERVER NAME
#     builds server spec from s (server) and u (user)

MCSERVER_FLAGS="s:u:h:";
function mcserver {
  local me;
  local slurper;
  local cpu;
  local fp;
  local opt;
  local server;
  local connspec;
  local default_me;
  local default_cpu;
  local default_slurp;
  local default_server;
  local OPTARG;
  local OPTIND;

  ### Update from options
  while getopts ":$MCSERVER_FLAGS" opt; do
    OPTARG=$(_str_strip "$OPTARG");
    case $opt in
        s)
          cpu="$OPTARG";
          ;;
        u)
          me="$OPTARG";
          ;;
        h)
          if [ "$OPTARG" == "" ]
            then
              slurper="hyak";
            else
              slurper="$OPTARG"
          fi
          ;;
    esac
  done

  ### Specification of the default values

  if [ "$MCDEFAULT_CONNECTION" != "" ]
    then
      connspec=($(_split_server $(basename $MCDEFAULT_CONNECTION)));
      default_me=${connspec[0]};
      default_cpu=${connspec[1]};
      default_server=${connspec[2]}
  fi

  if [ "$default_me" == "" ]; then
    default_me="$MCDEFAULT_USER";
  fi

  if [ "$MCDEFAULT_SLURP" == "hyak" ] && ( [ "$default_server" == "" ] || [ "$default_server" == "$MCDEFAULT_HYAK_SERVER" ] )
    then
      default_slurp="$MCDEFAULT_HYAK_SERVER"
    else
      if [ "$MCDEFAULT_SLURP" == "nersc" ] && ( [ "$default_server" == "" ] || [ "$default_server" == "$MCDEFAULT_NERSC_SERVER" ] )
        then
          default_slurp="$MCDEFAULT_NERSC_SERVER"
        else
          default_slurp=""
      fi
  fi

  if [ "$slurper" == "" ]
    then slurper="$default_slurp"
  fi

  if [ "$slurper" == "" ]
    then
      if ( [ "$default_cpu" == "mox" ] || [ "$default_cpu" == "ikt" ] || [ !"$default_cpu" ] )
        then default_cpu="$MCDEFAULT_CPU";
      fi
      if [ "$default_server" == "" ] || [ "$default_server" == "$MCDEFAULT_HYAK_SERVER" ]
        then default_server="$MCDEFAULT_SERVER";
      fi
    else
      if [ "$slurper" == "nersc" ]
        then
          if [ "$default_cpu" != "cori" ]
            then default_cpu="$MCDEFAULT_NERSC_CPU";
          fi
          default_server="$MCDEFAULT_NERSC_SERVER";
        else
          if [ "$default_cpu" != "mox" ] && [ "$default_cpu" != "ikt" ]
            then default_cpu="$MCDEFAULT_HYAK_CPU";
          fi
          default_server="$MCDEFAULT_HYAK_SERVER";
        fi

  fi

  if [ "$cpu" == "" ]; then cpu="$default_cpu"; fi
  if [ "$me" == "" ]; then me="$default_me"; fi
  if [ "$server" == "" ]; then server="$default_server"; fi

  # if specified cpu is not ikt or mox we can't use Hyak
  if [ "$server" == "$MCDEFAULT_HYAK_SERVER" ] && [ "$cpu" != "ikt" ] && [ "$cpu" != "mox" ]
    then
      if [ "$default_server" == "" ] || [ "$default_server" == "$MCDEFAULT_HYAK_SERVER" ]
        then server="$MCDEFAULT_SERVER";
        else server="$default_server";
      fi
  fi
  # if specified cpu is not cori we can't use NERSC
  if [ "$server" == "$MCDEFAULT_NERSC_SERVER" ] && [ "$cpu" != "cori" ]
    then
      if [ "$default_server" == "" ] || [ "$default_server" == "$MCDEFAULT_HYAK_SERVER" ]
        then server="$MCDEFAULT_SERVER";
        else server="$default_server";
      fi
  fi

  echo "$me@$cpu.$server"
}

############################################################################
###########################       SSH          #############################
############################################################################

# mcssh: SSH INTO MCCOY GROUP SERVER
#     adds params to ssh from mcserver

MCSSH_FLAGS="46AaCfgKkMNnqPTtVvXxYyZ:b:c:D:E:e:F:f:i:I:J:L:l:m:O:o:p:Q:S:W:w:";
function _mcssh_like {

    local base_cmd;
    local default_port;
    local caps_port;
    local port_flag;
    local port_arg;
    local server;
    local opt;
    local opt_string;
    local after_args;
    local cmd;
    local OPTARG;
    local OPTIND;
    local server_config;
    local opt_whitespace;
    local fp;
    local args;
    local conn;
    local all_flags;
    local hyak;
    local host;

    base_cmd=$1; shift;

    ### Specification of the port

    opt_string="";
    after_args="";
    server_config="";
    all_flags=":$MCSSH_FLAGS$MCSERVER_FLAGS";
    port_flag="p";
    while getopts "$all_flags" opt; do
      case "$opt" in
        s|u)
          if [ "$server_config" == "" ]
            then
              server_config="-$opt $OPTARG"
            else
              server_config="$server_config -$opt $OPTARG"
          fi
          ;;

        L|g)
          if [ "$after_args" == "" ]
            then
              after_args="-$opt $OPTARG"
            else
              after_args="$after_args -$opt $OPTARG"
            fi
            ;;
        h)
          if [ "$OPTARG" == "" ]
            then
              hyak="hyak";
            else
              hyak="$OPTARG"
          fi
          if [ "$server_config" == "" ]
            then
              server_config="-$opt $hyak"
            else
              server_config="$server_config -$opt $hyak"
          fi
          ;;
        P)
          port_flag="P";
          ;;
        p)
          port_arg="$OPTARG";
          ;;
        Z)
          conn="$OPTARG"
          ;;
        *)
          if [ "$opt_string" != "" ]
            then opt_whitespace=" ";
            else opt_whitespace="";
          fi;
          if [ "$OPTARG" != "" ]
            then opt_string="$opt_string$opt_whitespace-$opt $OPTARG"
            else opt_string="$opt_string$opt_whitespace-$opt"
          fi
          ;;
      esac;
    done
    shift "$((OPTIND -1))";

    server=$(mcserver $server_config);
    if [ "$hyak" == "" ]
      then
        host=$(_get_host "$server");
        if [ "$host" == "hyak.uw.edu" ]
          then hyak="hyak";
        fi
    fi;
    cmd=$(_add_port_arg "$cmd" "$port_flag" "$port_arg" "$hyak");
    cmd=$(_add_connection_arg "$cmd" "$server" "$conn");

    if [ "$opt_string" != "" ]
      then opt_string=" $opt_string"
    fi
    if [ "$after_args" != "" ]
      then after_args=" $after_args"
    fi
    cmd="$cmd$opt_string $server$after_args"

    fp="$1";
    shift;

    args="$@";

    if [ "$fp" != "" ];
      then cmd="$cmd:$fp";
    fi

    if [ "$args" != "" ];
      then cmd="$cmd $args";
    fi

    echo "$base_cmd $cmd"
    # echo $base_cmd $cmd

}

function mcssh {

  $(_mcssh_like ssh $@)

}

function mcsftp {

  $(_mcssh_like sftp -P $@)

}

############################################################################
###########################       SCP          #############################
############################################################################

# mcscp: SCP INTO MCCOY GROUP SERVER
#     adds params to scp from mcserver

MCSCP_FLAGS="UEZ:u:s:346BCpqrvF:i:l:o:P:S:";
function _mcscp_like {

  local base_cmd;
  local conn;
  local default_port;
  local port_flag;
  local port_arg;
  local hyak;
  local server;
  local opt;
  local opt_string;
  local cmd;
  local OPTARG;
  local OPTIND;
  local server_config;
  local echo_command;
  local opt_whitespace;
  local upload;
  local file_1;
  local file_2;
  local use_persistent;
  local all_flags;

  base_cmd="$1"; shift;
  opt_string="";
  server_config="";
  echo_command=0;
  upload=0;
  all_flags=":$MCSCP_FLAGS$MCSERVER_FLAGS"
  while getopts "$all_flags" opt; do
    case "$opt" in
      s|u)
        if [ "$server_config" == "" ]
          then
            server_config="-$opt $OPTARG"
          else
            server_config="$server_config -$opt $OPTARG"
        fi
        ;;
      h)
        if [ "$OPTARG" == "" ]
          then
            hyak="hyak";
          else
            hyak="$OPTARG"
        fi
        if [ "$server_config" == "" ]
          then
            server_config="-$opt $hyak"
          else
            server_config="$server_config -$opt $hyak"
        fi
        ;;
      U)
        upload=1;
        ;;
      Z)
        conn="$OPTARG";
        ;;
      P)
        port_arg="-$opt $OPTARG"
        ;;
      E)
        echo_command=1;
        ;;
      *)
        if [ "$opt_string" != "" ]
          then opt_whitespace=" ";
          else opt_whitespace="";
        fi;
        if [ "$OPTARG" != "" ]
          then opt_string="$opt_string$opt_whitespace-$opt $OPTARG"
          else opt_string="$opt_string$opt_whitespace-$opt"
        fi
        ;;
    esac;
  done
  shift "$((OPTIND -1))";

  server=$(mcserver $server_config);
  if [ "$upload" != 1 ]
    then
      file_1=$server:$1;
      file_2=$2;
    else
      file_1=$1;
      file_2=$server:$2;
  fi

  opt_string=$(_add_port_arg "$opt_string" "P" "$port_arg" "$hyak");
  opt_string=$(_add_connection_arg "$opt_string" "$server" "$conn");
  #opt_string="$opt_string $server";

  if [ "$opt_string" ]; then opt_string="$opt_string "; fi

  if [ "$echo_command" == 1 ]
    then echo "$opt_string$file_1 $file_2";
  fi

  echo "$base_cmd" $opt_string"$file_1" "$file_2";

}

function mcscp {

  $(_mcscp_like scp $@)

}
############################################################################
############################  UPLOAD/DOWNLOAD  #############################
############################################################################

function mcupload {

  mcscp -U $@

}

function mcdownload {

  mcscp $@

}

############################################################################
########################## PERISTENT CONNECTIONS ###########################
############################################################################

# mclose: CLOSE SSH INTO MCCOY GROUP SERVER
#     closes persistent background connection to server

function mcclose {

  local conn;
  local quiet;
  local serv;
  local use_def;
  local params;

  conn=$(mcoptvalue "$MCSERVER_FLAGS|q|Z:" "Z" "$@");
  quiet=$(mcoptvalue "$MCSERVER_FLAGS|q|Z:" "q" "$@");

  if [ "$conn" == "" ]
    then
      if [ "$MCDEFAULT_CONNECTION" != "" ]
        then
          use_def=1;
          conn=$MCDEFAULT_CONNECTION;
          serv=$(basename $conn);
      fi
    else
      serv=$(mcserver $(mcopts "$MCSERVER_FLAGS|q|Z:" "Z|q" "$@"));
      conn=~/.ssh/$(basename $conn);
  fi;

  if [ "$use_def" == 1 ]
    then
      MCDEFAULT_CONNECTION="";
      MCDEFAULT_SLURP="";
  fi

  if [ "$conn" != "" ]
    then
      params="-S $conn -O exit $serv"
      if [ $quiet ]; then params="-q $params"; fi;
      ssh $params
  fi

}

# mcconnect: PERMANENT SSH INTO MCCOY GROUP SERVER
#     configures persistent background connection to server

function mcconnect {

  local target;
  local socket;
  local conn;
  local hyak;
  local ssh_opts;
  local server_opts;

  socket=$(mcoptvalue "$MCSSH_FLAGS|$MCSERVER_FLAGS|Z:" "Z" "$@");
  hyak=$(mcoptvalue "$MCSSH_FLAGS|$MCSERVER_FLAGS|Z:" "h" "$@");
  server_opts=$(mcopts "$MCSSH_FLAGS|$MCSERVER_FLAGS|Z:" "Z" "$@");

  if [ "$socket" == "" ]
    then
      target=$(mcserver $server_opts);
      socket=~/.ssh/$target
    else
      socket=~/.ssh/$(basename $socket);
  fi

  # $(mcclose -Z "$socket" $server_opts);

  if [ "$target" != "" ]
    then
      MCDEFAULT_CONNECTION="$socket";
      MCDEFAULT_SLURP="$hyak";
  fi

  if [ "$server_opts" != "" ]
    then
      mcssh $server_opts -M -f -N -Z $socket
    else
      mcssh -M -f -N -Z $socket
  fi

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

############################################################################
###########################       CALL         #############################
############################################################################

# mccall: CALL W/E ON SERVER
#     takes a call args, same params as mcssh and mcscp

function mccall {

  local OPTARG;
  local OPTIND;
  local opts;
  local args;

  opts=$(mcopts "$MCSSH_FLAGS"Z: "" "$@");
  if [ "$opts" != "" ]; then opts="$opts "; fi

  args=$(mcargs "$MCSSH_FLAGS" "$@");

  mcssh $opts "" "$args"

}

# mcrun: RUN SCRIPT ON SERVER
#     takes a call args, same params as mcssh and mcscp

MCDIRECTORY_SCRIPTS=${PWD}/scripts
function mcrun {

  local OPTARG;
  local OPTIND;
  local opts;
  local file;
  local fname;
  local argcnt;
  local args;
  local cmd;
  local full_pat;
  local scp_ignore;
  local ssh_ignore;
  local ssh_opts;
  local scp_opts;

  full_pat="$MCSCP_FLAGS$MCSSH_FLAGS"Z:;
  ssh_ignore="U|3|B|r|P|M|G|R";
  scp_ignore="A|a|g|K|k|N|n|T|t|V|X|x|Y|y|b|c|D|e|f|I|J|L|m|O|Q|W|w|M|G|R";

  ssh_opts=$(mcopts "$full_pat" "$ssh_ignore" "$@");
  if [ "$ssh_opts" != "" ]; then ssh_opts="$ssh_opts "; fi
  scp_opts=$(mcopts "$full_pat" "$scp_ignore" "$@");
  if [ "$scp_opts" != "" ]; then scp_opts="$scp_opts "; fi

  args=( $(mcargs "$full_pat" "$@") );

  file=${args[0]};
  cmd="";
  if [ ! -f "$file" ];
    then
      cmd=$file;
      file=${args[1]};
      args=${args[@]:2}
    else
      args=${args[@]:1}
  fi
  fname=$(basename "$file");

  if [ "$file" ] && [ "$cmd" ]
    then
      mcscp -U $scp_opts"$file" _scripts/$fname;
      mccall $ssh_opts "" "$cmd _scripts/$fname $args"
    else
      echo "mcrun: No file passed"
  fi

}

# mccrun: RUN SCRIPT ON SERVER WITH PERSISTENT CONNECTION
#     chains mcconnect, mcrun, and mcclose

function mccrun {

  local servopts;
  local full_pat;
  local scp_ignore;
  local ssh_ignore;
  local runopts;
  local runargs;

  full_pat="$MCSCP_FLAGS""$MCSSH_FLAGS""$MCSERVER_FLAGS";
  scp_ignore="U|3|B|r|P|M|G|R";
  ssh_ignore="A|a|g|K|k|N|n|T|t|V|X|x|Y|y|b|c|D|e|f|I|J|L|m|O|Q|W|w|M|G|R";

  servopts=$(mcopts "$full_pat" "$MCSCP_FLAGS$MCSSH_FLAGS" "$@");

  mcconnect -Z _tmp_runner $servopts
  echo $(mcrun -Z _tmp_runner "$@")
  mcclose -Z _tmp_runner $servopts -q

}

############################################################################
###########################       RSA          #############################
############################################################################

# mcrsa: CONFIGURE RSA
#     adds params to ssh from mcserver

function mcrsa {

  local server;
  local username;
  local servername;
  local port;
  local hyak;
  local keyname;
  local response;
  local current_dir;
  local server_parts;
  local all_flags;

  all_flags=$MCSERVER_FLAGS;
  server=$(mcserver $@);

  server_parts=($(_split_server "$server"))

  username=${server_parts[0]};
  servername=${server_parts[1]};
  if [ "$username" == "" ]; then username="$MCDEFAULT_USER"; fi
  if [ "$servername" == "" ]; then servername="$MCDEFAULT_CPU"; fi

  port=$(mcoptvalue "p:$all_flags" "p" $@);
  hyak=$(mcoptvalue "$all_flags" "h" $@);
  if [ "$port" == "" ]
    then
      if [ "$hyak" == "" ]
        then
          port="-p $MCDEFAULT_PORT";
        else
          port="-p $MCDEFAULT_HYAK_PORT";
      fi
    else
      port="-p $port"
  fi

  keyname="mc_${servername}_rsa";
  current_dir="${PWD}";
  if [ ! -f "~/.ssh/$keyname" ]
    then
      read -p "Make new key-file? (Y/N) " response
      if [ "$response" = "Y" ]
      	then
      		ssh-add -d "$keyname"
      		mkdir -p ~/.ssh
      		cd ~/.ssh
      		chmod go-rwx ~/.ssh
      		ssh-keygen -t rsa -f "$keyname" -N ""
      		ssh-add "$keyname"
      		chmod go-rwx "$keyname"
      		chmod go-rwx "$keyname.pub"
      		cd "$current_dir"
          echo "Configuring server... (enter your password)"
          # echo "$port-o PubkeyAuthentication=no $server"
          cat ~/.ssh/"$keyname.pub" | ssh $port -o PubkeyAuthentication=no "$server" "mkdir -p ~/.ssh && cat >>  ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
          ssh $port "$server"
      	fi
     else
       echo "Key file already exists. If having login troubles contact me."
    fi

}

############################################################################
############################# GAUSSIAN STUFF ###############################
############################################################################

# mcg: GAUSSIAN RUN
#     takes a job, same params as mcssh and mcscp
#     adds in G param to specify how to call Gaussian

function mcg {

  local opt;
  local OPTARG;
  local OPTIND;
  local full_pat;
  local ssh_ignore;
  local scp_ignore;
  local opt_string;
  local arg_string;
  local do_mirror;
  local do_run;
  local g_call;
  local g_job;
  local ssh_opts;
  local scp_opts;

  full_pat="$MCSCP_FLAGS";
  scp_ignore="U|3|B|r|P|M|G|R";
  ssh_ignore="A|a|g|K|k|N|n|T|t|V|X|x|Y|y|b|c|D|e|f|I|J|L|m|O|Q|W|w|M|G|R";

  g_call=$(mcoptvalue "$full_pat" "G" "$@");
  if [ "$g_call" == "" ]
    then g_call="$MCDEFAULT_GAUSSIAN";
  fi

  do_mirror=$(mcoptvalue "$full_pat" "M" "$@");
  if [ "$do_mirror" != false ] && [ "$do_mirror" != 0 ]
    then do_mirror="1";
  fi

  do_run=$(mcoptvalue "$full_pat" "R" "$@");
  if [ "$do_run" != false ] && [ "$do_run" != 0 ]
    then do_run="1";
  fi


  ssh_opts=$(mcopts "$full_pat" "$ssh_ignore" "$@");
  if [ "$ssh_opts" != "" ]; then ssh_opts="$ssh_opts "; fi
  scp_opts=$(mcopts "$full_pat" "$scp_ignore" "$@");
  if [ "$scp_opts" != "" ]; then scp_opts="$scp_opts "; fi

  g_job=$(mcargs "$full_pat" "$@");
  g_job_name=$(basename "$g_job" ".gjf");
  g_job_dir=$(dirname "$g_job");

  # mirror the GJF up to the server
  if [ "$do_mirror" == "1" ]
    then mcscp -U $scp_opts"$g_job" gaussian_jobs
  fi

  # run the job and make an Formatted Checkpoint File after
  if [ "$do_run" == "1" ]
    then
      mcssh "$ssh_opts" <<RUNGAUSSIAN

cd gaussian_jobs;
echo "Starting job $g_job_name"
$g_call "$g_job_name".gjf
formchk "$g_job_name".chk
rm "$g_job_name".chk

RUNGAUSSIAN

  fi


}

# mcgcp: COPY GAUSSIAN RESULTS
#     takes a job, same params as mcssh and mcscp
#     L flag copies down the log file instead

function mcgcp {

  local OPTARG;
  local OPTIND;
  local opts;
  local slops;
  local get_log;
  local get_fchk;
  local g_job;
  local g_job_name;
  local g_job_file_base;
  local g_job_dir;

  opts=$(mcopts "L$MCSCP_FLAGS" "L" "$@");
  if [ "$opts" != "" ]; then opts="$opts "; fi
  get_log=$(mcoptvalue "LF$MCSCP_FLAGS" "L" "$@");
  if [ "$get_log" != true ]; then get_log=false; fi

  g_job=$(mcargs "L$MCSCP_FLAGS" "$@");
  g_job_name=$(basename "$g_job" ".gjf");
  g_job_file_base="gaussian_jobs/$g_job_name";
  g_job_dir=$(dirname "$g_job");

  slops=$(mcopts "$MCSCP_FLAGS" "L" "$@");
  mcconnect -Z _tmp_runner $slops
  mcscp $opts"$g_job_file_base.log" "$g_job_dir"
  mcscp $opts"$g_job_file_base.fchk" "$g_job_dir"
  mcclose -Z _tmp_runner -q $slops


}

# mcgrm: REMOVE GAUSSIAN RESULTS
#     takes a job, same params as mcssh and mcscp

function mcgrm {

  local opts;
  local g_job;
  local g_job_name;
  local g_job_server;
  local g_job_dir;

  opts=$(mcopts "$MCSSH_FLAGS" "" "$@");
  if [ "$opts" != "" ]; then opts="$opts "; fi

  g_job=$(mcargs "$MCSSH_FLAGS" "$@");
  g_job_name=$(basename "$g_job" ".gjf");

  mcssh $opts"rm gaussian_jobs/$g_job_name.fchk gaussian_jobs/$g_job_name.log"

}

############################################################################
############################# NUMPY STUFF ##################################
############################################################################

function mceigs {

  local eigargs;
  local matfile;
  local matdir;
  local matname;
  local upload;
  local servopts;
  local full_pat;
  local scp_ignore;
  local ssh_ignore;
  local verbose;
  local cmd;
  local outfile;

  full_pat="$MCSCP_FLAGS""$MCSSH_FLAGS""$MCSERVER_FLAGS";
  scp_ignore="U|3|B|r|P|M|G|R";
  ssh_ignore="A|a|g|K|k|N|n|T|t|V|X|x|Y|y|b|c|D|e|f|I|J|L|m|O|Q|W|w|M|G|R";

  servopts=$(mcopts "$full_pat" "$MCSCP_FLAGS$MCSSH_FLAGS" "$@");
  eigargs=( $(mcargs "$full_pat" "$@") );
  verbose=$(mcoptvalue "$full_pat" "V" "$@");
  upload=$(mcoptvalue "$full_pat" "U" "$@");

  matfile=${eigargs[0]};
  matname=$(basename $matfile);
  matdir=$(dirname $matfile);
  eigargs=${eigargs[@]:1};

  if [ ! $upload ] || [ -f $matfile ]
    then
      mcconnect -Z _tmp_runner $servopts
      if [ $upload ]; then
        if [ "$servopts" == "" ]
          then mcscp -Z _tmp_runner -U $matfile
          else mcscp -Z _tmp_runner $servopts -U $matfile
        fi
      fi
      cmd="python $MCDIRECTORY_SCRIPTS/eigs.py $matname $eigargs"
      if [ "$servopts" == "" ]
        then outfile=$(mccrun -Z _tmp_runner $cmd)
        else outfile=$(mccrun -Z _tmp_runner $servopts $cmd)
      fi
      if [ "$servopts" == "" ]
        then mcscp -Z _tmp_runner $outfile $matdir/$(basename $outfile)
        else mcscp -Z _tmp_runner $servopts $outfile $matdir/$(basename $outfile)
      fi
    else
      echo "file \'$matfile\' not found"
  fi


}


############################################################################
###################                                     ####################
#################          CONVENIENCE FUNCTIONS          ##################
###################                                     ####################
############################################################################

############################################################################
###########################     _str_split        ##########################
############################################################################

function _str_split {
  local sep;
  local str;
  local var;
  local arr;
  local IFS;

  str="$1";
  sep="$2";
  var="$3";
  if [ "$var" == "" ]
    then var="_SPLIT_STRING_ARRAY"
  fi
  IFS="$sep" read -ra arr <<< "$str";
  eval "$var=(${arr[@]})";

}


############################################################################
###########################     _str_strip        ##########################
############################################################################

function _str_strip {
  local trim;
  local mode;
  local str;
  local arr;

  str="$1";
  trim="$2";
  mode="$3";

  if ([[ "$trim" == ^* ]] || [[ "$trim" == *^ ]]) && [ "$mode" == "" ]
    then
      mode="$trim";
      trim=""
  fi

  if [ "$mode" == "" ]; then mode="^^"; fi;
  if [ "$trim" == "" ]; then trim="[:space:]"; fi;

  if [[ "$mode" == ^* ]]
    then str="${str#"${str%%[!$trim]*}"}";
  fi
  if [[ "$mode" == *^ ]]
    then str=${str%"${str##*[!$trim]}"};
  fi

  echo "$str"

}

############################################################################
###########################      _str_join        ##########################
############################################################################

function _str_join {
  local IFS;

  IFS="$1";
  shift;
  echo "$*"

}

############################################################################
#########################      _get_username        ########################
############################################################################

function _get_username {
  local server;
  local parts;

  server="$1";
  _str_split "$server" '@.' "server_split";
  echo "${parts[0]}"

}

############################################################################
#########################      _get_computer        ########################
############################################################################

function _get_computer {
  local server;
  local parts;

  server="$1";
  _str_split "$server" '@.' "server_split";
  echo "${parts[1]}"

}

############################################################################
#########################      _get_computer        ########################
############################################################################

function _get_host {
  local server;
  local parts;

  server="$1";
  _str_split "$server" '@.' "parts";
  echo $(_str_join '.' ${parts[@]:2})

}

############################################################################
#########################      _split_server        ########################
############################################################################

function _split_server {
  local server;
  local parts;
  local var;
  local username;
  local cpu;
  local host;

  server="$1";

  _str_split "$server" '@.' "parts"

  username="${parts[0]}";
  cpu="${parts[1]}";
  host="$(_str_join '.' ${parts[@]:2})";

  echo "$username $cpu $host"

}

############################################################################
#########################      _ssh_connected       ########################
############################################################################

function _ssh_connected {
  local ret;

  ssh -o "ControlPath=$1" -O check ":)" 2> /tmp/ssh_doop_doop
  ret=$(cat /tmp/ssh_doop_doop)
  rm /tmp/ssh_doop_doop
  if [[ "$ret"=Master* ]]
    then
      echo true
    else
      echo false
  fi

}

############################################################################
#########################       mcconnected        #########################
############################################################################

function mcconnected {
  local conn;
  local ret;

  conn=$MCDEFAULT_CONNECTION;
  if [ "$conn" ]
    then
      _ssh_connected "$conn"
    else
      echo false
  fi

}

############################################################################
######################      _add_connection_arg       ######################
############################################################################

function _add_connection_arg {
  local conn;
  local server;
  local cmd;

  cmd="$1";
  server="$2";
  conn="$3";

  if [ "$conn" == "" ] && [ "$MCDEFAULT_CONNECTION" != "" ] && [ "$server" == $(basename "$MCDEFAULT_CONNECTION") ]
    then
      conn="$MCDEFAULT_CONNECTION";
  fi;

  if [ "$conn" != "" ]
    then
      conn=~/.ssh/$(basename $conn)
      cmd="$cmd -o ControlPath=$conn"
  fi

  echo "$cmd"
}

############################################################################
#########################      _add_port_arg       #########################
############################################################################

function _add_port_arg {
  local flag;
  local arg;
  local cmd;

  cmd="$1";
  flag="$2";
  arg="$3";
  hyak="$4";

  if [ "$arg" == "" ]; then
    if [  "$hyak" == "" ];
      then
        arg="$MCDEFAULT_PORT"
      else
        if [ "$hyak" == "nersc" ]
          then
            arg="$MCDEFAULT_NERSC_PORT"
          else
            arg="$MCDEFAULT_HYAK_PORT"
        fi
    fi
  fi

  if [ "$cmd" == "" ]
    then cmd="-$flag $arg";
    else cmd="$cmd -$flag $arg";
  fi

  echo "$cmd"
}
