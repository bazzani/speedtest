#!/bin/sh
# These values can be overwritten with env variables
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
    JSON=$(speedtest --accept-license --accept-gdpr -f json "$1")
  fi

  if jq -e . >/dev/null 2>&1 <<<"$JSON"; then
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

call_speedtest_with_args() {
  if [ -z "$1" ]; then
    run_speedtest
  else
    run_speedtest "$1"
  fi
}

get_server_flags() {
  if [ -z $SPEEDTEST_HOSTNAME ] && [ -z "$SPEEDTEST_SERVER_ID" ]; then
    echo "[error] Only one server selection can be specified, please use one of ["'$SPEEDTEST_HOSTNAME' or 'SPEEDTEST_SERVER_ID'"]"
    # todo throw error
  elif [ -z $SPEEDTEST_HOSTNAME ]; then
    return "-o $SPEEDTEST_HOSTNAME"
  elif [ -z $SPEEDTEST_SERVER_ID ]; then
    return "-s $SPEEDTEST_SERVER_ID"
  else
    return null
  fi
}

# todo figure out which flags have been passed in here, return non-zero if multiple server flags passed in
def server_flags = get_server_flags

if $LOOP; then
  echo "Running speedtest forever... ♾️"
  echo
  while :; do
    call_speedtest_with_args server_flags
    echo ""
    echo "Running next test in ${LOOP_DELAY} seconds..."
    echo ""
    sleep "$LOOP_DELAY"
  done
else
  call_speedtest_with_args server_flags
fi
