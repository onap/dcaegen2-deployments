#!/bin/bash

# ================================================================================
# Copyright (c) 2017-2022 AT&T Intellectual Property. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
#


set -ex

echo "running script: [$0] for module [$1] at stage [$2]"

MVN_PROJECT_MODULEID="$1"
MVN_PHASE="$2"
PROJECT_ROOT=$(dirname $0)

source "${PROJECT_ROOT}"/mvn-phase-lib.sh

TIMESTAMP=$(date +%C%y%m%dT%H%M%S)
export BUILD_NUMBER="${TIMESTAMP}"
shift 2

case $MVN_PHASE in
clean)
  echo "==> clean phase script"
  clean_templated_files
  clean_tox_files
  rm -rf ./venv-* ./*.wgn ./site ./coverage.xml ./xunit-results.xml
  ;;
generate-sources)
  echo "==> generate-sources phase script"
  expand_templates
  ;;
compile)
  echo "==> compile phase script"
  ;;
test)
  echo "==> test phase script"
  case $MVN_PROJECT_MODULEID in
  dcae-services-policy-sync)
    set -e -x
    CURDIR=$(pwd)
    TOXINIS=$(find . -name "tox.ini")
    for TOXINI in "${TOXINIS[@]}"; do
      DIR=$(echo "$TOXINI" | rev | cut -f2- -d'/' | rev)
      cd "${CURDIR}/${DIR}"
      rm -rf ./venv-tox ./.tox
      virtualenv ./venv-tox
      source ./venv-tox/bin/activate
      pip install pip==20.3.4
      pip install --upgrade argparse
      pip install tox
      pip freeze
      tox
      deactivate
      rm -rf ./venv-tox ./.tox
    done 
    ;;
  esac
  ;;
package)
  echo "==> package phase script"
  ;;
install)
  echo "==> install phase script"
  case $MVN_PROJECT_MODULEID in
  bootstrap)
    upload_files_of_extension sh
    ;;
  esac
  ;;
deploy)
  echo "==> deploy phase script"

  case $MVN_PROJECT_MODULEID in
  cm-container|healthcheck-container|tls-init-container|consul-loader-container|multisite-init-container|dcae-k8s-cleanup-container|dcae-services-policy-sync)
    build_and_push_docker
    ;;
  *)
    echo "====> unknown mvn project module"
    ;;
  esac
  ;;
*)
  echo "==> unprocessed phase"
  ;;
esac

