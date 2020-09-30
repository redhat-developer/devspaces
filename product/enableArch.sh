#!/bin/bash
set -e 

DWNSTRM_BRANCH="crw-2.5-rhel-8"
usage()
{
    echo "
Usage: $0 [arch-to-enable]
Example: $0 ppc64le"
}
if [[ ! $1 ]]; then usage; exit; fi

ARCH=$1

for d in . */; do 
    if [[ -f $d/container.yaml ]]; then 
        echo; if [[ $d == "." ]]; then echo "== $(basename `pwd`) =="; else echo "== $d =="; fi
        cd $d
            grep -E " - ${ARCH}" -r || true
            if [[ $(grep -E "^ *# *- ${ARCH}" -r) ]]; then
                git fetch
                git checkout $DWNSTRM_BRANCH || true
                git pull origin $DWNSTRM_BRANCH || true
                sed -i container.yaml -r -e "s| *# *- ${ARCH}|  - ${ARCH}|" || true
                git commit -s -m "Enable ${ARCH} builds in container.yaml" container.yaml || true
                git push origin $DWNSTRM_BRANCH || true
            fi
        cd ..
    fi
done
