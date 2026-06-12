#!/bin/bash

help() {
  echo "Usage: $1 <options>"
  echo "       -c : Clean capif services tmp files"
  echo "       -m : Clean monitoring service tmp files"
  echo "       -t : Clean robot-test service tmp files"
  echo "       -d : Clean docs folder tmp files"
  echo "       -a : Clean all tmp files"
  echo "       -h : show this help"
  exit 1
}

if [[ $# -lt 1 ]]
then
  echo "You must specify an option before run script."
  help
fi


FILES=()
echo "${FILES[@]}"

# Read params
while getopts "cmtdah" opt; do
  case $opt in
    c)
      echo "Remove capif services temporary files"
      FILES+=("services")
      ;;
    m)
      echo "Remove monitoring service temporary files"
      FILES+=("monitoring")
      ;;
    t)
      echo "Remove robot-test service temporary files"
      FILES+=("tests")
      ;;
    d)
      echo "Remove docs folder temporary files"
      FILES+=("docs")
      ;;
    a)
      echo "Remove all temporary files"
      FILES=("services" "monitoring" "tests" "docs")
      ;;
    h)
      help
      ;;
    \?)
      echo "Not valid option: -$OPTARG" >&2
      help
      exit 1
      ;;
    :)
      echo "The -$OPTARG option requires an argument." >&2
      help
      exit 1
      ;;
  esac
done
echo "after check"
echo "${FILES[@]}"

cd ..

for FILE in "${FILES[@]}"; do
  echo "Remove temporary files for $FILE"
  tmp_files=$(git ls-files . --ignored --exclude-standard --others --directory | grep $FILE)
  if [[ $tmp_files ]]; then
    sudo rm -r $tmp_files
    status=$?
    if [ $status -eq 0 ]; then
        echo "*** Removed tmp files from $FILE ***"
    else
        echo "*** Some files from $FILE failed on removing ***"
    fi
  else
    echo "No files found"
  fi
done


echo "Remove tmp files complete."
cd ./services