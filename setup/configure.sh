#!/bin/bash
OPENNMS_HOST=localhost
OPENNMS_USER=admin
OPENNMS_PASS=admin
OPENNMS_PORT=8980

GRAYLOG_HOST=localhost
GRAYLOG_USER=admin
GRAYLOG_PASS=admin
GRAYLOG_PORT=9000

GRAFANA_HOST=localhost
GRAFANA_PORT=3000
GRAFANA_USER=admin
GRAFANA_PASS=mysecret

# set -x

echo -n "Ensure the ReST API is running before setup        "
until $(curl -L --output /dev/null --silent --head --fail http://${OPENNMS_HOME}:8980); do
    printf '.'
    sleep 2
done
echo " DONE"

# Change to project root directory
cd ..

echo -n "Create Minion user                                 ... "
curl -s -u ${OPENNMS_USER}:${OPENNMS_PASS} \
     -X POST \
     -H "Content-Type: application/xml" \
     -H "Accept: application/xml" \
     -d @setup/minion-user.xml \
     http://${OPENNMS_HOST}:${OPENNMS_PORT}/opennms/rest/users
echo "DONE"

echo -n "Create user on Minion for ReST API and HTTP broker ... "
docker-compose exec minion /opt/minion/bin/client "scv:set opennms.http minion minion"
docker-compose exec minion /opt/minion/bin/client "scv:set opennms.broker minion minion"

#
# Change into OpenNMS config directory to apply configuration patches for Graylog and ActiveMQ for Minions
#
cd etc
echo -n "Enable listening for ActiveMQ on all interfaces    ... "
patch opennms-activemq.xml < ../setup/activemq-listen.patch
echo "DONE"

echo "Restart OpenNMS Horizon                            ... "
docker-compose stop opennms && docker-compose up -d

echo -n "Wait for web app to be ready                       "
until $(curl -L --output /dev/null --silent --head --fail http://${OPENNMS_HOME}:8980); do
    printf '.'
    sleep 2
done
echo " DONE"

echo "Restart OpenNMS Horizon                            ... "
docker-compose stop opennms && docker-compose up -d

echo -n "Wait for web app to be ready                       "
until $(curl -L --output /dev/null --silent --head --fail http://${OPENNMS_HOME}:${OPENNMS_PORT}); do
    printf '.'
    sleep 2
done
echo " DONE"

echo -n "Install Grafana OpenNMS Datasource              ... "
docker-compose exec grafana grafana-cli plugins install opennms-datasource
echo "DONE"

echo "Restart Grafana                                 ... "
docker-compose stop grafana
docker-compose up -d grafana
sleep 10

echo -n "Setup Grafana OpenNMS Data Source               ... "
curl -s -u admin:mysecret \
     -X POST \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d @opennms-grafana-datasource.json \
     http://${GRAFANA_HOST}:${GRAFANA_PORT}/api/datasources
echo "DONE"
