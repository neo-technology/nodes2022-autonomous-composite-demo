ARG neo4jVersion

FROM neo4j:${neo4jVersion}

RUN keytool \
    -genseckey \
    -keyalg aes \
    -keysize 256 \
    -storetype pkcs12 \
    -keystore '/var/lib/neo4j/conf/secrets' \
    -alias 'secrets' \
    -storepass 'foobar'

COPY sharding-function/target/sharding-function-1.0-SNAPSHOT.jar \
     /var/lib/neo4j/plugins/

RUN apt update && apt install -y \
    dnsutils \
    iputils-ping \
    less