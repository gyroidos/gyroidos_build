# shellcheck shell=bash

error_check(){
if [ "$1" != "0" ]; then
  echo "Error: $2"
  cleanup
  exit 1
fi
}

assert_file_exists(){
if [ ! -f "$1" ]; then
  echo "Error: Missing file $1"
  cleanup
  exit 1
fi
}

assert_file_not_exists(){
if [ -f "$1" ]; then
  echo "Error: File $1 exists. Precautional exit"
  exit 1
fi
}

set_newkey_args(){
local key_type=${1}
if [[ "${key_type}" =~ ^rsa:([0-9]+)$ ]]; then
	local key_size="${BASH_REMATCH[1]}"
	NEWKEY_ARGS_primary=(-newkey "rsa:${key_size}")
	NEWKEY_ARGS_secondary=(-newkey "rsa-pss" -pkeyopt "rsa_keygen_bits:${key_size}")
	SIGOPT_ARGS=(-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1)
elif [[ "${key_type}" =~ ^ec:(.+)$ ]]; then
	local curve="${BASH_REMATCH[1]}"
	NEWKEY_ARGS_primary=(-newkey ec -pkeyopt "ec_paramgen_curve:${curve}")
	NEWKEY_ARGS_secondary=("${NEWKEY_ARGS_primary[@]}")
	SIGOPT_ARGS=()
else
	NEWKEY_ARGS_primary=(-newkey "${key_type}")
	NEWKEY_ARGS_secondary=("${NEWKEY_ARGS_primary[@]}")
	SIGOPT_ARGS=()
fi
}
