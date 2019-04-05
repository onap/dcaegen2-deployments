FROM ubuntu:16.04
MAINTAINER maintainer
ENV INSROOT  /opt/app
ENV APPUSER installer
RUN apt-get update\
    && apt-get install -y iputils-ping wget python-virtualenv python-pip ssh ed curl uuid-runtime netcat\
    && apt-get clean\
    && pip install --upgrade pip\
    && mkdir -p ${INSROOT}/${APPUSER}/blueprints\
    &&  useradd -d ${INSROOT}/${APPUSER}  ${APPUSER}
COPY installer-docker.sh ${INSROOT}/${APPUSER}/installer
COPY teardown.sh ${INSROOT}/${APPUSER}/teardown
# COPY *.yaml ${INSROOT}/${APPUSER}/blueprints/
RUN wget -P ${INSROOT}/${APPUSER}/blueprints/ https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.blueprints/R3/blueprints/centos_vm.yaml
RUN wget -P ${INSROOT}/${APPUSER}/blueprints/ https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.blueprints/R3/blueprints/consul_cluster.yaml
WORKDIR ${INSROOT}/${APPUSER}
RUN chown -R ${APPUSER}:${APPUSER} ${INSROOT}/${APPUSER}  && chmod +x ${INSROOT}/${APPUSER}/installer && chmod +x ${INSROOT}/${APPUSER}/teardown
USER ${APPUSER}
ENTRYPOINT exec "${INSROOT}/${APPUSER}/installer"
 
