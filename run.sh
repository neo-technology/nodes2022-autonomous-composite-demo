#!/bin/bash

set -e
# set -x

commands=${1:-all}
numMembers1=5
numMembers2=7
numShards=10
numPersons=100
numFollows=100
maxPosts=100


build() {
    sharding-function/mvnw -f sharding-function/pom.xml  package
    docker-compose build
}

run() {
    options=()
    echo "=================================================="
    echo "options:"
    while [ $# -gt 1 ]; do
        echo "  " "$1" "$2"
        options+=("$1")
        options+=("$2")
        shift; shift
    done
    echo
    query=$(echo "$@" | sed 's/^[[:space:]]*|/  /g')
    echo "query:"
    echo "$query"
    echo "result:"
    docker-compose exec -T main cypher-shell -u neo4j -p password "${options[@]}" "$query" | sed 's/^/  /g'
    echo
}

shell() {
    docker-compose exec main cypher-shell -u neo4j -p password -d system
}

up() {
    docker-compose up -d --scale main=$numMembers1
    docker-compose logs -f || true
}

setup() {
    s3='s3://tobiasjohansson/nodes2022'

    run -d system -P "uri => '$s3/peopledb.backup'" '
        |DROP DATABASE neo4j;
        |CREATE DATABASE peopledb
        |  TOPOLOGY 3 PRIMARIES
        |  OPTIONS { existingData: "use", seedURI: $uri, seedConfig: "region=eu-north-1" }
        |  WAIT;
        |
        |CREATE COMPOSITE DATABASE social;
        |
        |CREATE ALIAS social.people FOR DATABASE peopledb;
    '

    for i in $(seq 1 $numShards); do
        run -d system -P "db => 'posts${i}db'" -P "alias => 'social.posts${i}'" -P "uri => '$s3/posts${i}db.backup'" '
            |CREATE DATABASE $db
            |  TOPOLOGY 3 PRIMARIES
            |  OPTIONS { existingData:"use", seedURI: $uri, seedConfig: "region=eu-north-1" }
            |  WAIT;
            |
            |CREATE ALIAS $alias FOR DATABASE $db;
        '
    done
}

query() {
    run -d social -P "numShards => $numShards" '
        |CALL {
        |    USE social.people
        |    MATCH (person:Person)-[:FOLLOWS]->(poster:Person)
        |    RETURN person, poster LIMIT 10
        |}
        |WITH person, poster,
        |     poster.id AS pid, 
        |     sharding.postsByPersonId(poster.id) AS shard
        |CALL {
        |    USE graph.byName(shard)
        |    WITH pid
        |    MATCH (p:Person {id: pid})-[:POSTED]->(post:Post)
        |    RETURN post LIMIT 2
        |}
        |RETURN person.name, 
        |       poster.name, 
        |       post.text,
        |       shard;
    '
}

scale() {
    docker-compose up -d --scale main=$numMembers2
    docker-compose logs -f || true
}

enable() {
    run -d system 'SHOW SERVERS'

    ids=$(run -d system 'SHOW SERVERS' \
        | grep '"Free"' \
        | cut -d ',' -f 1 \
        | tr -d '"')

    for id in $ids; do
        run -d system -P "id => '$id'" 'ENABLE SERVER $id'
    done

    run -d system 'SHOW SERVERS'
}

reallocate() {
    run -d system 'SHOW SERVERS'
    run -d system 'REALLOCATE DATABASES'
    run -d system 'SHOW SERVERS'
}

phase1() {
    up
    setup
    query
}

phase2() {
    scale
    enable
    reallocate
    query
}

all() {
    phase1
    phase2
}

for command in $commands; do
    $command
done
