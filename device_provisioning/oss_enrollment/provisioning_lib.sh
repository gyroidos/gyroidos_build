error_check(){
if [ "$1" != "0" ]; then
  echo "Error: $2"
  cleanup
  exit 1
fi
}

assert_file_exists(){
if [ ! -f $1 ]; then 
  echo "Error: Missing file $1"
  cleanup
  exit 1
fi
}

assert_file_not_exists(){
if [ -f $1 ]; then 
  echo "Error: File $1 exists. Precautional exit"
  exit 1
fi
}
