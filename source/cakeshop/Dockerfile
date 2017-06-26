FROM jpmc/cakeshop

RUN rm -f /opt/cakeshop/data/local/application.properties

COPY application.properties /opt/cakeshop/data/local/

WORKDIR /opt/cakeshop

ENTRYPOINT  ["java","-jar","/opt/cakeshop/cakeshop.war"]