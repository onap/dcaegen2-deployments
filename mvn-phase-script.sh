#!/bin/bash

echo "running script: [$0] for module [$1] at stage [$2]"

echo "=> Prepare environment "

# This is the base for where "deploy" will upload
# MVN_NEXUSPROXY is set in the pom.xml
REPO=$MVN_NEXUSPROXY/content/sites/raw

TIMESTAMP=$(date +%C%y%m%dT%H%M%S)
export BUILD_NUMBER="${TIMESTAMP}"

# expected environment variables
if [ -z "${MVN_NEXUSPROXY}" ]; then
    echo "MVN_NEXUSPROXY environment variable not set.  Cannot proceed"
    exit
fi
MVN_NEXUSPROXY_HOST=$(echo $MVN_NEXUSPROXY |cut -f3 -d'/' | cut -f1 -d':')


# use the version text detect which phase we are in in LF CICD process: verify, merge, or (daily) release

# mvn phase in life cycle
MVN_PHASE="$2"

case $MVN_PHASE in
clean)
  echo "==> clean phase script"
  # Nothing to do
  ;;
generate-sources)
  echo "==> generate-sources phase script"
  # Nothing to do
  ;;
compile)
  echo "==> compile phase script"
  # Nothing to do
  ;;
test)
  echo "==> test phase script"
  # Nothing to do
  ;;
package)
  echo "==> package phase script"
  # Nothing to do
  ;;
install)
  echo "==> install phase script"
  # Nothing to do
  ;;
deploy)
  echo "==> deploy phase script"
  # Just upload files to Nexus
  set -e -x
  function setnetrc {
    # Turn off -x so won't leak the credentials
    set +x
    hostport=$(echo $1 | cut -f3 -d /)
    host=$(echo $hostport | cut -f1 -d:)
    settings=$HOME/.m2/settings.xml
    ( echo machine $host; echo login $(xpath $settings "//servers/server[id='$hostport']/username/text()"); echo password $(xpath $settings "//servers/server[id='$hostport']/password/text()") ) >$HOME/.netrc
    chmod 600 $HOME/.netrc
    set -x
  }
  function putraw {
    curl -X PUT -H "Content-Type: text/plain" --netrc --upload-file $1 --url $REPO/$2
  }
  setnetrc $REPO
  putraw scripts/instconsulagentub16.sh cloud_init/instconsulagentub16.sh
  putraw scripts/cdap-init.sh cloud_init/cdap-init.sh
  set +e +x
  ;;
*)
  echo "==> unprocessed phase"
  ;;
esac

