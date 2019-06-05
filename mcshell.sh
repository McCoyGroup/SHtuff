#! /bin/bash --init-file

MCSHELL_ROOT=$(dirname $(dirname "$0"))
MCLIB=$MCSHELL_ROOT/Common/mclib.sh
if [ -f "$MCLIB" ]
	then ""
	else
		MCSHELL_ROOT=~/Documents/UW/Research
		MCLIB=$MCSHELL_ROOT/Common/mclib.sh
fi

function mcload {
	local curdir;
	curdir=${PWD};
	cd $(dirname $MCLIB )
	source $MCLIB
	cd $curdir
	}

PS1='\u\$ '
PROMPT_COMMAND='echo -ne "\033]0;MCSESSION: ${PWD}\007"'
cd $MCSHELL_ROOT
