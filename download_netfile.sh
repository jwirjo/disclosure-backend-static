#!/bin/bash
# usage: ./download_netfile.sh COAK 2016 summary
# usage: ./download_netfile.sh COAK 2016 transaction
set -euo pipefail

agency=$1
year=$2
form=$3

download_page() {
  page_offset=$1
  tmpfile=$(mktemp -t netfile.XXXXXX)
  curl -H "Accept: text/csv" -d Aid=$agency -d Year=$year -d CurrentPageIndex=${page_offset} \
    https://netfile.com:443/Connect2/api/public/campaign/export/cal201/$form/year/csv \
    > $tmpfile

  if [[ "$page_offset" == "0" ]]; then
    cat $tmpfile
  else
    tail -n +2 $tmpfile
  fi

  if [[ $(wc -l "$tmpfile" | awk '{ print $1 }') == "1001" ]]; then
    # there's another page!
    download_page $((page_offset + 1))
  fi
}

download_page 0
