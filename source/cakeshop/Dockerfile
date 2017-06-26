FROM jpmc/cakeshop

RUN rm -f /opt/cakeshop/data/local/application.properties
COPY start.sh /opt/cakeshop/
COPY application.properties /opt/cakeshop/data/local/
WORKDIR /opt/cakeshop/

CMD  ["/opt/cakeshop/start.sh"]