#!/bin/bash -e
#
# script to query latest tags of the FROM repos, and update Dockerfiles using the latest base images
# requires docker-ls container to be built locally -- see https://github.com/mayflower/docker-ls
# 
# thankfully, the https://registry.access.redhat.com is v2 and does not require authentication to query

WORKDIR=`pwd`
buildCommand="echo \"No build triggered: use -c for a container-build (or -s for scratch).\""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$1"; shift 1;;
    '-c') buildCommand="rhpkg container-build"; shift 0;; 
    '-s') buildCommand="rhpkg container-build --scratch"; shift 0;; 
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

pushedIn=0
for d in $(find ${WORKDIR} -name Dockerfile); do 
	if [[ -f ${d} ]]; then
		# pull latest commits
		if [[ -d ${d%%/Dockerfile} ]]; then pushd ${d%%/Dockerfile} >/dev/null; pushedIn=1; fi
		git checkout . && git pull -q
		if [[ ${pushedIn} -eq 1 ]]; then popd >/dev/null; pushedIn=0; fi

		QUERY=""
		FROMPREFIX=""
		LATESTTAG=""
		echo ""
		# echo "# Dockerfile = $d "
		URLs=$(cat $d | grep FROM -B1);
		for URL in $URLs; do
			# echo "URL=$URL"
			if [[ $URL == "https"* ]]; then 
				QUERY="$(echo $URL | sed -e "s#.\+registry.access.redhat.com/#docker run docker-ls docker-ls tags --registry https://registry.access.redhat.com #g" | tr '\n' ' ')"
				echo "# $QUERY|grep \"^-\"|egrep -v \"\\\"|latest\"|sort -V|tail -5"
				FROMPREFIX=$(echo $URL | sed -e "s#.\+registry.access.redhat.com/##g")
				LATESTTAG=$(${QUERY}|grep "^-"|egrep -v "\"|latest"|sed -e "s#^-##" -e "s#[\n\r\ ]\+##g"|sort -V|tail -1)
				echo "+ ${FROMPREFIX}:${LATESTTAG}"
			elif [[ $URL ]] && [[ $URL == "${FROMPREFIX}:"* ]]; then
				if [[ ${LATESTTAG} ]] && [[ "${URL}" != "${FROMPREFIX}:${LATESTTAG}" ]]; then # fix the Dockerfile
					echo "- ${URL}"
					echo "++ $d "
					sed -i -e "s#${URL}#${FROMPREFIX}:${LATESTTAG}#g" $d

					# commit change and push it
					if [[ -d ${d%%/Dockerfile} ]]; then pushd ${d%%/Dockerfile} >/dev/null; pushedIn=1; fi
					git commit -s -m "[update base] update from ${URL} to ${FROMPREFIX}:${LATESTTAG}" Dockerfile && git push
					echo "# ${buildCommand} &"
					${buildCommand} &
					if [[ ${pushedIn} -eq 1 ]]; then popd >/dev/null; pushedIn=0; fi
					fixedFiles="${fixedFiles} $d"
				fi
			fi
		done
	fi
done 
sleep 10s & wait

echo ""
if [[ $fixedFiles ]]; then
	echo "[update base] Fixed these files:"
	for d in $fixedFiles; do echo "++ $d"; done
else
	echo "[update base] No Dockerfiles changed - no new base images found."
fi

