#!/bin/sh

dirlocation=`pwd`/.
# If no argument is provided, use "main" as the default value
default_branch="main"
default_mon="false"
branch="${1:-$default_branch}"
monitoring="${2:-default_mon}"

echo "Selected branch: $branch"
echo "We're working with $dirlocation"
cd $dirlocation


updaterepo(){
        cd $dirlocation
        echo "Build " $1
        if [ ! -d $1 ]; then
                git clone https://labs.etsi.org/rep/ocf/$1.git
        fi

        cd $1/
        git checkout $branch
        git pull
}

updaterepo capif

cd $dirlocation
cd capif/services

./run.sh -m $monitoring