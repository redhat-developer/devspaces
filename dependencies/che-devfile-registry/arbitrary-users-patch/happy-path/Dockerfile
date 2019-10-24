ARG TAG
FROM quay.io/eclipse/che-java11-maven:${TAG}

USER root

RUN cd / && \
    git clone https://github.com/spring-projects/spring-petclinic && \
    cd /spring-petclinic && \
    mvn clean package && \
    mkdir -p /home/user/.m2/repository && \
    cp -r /root/.m2/repository/* /home/user/.m2/repository && \
    rm -rf spring-petclinic/ /root/.m2/repository/* && \
    chmod -R g=u /home/user

USER 10001
