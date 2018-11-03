#!/bin/bash
sed \
  -e 's#{{ ONAPTEMPLATE_RAWREPOURL_org_onap_dcaegen2_platform_plugins_releases }}#https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/R4#' \
  -e 's#{{ ONAPTEMPLATE_RAWREPOURL_org_onap_ccsdk_platform_plugins_releases }}#https://nexus.onap.org/service/local/repositories/raw/content/org.onap.ccsdk.platform.plugins#' \
  -e 's#{{ ONAPTEMPLATE_RAWREPOURL_org_onap_dcaegen2_platform_blueprints_releases }}#https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.blueprints/R4#' \
Dockerfile-template > Dockerfile
