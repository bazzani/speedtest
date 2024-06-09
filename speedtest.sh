#!/bin/sh

# These values can be overwritten with env variables
SHOW_SERVERS="${SHOW_SERVERS:-false}"
LOOP="${LOOP:-false}"
LOOP_DELAY="${LOOP_DELAY:-60}"
DB_SAVE="${DB_SAVE:-false}"
DB_HOST="${DB_HOST:-http://localhost:8086}"
DB_NAME="${DB_NAME:-speedtest}"
DB_USERNAME="${DB_USERNAME:-admin}"
DB_PASSWORD="${DB_PASSWORD:-password}"
SPEEDTEST_HOSTNAME="${SPEEDTEST_HOSTNAME}"
SPEEDTEST_SERVER_ID="${SPEEDTEST_SERVER_ID}"

run_speedtest() {
  DATE=$(date +%s)
  HOSTNAME=$(hostname)

  # Start speed test
  if [ -z "$1" ]; then
    echo "Running a Speed Test with default host... "
    JSON=$(speedtest --accept-license --accept-gdpr -f json)
  else # todo add else if, or make 1st if the final else
    echo "Running a Speed Test with server flags [$1]... "
#    JSON=$(speedtest --accept-license --accept-gdpr -f json -o "$1")
    JSON=$(speedtest --accept-license --accept-gdpr -f json -s "$1")
  fi

  json_result_found="$(jq -e 'select(.type == "result")')"
  if [ -n "${json_result_found}" ]; then
    DOWNLOAD="$(echo "$JSON" | jq -r '.download.bandwidth')"
    UPLOAD="$(echo "$JSON" | jq -r '.upload.bandwidth')"
    PING="$(echo "$JSON" | jq -r '.ping.latency')"
    echo "Your download speed is $((DOWNLOAD / 125000)) Mbps ($DOWNLOAD Bytes/s)."
    echo "Your upload speed is $((UPLOAD / 125000)) Mbps ($UPLOAD Bytes/s)."
    echo "Your ping is $PING ms."

    # Save results in the database
    if $DB_SAVE; then
      echo "Saving values to database..."

      curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
        --data-binary "download,host=$HOSTNAME value=$DOWNLOAD $DATE"
      curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
        --data-binary "upload,host=$HOSTNAME value=$UPLOAD $DATE"
      curl -s -S -XPOST "$DB_HOST/write?db=$DB_NAME&precision=s&u=$DB_USERNAME&p=$DB_PASSWORD" \
        --data-binary "ping,host=$HOSTNAME value=$PING $DATE"

      echo "Values saved."
    fi
  else
    echo "Unable to retrieve results from speedtest"
  fi
}

get_server_flags() {
#  echo >&2 "get_server_flags..."
#  echo >&2 "SPEEDTEST_SERVER_ID: $([ -n "$SPEEDTEST_SERVER_ID" ])"
#  echo >&2 "SPEEDTEST_HOSTNAME: $([ -n "$SPEEDTEST_HOSTNAME" ])"

## todo figure out which flags have been passed in here, return non-zero if multiple server flags passed in

  if [ -n "$SPEEDTEST_SERVER_ID" ] && [ -n "$SPEEDTEST_HOSTNAME" ]; then
    echo >&2 "[error] Only one server selection can be specified, please use one of ['SPEEDTEST_SERVER_ID' or 'SPEEDTEST_HOSTNAME']"
    exit 1 # todo throw error
  elif [ -n "$SPEEDTEST_HOSTNAME" ]; then
#    echo "-o $SPEEDTEST_HOSTNAME"
    echo "$SPEEDTEST_HOSTNAME"
  elif [ -n "$SPEEDTEST_SERVER_ID" ]; then
#    echo "-s $SPEEDTEST_SERVER_ID"
    echo "$SPEEDTEST_SERVER_ID"
  else
    echo >&2 "No Server flags being set"
  fi
}

call_speedtest_with_args() {
  #  set -e
  server_flags=$(get_server_flags)

  if [ -z "$server_flags" ]; then
    #  if [ -z "$1" ]; then
    run_speedtest
  else
    #    echo "run_speedtest with [ $1 ]"
    #    run_speedtest "$1"
    echo "run_speedtest with [ $server_flags ]"
    run_speedtest "$server_flags"
  fi
}

if $SHOW_SERVERS; then
  speedtest --accept-license --accept-gdpr -L
fi

if $LOOP; then
  echo "Running speedtest forever... ♾️"
  echo
  while :; do
    call_speedtest_with_args
    echo ""
    echo "Running next test in ${LOOP_DELAY} seconds..."
    echo ""
    sleep "$LOOP_DELAY"
  done
else
  call_speedtest_with_args
fi
