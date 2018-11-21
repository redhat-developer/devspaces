CHE_DIR=$HOME/che
LS_DIR=${CHE_DIR}/ls-bayesian
LS_LAUNCHER=${LS_DIR}/launch.sh

AGENT_BINARIES_URI=https://github.com/fabric8-analytics/fabric8-analytics-lsp-server/releases/download/v0.1.42/ca-lsp-server.tar

mkdir -p ${CHE_DIR}
mkdir -p ${LS_DIR}


############################
### Install Bayesian LSP ###
############################

# Payload is tared and base64 encoded representation of `lsp/server/out`
if [ ! -f "${LS_DIR}/server.js" ]; then
    echo "Deploying com.redhat.bayesian.lsp server"
    cd ${LS_DIR}
    curl -sSL ${AGENT_BINARIES_URI} | tar vxj
fi

touch ${LS_LAUNCHER}
chmod +x ${LS_LAUNCHER}

NODE="node"
command -v node >/dev/null 2>&1 || NODE="nodejs"

echo "${NODE} ${LS_DIR}/server.js --stdio" > ${LS_LAUNCHER}
