FROM centos

MAINTAINER Venoodk venood.khatuva12@gmail.com

ENV SPLUNK_BACKUP_APP /var/opt/splunk/etc/apps
ENV DOCKER_VERSION 17.06.2

# Basic packages
RUN yum update -y
RUN yum group install "Development Tools" -y
RUN rpm -Uvh http://del-mirrors.extreme-ix.org/epel//epel-release-latest-7.noarch.rpm \
 && yum -y install passwd sudo git curl dnsutils vim wget openssl openssh openssh-server openssh-clients jq

# Create user
RUN useradd splunk \
 && echo "changeme" | passwd splunk --stdin \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
 && echo "splunk ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/splunk
 
COPY ./rmp-files/splunkforwarder-6.5.3-36937ad027d4-linux-2.6-x86_64.rpm /tmp/
RUN rpm -ivh /tmp/splunkforwarder-6.5.3-36937ad027d4-linux-2.6-x86_64.rpm

COPY ta-dockerlogs_fileinput ${SPLUNK_BACKUP_APP}/ta-dockerlogs_fileinput
COPY ta-dockerstats ${SPLUNK_BACKUP_APP}/ta-dockerstats
RUN chmod +x ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/*.sh 
RUN wget -qO ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/docker-${DOCKER_VERSION}-ce.tgz https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}-ce.tgz \
    && mkdir ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/tmp \
    && tar xzvf ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/docker-${DOCKER_VERSION}-ce.tgz -C ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/tmp \
    && rm -rf ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/docker-${DOCKER_VERSION}-ce.tgz \
    && mv ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/tmp/docker/* ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin \
    && chmod +x ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/docker

RUN rm -rvf \
      /tmp/* \
      /var/tmp/*

RUN chown -R splunk:splunk /opt/splunk
RUN chmod -R 777 /opt/splunk
RUN chown splunk:splunk ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/*.sh
RUN chown splunk:splunk ${SPLUNK_BACKUP_APP}/ta-dockerstats/bin/docker
RUN mkdir -p /opt/splunkforwarder/etc/apps/sb_cdx_${SERVER}/local/
COPY config-files/inputs.conf /opt/splunkforwarder/etc/apps/sb_cdx_${SERVER}/local/inputs.conf
COPY config-files/deploymentclient.conf /opt/splunkforwarder/etc/system/default/deploymentclient.conf
CMD /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes \
    && /opt/splunkforwarder/bin/splunk set deploy-poll ${SPLUNK_DEPLOYMENT_SERVER} -auth ${SPLUNKUSER} \
    && sudo /opt/splunkforwarder/bin/splunk enable boot-start -user splunk 
RUN sed -i "s/DEPLOYMENT_SERVER/${SPLUNK_DEPLOYMENT_SERVER}/g" deploymentclient.conf
RUN sed -i "s/ENVO/${SERVER}g" inputs.conf

CMD ["/opt/splunkforwarder/bin/splunk restart"]


